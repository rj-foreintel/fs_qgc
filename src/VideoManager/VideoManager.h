#pragma once

#include <QtCore/QFuture>
#include <QtCore/QPromise>
#include <QtCore/QObject>
#include <QtCore/QSize>
#include <QtQmlIntegration/QtQmlIntegration>

#include <functional>
#include <memory>

class QQuickWindow;
class SiyiCameraEncoding;
class SubtitleWriter;
class Vehicle;
class VideoLiveStreamer;
class VideoReceiver;
class VideoSettings;

class VideoManager : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_UNCREATABLE("")
    Q_MOC_INCLUDE("Vehicle.h")
    Q_MOC_INCLUDE("VideoLiveStreamer.h")
    Q_MOC_INCLUDE("SiyiCameraEncoding.h")

    Q_PROPERTY(bool     gstreamerEnabled        READ gstreamerEnabled                           CONSTANT)
    Q_PROPERTY(bool     qtmultimediaEnabled     READ qtmultimediaEnabled                        CONSTANT)
    Q_PROPERTY(bool     uvcEnabled              READ uvcEnabled                                 CONSTANT)
    Q_PROPERTY(bool     autoStreamConfigured    READ autoStreamConfigured                       NOTIFY autoStreamConfiguredChanged)
    Q_PROPERTY(bool     decoding                READ decoding                                   NOTIFY decodingChanged)
    Q_PROPERTY(bool     fullScreen              READ fullScreen             WRITE setfullScreen NOTIFY fullScreenChanged)
    Q_PROPERTY(bool     hasThermal              READ hasThermal                                 NOTIFY decodingChanged)
    Q_PROPERTY(bool     hasVideo                READ hasVideo                                   NOTIFY hasVideoChanged)
    Q_PROPERTY(bool     isStreamSource          READ isStreamSource                             NOTIFY isStreamSourceChanged)
    Q_PROPERTY(bool     isUvc                   READ isUvc                                      NOTIFY isUvcChanged)
    Q_PROPERTY(bool     recording               READ recording                                  NOTIFY recordingChanged)
    Q_PROPERTY(bool     streaming               READ streaming                                  NOTIFY streamingChanged)
    Q_PROPERTY(double   aspectRatio             READ aspectRatio                                NOTIFY aspectRatioChanged)
    Q_PROPERTY(double   hfov                    READ hfov                                       NOTIFY aspectRatioChanged)
    Q_PROPERTY(double   thermalAspectRatio      READ thermalAspectRatio                         NOTIFY aspectRatioChanged)
    Q_PROPERTY(double   thermalHfov             READ thermalHfov                                NOTIFY aspectRatioChanged)
    Q_PROPERTY(QSize    videoSize               READ videoSize                                  NOTIFY videoSizeChanged)
    Q_PROPERTY(QString  imageFile               READ imageFile                                  NOTIFY imageFileChanged)
    Q_PROPERTY(QString  uvcVideoSourceID        READ uvcVideoSourceID                           NOTIFY uvcVideoSourceIDChanged)
    /// RTMP publisher for the main video stream; nullptr when the video backend cannot stream.
    Q_PROPERTY(VideoLiveStreamer *liveStreamer  READ liveStreamer                               NOTIFY liveStreamerChanged)
    /// Switches SIYI cameras from H.265 to H.264 (needed for live streaming).
    Q_PROPERTY(SiyiCameraEncoding *siyiCameraEncoding READ siyiCameraEncoding                   CONSTANT)
    /// Second stream played in the "thermalVideo" output when the vehicle announces no thermal
    /// stream (set by custom builds, e.g. to show two camera streams side by side). Empty: none.
    Q_PROPERTY(QString  secondaryStreamUri      READ secondaryStreamUri                         NOTIFY secondaryStreamUriChanged)
    Q_PROPERTY(bool     secondaryDecoding       READ secondaryDecoding                          NOTIFY secondaryDecodingChanged)
    Q_PROPERTY(QSize    secondaryVideoSize      READ secondaryVideoSize                         NOTIFY secondaryVideoSizeChanged)

    friend class VideoManagerInitTest;

public:
    explicit VideoManager(QObject *parent = nullptr);
    ~VideoManager();

    static VideoManager *instance();

    Q_INVOKABLE void grabImage(const QString &imageFile = QString());
    Q_INVOKABLE void startRecording(const QString &videoFile = QString());
    Q_INVOKABLE void startVideo();
    Q_INVOKABLE void stopRecording();
    Q_INVOKABLE void stopVideo();
    /// Starts sending the main video to the RTMP URL in Video settings (if live streaming is enabled).
    Q_INVOKABLE void startLiveStream();
    Q_INVOKABLE void stopLiveStream();
    /// Switches the SIYI camera that serves the main video stream to H.264.
    Q_INVOKABLE void switchCameraToH264();

    void init(QQuickWindow *mainWindow);
    void startGStreamerInit();
    bool waitForGStreamerInit(int timeoutMs = 60000);
    void cleanup();
    bool autoStreamConfigured() const;
    bool decoding() const { return _decoding; }
    bool fullScreen() const { return _fullScreen; }
    bool hasThermal() const;
    bool hasVideo() const;
    bool isStreamSource() const;
    bool isUvc() const;
    bool recording() const { return _recording; }
    bool streaming() const { return _streaming; }
    double aspectRatio() const;
    double hfov() const;
    double thermalAspectRatio() const;
    double thermalHfov() const;
    QSize videoSize() const { return _videoSize; }
    QString imageFile() const { return _imageFile; }
    QString uvcVideoSourceID() const { return _uvcVideoSourceID; }
    VideoLiveStreamer *liveStreamer() const;
    SiyiCameraEncoding *siyiCameraEncoding() const { return _siyiCameraEncoding; }
    QString secondaryStreamUri() const { return _secondaryStreamUri; }
    bool secondaryDecoding() const { return _secondaryDecoding; }
    QSize secondaryVideoSize() const { return _secondaryVideoSize; }
    void setSecondaryStreamUri(const QString &uri);
    static bool isValidLiveStreamUrl(const QString &url);
    void setfullScreen(bool on);
    static bool gstreamerEnabled();
    static bool qtmultimediaEnabled();
    static bool uvcEnabled();

signals:
    void aspectRatioChanged();
    void autoStreamConfiguredChanged();
    void decodingChanged();
    void fullScreenChanged();
    void hasVideoChanged();
    void imageFileChanged(const QString &filename);
    void isAutoStreamChanged();
    void isStreamSourceChanged();
    void isUvcChanged();
    void liveStreamerChanged();
    void recordingChanged(bool recording);
    void recordingStarted(const QString &filename);
    void secondaryDecodingChanged();
    void secondaryStreamUriChanged();
    void secondaryVideoSizeChanged();
    void streamingChanged();
    void uvcVideoSourceIDChanged();
    void videoSizeChanged();

private slots:
    void _communicationLostChanged(bool communicationLost);
    void _setActiveVehicle(Vehicle *vehicle);
    void _videoSourceChanged();

private:
    enum class InitState : uint8_t {
        NotStarted,
        Pending,
        GstReady,
        QmlReady,
        Running,
        Failed
    };

    static bool _shouldSkipGStreamerForUnitTests();
    void _initAfterQmlIsReady();
    void _onGstInitComplete(bool success);
    void _createVideoReceivers();
    void _initVideoReceiver(VideoReceiver *receiver, QQuickWindow *window);
    bool _updateAutoStream(VideoReceiver *receiver);
    bool _updateUVC(VideoReceiver *receiver);
    bool _updateSettings(VideoReceiver *receiver);
    bool _updateVideoUri(VideoReceiver *receiver, const QString &uri);
    void _restartAllVideos();
    void _restartVideo(VideoReceiver *receiver);
    void _startReceiver(VideoReceiver *receiver);
    void _stopReceiver(VideoReceiver *receiver);
    static void _cleanupOldVideos();

    QList<VideoReceiver*> _videoReceivers;
    SubtitleWriter *_subtitleWriter = nullptr;
    SiyiCameraEncoding *_siyiCameraEncoding = nullptr;
    VideoSettings *_videoSettings = nullptr;
    QQuickWindow *_mainWindow = nullptr;
    Vehicle *_activeVehicle = nullptr;

    InitState _initState = InitState::NotStarted;
    QFuture<bool> _gstInitFuture;
#if defined(QGC_GST_STREAMING) && defined(Q_OS_ANDROID)
#endif
    bool _initialized = false;
    bool _gstreamerDisabledForUnitTests = false;
    bool _fullScreen = false;

    QAtomicInteger<bool> _decoding = false;
    QAtomicInteger<bool> _recording = false;
    QAtomicInteger<bool> _streaming = false;
    QAtomicInteger<bool> _secondaryDecoding = false;
    QSize _videoSize;
    QSize _secondaryVideoSize;
    QString _secondaryStreamUri;
    QString _imageFile;
    QString _uvcVideoSourceID;

#ifdef QGC_UNITTEST_BUILD
    std::function<void()> _createVideoReceiversForTest;
#endif
};
