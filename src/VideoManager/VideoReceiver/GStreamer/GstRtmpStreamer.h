#pragma once

#include <QtCore/QAtomicInteger>
#include <QtCore/QElapsedTimer>
#include <QtCore/QMutex>
#include <QtCore/QTimer>

#include <gst/gst.h>

#include "VideoLiveStreamer.h"

/// Publishes encoded camera video to an RTMP/RTMPS server.
///
///   appsrc --> h264parse --> flvmux --> rtmp2sink
///
/// Only H.264 is published. H.265 cameras get a clear "set the camera to H.264"
/// status (see _pushLocked() for why Enhanced RTMP is not used).
///
/// GstVideoReceiver feeds it a copy of the compressed stream from its tee (see
/// pushSample()). The publisher is a separate pipeline: server errors are handled
/// here, with automatic retries, and never reach the receiver or the pilot's view.
class GstRtmpStreamer : public VideoLiveStreamer
{
    Q_OBJECT

public:
    explicit GstRtmpStreamer(QObject *parent = nullptr);
    ~GstRtmpStreamer() override;

    void start(const QString &url) override;
    void stop() override;

    /// Thread-safe. Called from the receiver's streaming thread for each encoded
    /// sample. Never blocks: if the publisher is busy the sample is dropped and the
    /// stream resumes at the next keyframe.
    void pushSample(GstSample *sample);

private:
    enum class Codec {
        None,
        H264,
        H265,
        Unsupported
    };

    // All of these require _lock.
    bool _buildPipeline(Codec codec, GstCaps *caps);
    void _destroyPipeline(bool sendEos);
    void _scheduleRetry(const QString &reason);
    void _pushLocked(GstBuffer *buffer, GstCaps *caps);

    void _poll();
    static Codec _codecFromCaps(const GstCaps *caps);
    static QString _codecName(Codec codec);
    static QString _describeUrl(const QString &url);

    QMutex _lock;
    QTimer _pollTimer;
    QElapsedTimer _clock;

    // Guarded by _lock
    QString _url;
    bool _wanted = false;
    GstElement *_pipeline = nullptr;
    GstElement *_appsrc = nullptr;
    GstElement *_sink = nullptr;
    Codec _pipelineCodec = Codec::None;
    Codec _lastCodec = Codec::None;
    bool _needKeyframe = true;
    GstClockTime _inBase = GST_CLOCK_TIME_NONE;
    GstClockTime _outBase = GST_CLOCK_TIME_NONE;
    GstClockTime _lastInTs = GST_CLOCK_TIME_NONE;
    GstClockTime _lastOutDts = GST_CLOCK_TIME_NONE;
    qint64 _lastSampleMs = -1;
    qint64 _retryAtMs = -1;
    int _retryDelayMs = kMinRetryDelayMs;
    QString _retryReason;
    QString _failReason;            ///< Non-empty: cannot stream _failedCodec at all
    Codec _failedCodec = Codec::None;
    guint64 _lastOutBytes = 0;
    qint64 _lastStatsMs = 0;
    bool _connected = false;

    /// Set by pushSample() when it skipped a sample because the publisher was busy.
    QAtomicInteger<bool> _resyncNeeded = false;

    static constexpr int kPollIntervalMs = 500;
    static constexpr int kMinRetryDelayMs = 2000;
    static constexpr int kMaxRetryDelayMs = 15000;
    static constexpr int kNoVideoTimeoutMs = 3000;
    /// Backlog (time queued in appsrc) above which frames are dropped until the next keyframe.
    static constexpr GstClockTime kMaxBacklog = 2 * GST_SECOND;
    /// A jump in the input timestamps larger than this is treated as a new stream.
    static constexpr GstClockTime kMaxTimestampJump = 5 * GST_SECOND;
};
