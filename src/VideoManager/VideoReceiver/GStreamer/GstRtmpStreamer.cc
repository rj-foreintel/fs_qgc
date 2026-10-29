#include "GstRtmpStreamer.h"

#include "QGCLoggingCategory.h"

#include <QtCore/QScopeGuard>
#include <QtCore/QUrl>

#include <gst/app/gstappsrc.h>

QGC_LOGGING_CATEGORY(GstRtmpStreamerLog, "Video.GStreamer.GstRtmpStreamer")

GstRtmpStreamer::GstRtmpStreamer(QObject *parent)
    : VideoLiveStreamer(parent)
{
    _clock.start();
    _pollTimer.setInterval(kPollIntervalMs);
    (void) connect(&_pollTimer, &QTimer::timeout, this, &GstRtmpStreamer::_poll);
}

GstRtmpStreamer::~GstRtmpStreamer()
{
    QMutexLocker locker(&_lock);
    _wanted = false;
    _destroyPipeline(false);
}

void GstRtmpStreamer::start(const QString &url)
{
    {
        QMutexLocker locker(&_lock);
        if (_wanted && (url == _url)) {
            return;
        }

        // A URL change while streaming closes the old connection cleanly first.
        _destroyPipeline(_wanted);

        _url = url;
        _wanted = true;
        _needKeyframe = true;
        _lastSampleMs = -1;
        _lastCodec = Codec::None;
        _retryAtMs = -1;
        _retryDelayMs = kMinRetryDelayMs;
        _retryReason.clear();
        _failReason.clear();
        _failedCodec = Codec::None;
    }

    qCDebug(GstRtmpStreamerLog) << "Live stream requested to" << _describeUrl(url);

    setStats(QString(), 0);
    setState(WaitingForVideo, tr("Waiting for camera video"));
    _pollTimer.start();
}

void GstRtmpStreamer::stop()
{
    _pollTimer.stop();

    {
        QMutexLocker locker(&_lock);
        _wanted = false;
        _destroyPipeline(true);
    }

    qCDebug(GstRtmpStreamerLog) << "Live stream stopped";

    setStats(QString(), 0);
    setState(Idle, QString());
}

void GstRtmpStreamer::pushSample(GstSample *sample)
{
    // Never make the receiver's streaming thread wait (that would stall the pilot's video).
    if (!_lock.tryLock()) {
        _resyncNeeded.storeRelaxed(true);
        return;
    }
    const auto unlock = qScopeGuard([this]() { _lock.unlock(); });

    if (!_wanted) {
        return;
    }

    GstBuffer *buffer = gst_sample_get_buffer(sample);
    GstCaps *caps = gst_sample_get_caps(sample);
    if (!buffer || !caps) {
        return;
    }

    if (_resyncNeeded.fetchAndStoreRelaxed(false)) {
        _needKeyframe = true;
    }

    _lastSampleMs = _clock.elapsed();
    _inBytes += gst_buffer_get_size(buffer);
    _pushLocked(buffer, caps);
}

void GstRtmpStreamer::_pushLocked(GstBuffer *buffer, GstCaps *caps)
{
    const Codec codec = _codecFromCaps(caps);
    _lastCodec = codec;

    if (codec == Codec::Unsupported) {
        _destroyPipeline(false);
        return;
    }

    if (codec == Codec::H265) {
        // H.265 needs Enhanced RTMP. GStreamer's eflvmux (1.26-1.28) does not write the
        // standard Enhanced-RTMP video header ("hvc1" FourCC), so servers such as FFmpeg
        // cannot decode it. Ask for H.264 rather than sending an unplayable stream.
        _destroyPipeline(false);
        _failedCodec = codec;
        _failReason = tr("Live streaming needs H.264 video, but the camera is sending H.265. "
                         "Tap Switch Camera to H.264, or set the camera's coding format to H.264.");
        return;
    }

    if (!_failReason.isEmpty()) {
        if (codec == _failedCodec) {
            return;
        }
        // The camera switched codec; give it another try.
        _failReason.clear();
        _failedCodec = Codec::None;
    }

    const bool keyframe = !GST_BUFFER_FLAG_IS_SET(buffer, GST_BUFFER_FLAG_DELTA_UNIT);

    if (_pipeline && (codec != _pipelineCodec)) {
        qCDebug(GstRtmpStreamerLog) << "Camera codec changed to" << _codecName(codec) << "- restarting publisher";
        _destroyPipeline(false);
    }

    if (!_pipeline) {
        // The server must receive a keyframe first, and we respect the retry back-off.
        if (!keyframe || ((_retryAtMs >= 0) && (_clock.elapsed() < _retryAtMs))) {
            return;
        }
        _retryAtMs = -1;
        if (!_buildPipeline(codec, caps)) {
            return;
        }
    }

    GstAppSrc *appsrc = GST_APP_SRC(_appsrc);

    // Follow caps changes, e.g. a resolution change on the camera.
    GstCaps *currentCaps = gst_app_src_get_caps(appsrc);
    if (!currentCaps || !gst_caps_is_equal(currentCaps, caps)) {
        gst_app_src_set_caps(appsrc, caps);
    }
    gst_clear_caps(&currentCaps);

    // If the upload cannot keep up, skip whole groups of frames instead of sending
    // frames the viewer cannot decode.
    const GstClockTime backlog = gst_app_src_get_current_level_time(appsrc);
    if (GST_CLOCK_TIME_IS_VALID(backlog) && (backlog > kMaxBacklog)) {
        if (!_needKeyframe) {
            qCDebug(GstRtmpStreamerLog) << "Upload too slow, backlog" << (backlog / GST_MSECOND) << "ms - skipping to next keyframe";
        }
        _needKeyframe = true;
        _lastBacklogDropMs = _clock.elapsed();
        return;
    }

    const GstClockTime inTs = GST_BUFFER_DTS_IS_VALID(buffer) ? GST_BUFFER_DTS(buffer) : GST_BUFFER_PTS(buffer);
    if (!GST_CLOCK_TIME_IS_VALID(inTs)) {
        return;
    }

    // The receiver restarts its pipeline when the camera link drops, which resets its
    // timestamps. Treat backwards or large forward jumps as a new stream.
    if (!_needKeyframe && GST_CLOCK_TIME_IS_VALID(_lastInTs)
            && ((inTs < _lastInTs) || ((inTs - _lastInTs) > kMaxTimestampJump))) {
        qCDebug(GstRtmpStreamerLog) << "Camera timestamps jumped - resyncing at next keyframe";
        _needKeyframe = true;
    }

    bool resynced = false;
    if (_needKeyframe) {
        if (!keyframe) {
            return;
        }
        // Map the input onto this pipeline's running time so flvmux sees a live,
        // monotonic timeline across camera reconnects.
        GstClockTime now = gst_element_get_current_running_time(_pipeline);
        if (!GST_CLOCK_TIME_IS_VALID(now)) {
            now = 0;
        }
        if (GST_CLOCK_TIME_IS_VALID(_lastOutDts) && (now <= _lastOutDts)) {
            now = _lastOutDts + GST_MSECOND;
        }
        _outBase = now;
        _inBase = inTs;
        _needKeyframe = false;
        resynced = true;
    }
    _lastInTs = inTs;

    const auto rebase = [this](GstClockTime ts) -> GstClockTime {
        if (!GST_CLOCK_TIME_IS_VALID(ts) || (ts < _inBase)) {
            return GST_CLOCK_TIME_NONE;
        }
        return ts - _inBase + _outBase;
    };

    GstBuffer *out = gst_buffer_copy(buffer);   // shallow: shares the encoded data
    GST_BUFFER_PTS(out) = rebase(GST_BUFFER_PTS(buffer));
    GST_BUFFER_DTS(out) = rebase(GST_BUFFER_DTS(buffer));
    if (resynced) {
        GST_BUFFER_FLAG_SET(out, GST_BUFFER_FLAG_DISCONT);
    }

    const GstClockTime outDts = GST_BUFFER_DTS_IS_VALID(out) ? GST_BUFFER_DTS(out) : GST_BUFFER_PTS(out);
    if (!GST_CLOCK_TIME_IS_VALID(outDts) || (GST_CLOCK_TIME_IS_VALID(_lastOutDts) && (outDts < _lastOutDts))) {
        gst_buffer_unref(out);
        return;
    }
    _lastOutDts = outDts;

    (void) gst_app_src_push_buffer(appsrc, out);   // takes ownership; never blocks (block=false)
}

bool GstRtmpStreamer::_buildPipeline(Codec codec, GstCaps *caps)
{
    GstElement *pipeline = gst_pipeline_new("rtmp-publisher");
    GstElement *appsrc = gst_element_factory_make("appsrc", nullptr);
    GstElement *parser = gst_element_factory_make("h264parse", nullptr);
    GstElement *mux = gst_element_factory_make("flvmux", nullptr);
    GstElement *sink = gst_element_factory_make("rtmp2sink", nullptr);

    if (!pipeline || !appsrc || !parser || !mux || !sink) {
        const char *missing = !appsrc ? "appsrc" : !parser ? "h264parse" : !mux ? "flvmux" : !sink ? "rtmp2sink" : "pipeline";
        qCCritical(GstRtmpStreamerLog) << "Missing GStreamer element:" << missing;

        _failedCodec = codec;
        _failReason = tr("Live streaming is not available in this build (missing %1).").arg(QString::fromLatin1(missing));

        gst_clear_object(&sink);
        gst_clear_object(&mux);
        gst_clear_object(&parser);
        gst_clear_object(&appsrc);
        gst_clear_object(&pipeline);
        return false;
    }

    // appsrc holds the backlog while the connection is slow; _pushLocked() trims it
    // at keyframe boundaries, and the leaky limit is only a safety net.
    g_object_set(appsrc,
                 "format", GST_FORMAT_TIME,
                 "is-live", TRUE,
                 "do-timestamp", FALSE,
                 "block", FALSE,
                 nullptr);
    gst_app_src_set_caps(GST_APP_SRC(appsrc), caps);
    gst_app_src_set_stream_type(GST_APP_SRC(appsrc), GST_APP_STREAM_TYPE_STREAM);
    gst_app_src_set_max_bytes(GST_APP_SRC(appsrc), 0);
    gst_app_src_set_max_buffers(GST_APP_SRC(appsrc), 0);
    gst_app_src_set_max_time(GST_APP_SRC(appsrc), 2 * kMaxBacklog);
    gst_app_src_set_leaky_type(GST_APP_SRC(appsrc), GST_APP_LEAKY_TYPE_DOWNSTREAM);

    // Repeat SPS/PPS with every keyframe so viewers can join at any time.
    g_object_set(parser, "config-interval", -1, nullptr);

    g_object_set(mux, "streamable", TRUE, nullptr);

    const QByteArray location = _url.toUtf8();
    g_object_set(sink,
                 "location", location.constData(),
                 "async-connect", TRUE,
                 "sync", FALSE,
                 "async", FALSE,
                 nullptr);

    gst_bin_add_many(GST_BIN(pipeline), appsrc, parser, mux, sink, nullptr);

    if (!gst_element_link_many(appsrc, parser, mux, sink, nullptr)) {
        qCCritical(GstRtmpStreamerLog) << "Failed to link publisher for" << _codecName(codec);
        gst_clear_object(&pipeline);
        _failedCodec = codec;
        _failReason = tr("Live streaming could not be set up for %1 video.").arg(_codecName(codec));
        return false;
    }

    if (gst_element_set_state(pipeline, GST_STATE_PLAYING) == GST_STATE_CHANGE_FAILURE) {
        qCWarning(GstRtmpStreamerLog) << "Publisher failed to start";
        (void) gst_element_set_state(pipeline, GST_STATE_NULL);
        gst_clear_object(&pipeline);
        _scheduleRetry(tr("Could not start the stream"));
        return false;
    }

    _pipeline = pipeline;
    _appsrc = appsrc;
    _sink = sink;
    _pipelineCodec = codec;
    _needKeyframe = true;
    _lastInTs = GST_CLOCK_TIME_NONE;
    _lastOutDts = GST_CLOCK_TIME_NONE;
    _lastOutBytes = 0;
    _lastStatsMs = _clock.elapsed();
    _lastInBytes = _inBytes;
    _lastBacklogDropMs = -1;
    _uploadBehindSinceMs = -1;
    _connected = false;

    qCDebug(GstRtmpStreamerLog) << "Publishing" << _codecName(codec) << "to" << _describeUrl(_url);
    return true;
}

void GstRtmpStreamer::_destroyPipeline(bool sendEos)
{
    if (!_pipeline) {
        return;
    }

    if (sendEos && _connected) {
        // Let the server close the stream cleanly; don't wait long on a bad link.
        (void) gst_app_src_end_of_stream(GST_APP_SRC(_appsrc));
        GstBus *bus = gst_element_get_bus(_pipeline);
        if (bus) {
            GstMessage *msg = gst_bus_timed_pop_filtered(bus, 500 * GST_MSECOND,
                                                         static_cast<GstMessageType>(GST_MESSAGE_EOS | GST_MESSAGE_ERROR));
            gst_clear_message(&msg);
            gst_clear_object(&bus);
        }
    }

    (void) gst_element_set_state(_pipeline, GST_STATE_NULL);
    gst_clear_object(&_pipeline);
    _appsrc = nullptr;
    _sink = nullptr;
    _pipelineCodec = Codec::None;
    _connected = false;
    _needKeyframe = true;
}

void GstRtmpStreamer::_scheduleRetry(const QString &reason)
{
    _retryReason = reason;
    _retryAtMs = _clock.elapsed() + _retryDelayMs;
    qCDebug(GstRtmpStreamerLog) << "Retrying in" << _retryDelayMs << "ms:" << reason;
    _retryDelayMs = qMin(_retryDelayMs * 2, kMaxRetryDelayMs);
}

void GstRtmpStreamer::_poll()
{
    State state = Idle;
    QString text;
    QString codecName;
    int kbps = 0;
    int inKbps = 0;
    int backlogMs = 0;
    bool uploadTooSlow = false;

    {
        QMutexLocker locker(&_lock);
        if (!_wanted) {
            return;
        }

        const qint64 now = _clock.elapsed();

        if (_pipeline) {
            GstBus *bus = gst_element_get_bus(_pipeline);
            GstMessage *msg = nullptr;
            while (_pipeline && bus
                   && (msg = gst_bus_pop_filtered(bus, static_cast<GstMessageType>(GST_MESSAGE_ERROR | GST_MESSAGE_EOS)))) {
                QString reason;
                if (GST_MESSAGE_TYPE(msg) == GST_MESSAGE_ERROR) {
                    GError *error = nullptr;
                    gchar *debug = nullptr;
                    gst_message_parse_error(msg, &error, &debug);
                    reason = error ? QString::fromUtf8(error->message) : tr("Stream error");
                    qCWarning(GstRtmpStreamerLog) << "Publisher error:" << reason << (debug ? debug : "");
                    g_clear_error(&error);
                    g_free(debug);
                } else {
                    reason = tr("The server closed the connection");
                }
                gst_clear_message(&msg);

                _destroyPipeline(false);
                _scheduleRetry(reason);
            }
            gst_clear_object(&bus);
        }

        if (_pipeline && _sink) {
            GstStructure *stats = nullptr;
            g_object_get(_sink, "stats", &stats, nullptr);
            guint64 outBytes = 0;
            if (stats) {
                (void) gst_structure_get_uint64(stats, "out-bytes-total", &outBytes);
                gst_structure_free(stats);
            }

            const qint64 elapsedMs = now - _lastStatsMs;
            if ((elapsedMs > 0) && (outBytes >= _lastOutBytes)) {
                kbps = static_cast<int>(((outBytes - _lastOutBytes) * 8) / static_cast<guint64>(elapsedMs));
            }
            if ((elapsedMs > 0) && (_inBytes >= _lastInBytes)) {
                inKbps = static_cast<int>(((_inBytes - _lastInBytes) * 8) / static_cast<guint64>(elapsedMs));
            }
            _lastInBytes = _inBytes;

            if (_appsrc) {
                const GstClockTime level = gst_app_src_get_current_level_time(GST_APP_SRC(_appsrc));
                if (GST_CLOCK_TIME_IS_VALID(level)) {
                    backlogMs = static_cast<int>(level / GST_MSECOND);
                }
            }

            // Behind when the upload stays clearly below the camera rate (10 % margin for
            // bursty key frames), or frames had to be skipped recently.
            if ((inKbps > 0) && (kbps * 10 < inKbps * 9)) {
                if (_uploadBehindSinceMs < 0) {
                    _uploadBehindSinceMs = now;
                }
            } else {
                _uploadBehindSinceMs = -1;
            }
            uploadTooSlow = ((_uploadBehindSinceMs >= 0) && ((now - _uploadBehindSinceMs) > kUploadSlowMs))
                            || ((_lastBacklogDropMs >= 0) && ((now - _lastBacklogDropMs) < kUploadSlowMs));
            // The handshake alone is a few hundred bytes; sustained data means we are live.
            if ((outBytes > _lastOutBytes) && (outBytes > 16 * 1024)) {
                _connected = true;
                _retryDelayMs = kMinRetryDelayMs;
            }
            _lastOutBytes = outBytes;
            _lastStatsMs = now;
        }

        codecName = _codecName(_pipeline ? _pipelineCodec : _lastCodec);
        const bool videoArriving = (_lastSampleMs >= 0) && ((now - _lastSampleMs) < kNoVideoTimeoutMs);

        if (_lastCodec == Codec::Unsupported) {
            state = Failed;
            text = tr("The camera's video format cannot be sent over RTMP. Set the camera to H.264.");
        } else if (!_failReason.isEmpty()) {
            state = Failed;
            text = _failReason;
        } else if (!videoArriving) {
            state = WaitingForVideo;
            text = tr("Waiting for camera video");
            kbps = 0;
            inKbps = 0;
            uploadTooSlow = false;
        } else if (!_pipeline && (_retryAtMs >= 0)) {
            state = Reconnecting;
            const qint64 seconds = qMax<qint64>(1, (_retryAtMs - now + 999) / 1000);
            text = tr("%1. Retrying in %2 s").arg(_retryReason).arg(seconds);
        } else if (!_pipeline || !_connected) {
            state = Connecting;
            text = tr("Connecting to %1").arg(_describeUrl(_url));
        } else {
            state = Live;
            text = tr("Live on %1").arg(_describeUrl(_url));
        }
    }

    if (state != Live) {
        uploadTooSlow = false;
    }
    setStats(codecName, kbps, inKbps, backlogMs, uploadTooSlow);
    setState(state, text);
}

GstRtmpStreamer::Codec GstRtmpStreamer::_codecFromCaps(const GstCaps *caps)
{
    if (!caps || gst_caps_is_empty(caps)) {
        return Codec::None;
    }

    const GstStructure *structure = gst_caps_get_structure(caps, 0);
    if (gst_structure_has_name(structure, "video/x-h264")) {
        return Codec::H264;
    }
    if (gst_structure_has_name(structure, "video/x-h265")) {
        return Codec::H265;
    }
    return Codec::Unsupported;
}

QString GstRtmpStreamer::_codecName(Codec codec)
{
    switch (codec) {
    case Codec::H264:
        return QStringLiteral("H.264");
    case Codec::H265:
        return QStringLiteral("H.265");
    default:
        return QString();
    }
}

QString GstRtmpStreamer::_describeUrl(const QString &url)
{
    // Show where we stream to without revealing the stream key.
    const QUrl parsed(url);
    QString text = parsed.scheme() + QStringLiteral("://") + parsed.host();
    if (parsed.port() > 0) {
        text += QLatin1Char(':') + QString::number(parsed.port());
    }
    const QStringList segments = parsed.path().split(QLatin1Char('/'), Qt::SkipEmptyParts);
    if (!segments.isEmpty()) {
        text += QLatin1Char('/') + segments.first();
    }
    return text;
}
