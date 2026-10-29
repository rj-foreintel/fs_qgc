#pragma once

#include <QtCore/QObject>
#include <QtCore/QTimer>
#include <QtNetwork/QHostAddress>

class QUdpSocket;

/// Controls a SIYI gimbal camera (A8 mini, ZR10, ZR30, ZT6, ZT30) straight from ForeView, so
/// customers do not have to switch to the SIYI FPV app: photo, video recording, zoom, centring,
/// colour/thermal main view, thermal colours and thermal range.
///
/// Uses SIYI's camera SDK protocol over UDP port 37260 on the camera, the host taken from the
/// RTSP URL in Settings > Video. Command IDs and values follow SIYI's SDK as used by ArduPilot's
/// AP_Mount_Siyi driver. Photos and videos are stored on the camera's SD card.
class ForeViewCamera : public QObject
{
    Q_OBJECT

    Q_PROPERTY(bool     connected           READ connected          NOTIFY connectedChanged)
    Q_PROPERTY(QString  model               READ model              NOTIFY connectedChanged)
    Q_PROPERTY(bool     thermalSupported    READ thermalSupported   NOTIFY connectedChanged)
    Q_PROPERTY(bool     recording           READ recording          NOTIFY recordingChanged)
    Q_PROPERTY(bool     sdCardMissing       READ sdCardMissing      NOTIFY recordingChanged)
    Q_PROPERTY(double   zoom                READ zoom               NOTIFY zoomChanged)
    Q_PROPERTY(bool     thermalView         READ thermalView        NOTIFY thermalViewChanged)
    Q_PROPERTY(int      thermalPalette      READ thermalPalette     NOTIFY thermalPaletteChanged)
    Q_PROPERTY(bool     thermalHighRange    READ thermalHighRange   NOTIFY thermalHighRangeChanged)
    /// Colour and thermal shown side by side: the RTSP stream from Settings > Video shows colour
    /// and the camera's other stream (video1 <-> video2) shows thermal.
    Q_PROPERTY(bool     sideBySide          READ sideBySide         NOTIFY sideBySideChanged)

public:
    explicit ForeViewCamera(QObject *parent = nullptr);

    bool connected() const { return _connected; }
    QString model() const { return _model; }
    bool thermalSupported() const { return (_model == QStringLiteral("ZT6")) || (_model == QStringLiteral("ZT30")); }
    bool recording() const { return _recordStatus == kRecordOn; }
    bool sdCardMissing() const { return _recordStatus == kRecordNoCard; }
    double zoom() const { return _zoom; }
    bool thermalView() const { return _thermalView; }
    int thermalPalette() const { return _thermalPalette; }
    bool thermalHighRange() const { return _thermalHighRange; }
    bool sideBySide() const { return _sideBySide; }
    /// RTSP URL of the second stream while side by side is on, otherwise empty.
    QString secondaryStreamUrl() const { return _sideBySide ? otherStreamUrl(_rtspUrl()) : QString(); }

    Q_INVOKABLE void takePhoto();
    Q_INVOKABLE void toggleRecording();
    /// Zoom keeps moving until zoomStop() is called (press and hold).
    Q_INVOKABLE void zoomIn();
    Q_INVOKABLE void zoomOut();
    Q_INVOKABLE void zoomStop();
    Q_INVOKABLE void center();
    /// true: thermal sensor on the video the pilot sees, false: colour sensor. Ends side by side.
    Q_INVOKABLE void setThermalView(bool thermal);
    /// Thermal cameras only; needs an RTSP URL ending in /video1 or /video2.
    Q_INVOKABLE void setSideBySide(bool on);
    /// SIYI palette value: 0 White hot, 2 Sepia, 3 Ironbow, 4 Rainbow, 5 Night, 6 Aurora,
    /// 7 Red hot, 8 Jungle, 9 Medical, 10 Black hot, 11 Glory hot.
    Q_INVOKABLE void setThermalPalette(int palette);
    /// false: everyday range (-20 to 150 C, high gain), true: hot objects (50 to 550 C, low gain).
    Q_INVOKABLE void setThermalHighRange(bool highRange);

    /// Model name from the two-character SIYI hardware ID (exposed for tests).
    static QString modelFromHardwareId(char first, char second);
    /// The camera's other stream: .../video1 <-> .../video2. Empty for any other URL.
    static QString otherStreamUrl(const QString &rtspUrl);

signals:
    void connectedChanged();
    void recordingChanged();
    void zoomChanged();
    void thermalViewChanged();
    void thermalPaletteChanged();
    void thermalHighRangeChanged();
    /// Also emitted when the second stream's URL changes.
    void sideBySideChanged();
    /// Short message for the pilot, e.g. "Photo saved" or "No SD card in the camera".
    void notice(const QString &text, bool error);

private:
    void _poll();
    void _onReadyRead();
    void _handleFrame(quint8 cmdId, const QByteArray &data);
    void _send(quint8 cmdId, const QByteArray &data);
    void _send(quint8 cmdId, quint8 value) { _send(cmdId, QByteArray(1, static_cast<char>(value))); }
    bool _updateHost();
    bool _viewingSubStream() const;
    static QString _rtspUrl();
    void _applyThermalView(bool thermal);
    void _rtspUrlChanged();
    void _setConnected(bool isConnected);
    void _requestState();
    static bool _parseFrame(const QByteArray &datagram, quint8 &cmdId, QByteArray &data);

    QUdpSocket *_socket = nullptr;
    QTimer _pollTimer;
    QHostAddress _host;
    quint16 _seq = 0;
    int _missedPolls = 0;
    bool _photoPending = false;

    bool _connected = false;
    QString _model;
    quint8 _recordStatus = 0;
    double _zoom = 1.0;
    bool _thermalView = false;
    int _thermalPalette = 0;
    bool _thermalHighRange = false;
    bool _sideBySide = false;
    QString _secondaryStreamUrl;

    static constexpr quint16 kPort = 37260;
    static constexpr int kPollIntervalMs = 2000;
    static constexpr int kMissedPollsBeforeDisconnect = 3;

    // SIYI SDK command IDs
    static constexpr quint8 kCmdHardwareId = 0x02;
    static constexpr quint8 kCmdManualZoom = 0x05;
    static constexpr quint8 kCmdCenter = 0x08;
    static constexpr quint8 kCmdConfigInfo = 0x0A;
    static constexpr quint8 kCmdFunctionFeedback = 0x0B;
    static constexpr quint8 kCmdPhoto = 0x0C;
    static constexpr quint8 kCmdGetImageType = 0x10;
    static constexpr quint8 kCmdSetImageType = 0x11;
    static constexpr quint8 kCmdGetThermalPalette = 0x1A;
    static constexpr quint8 kCmdSetThermalPalette = 0x1B;
    static constexpr quint8 kCmdGetThermalGain = 0x37;
    static constexpr quint8 kCmdSetThermalGain = 0x38;

    // 0x37/0x38 thermal gain values
    static constexpr quint8 kGainLow = 0;     // 50 to 550 C ("Hot objects")
    static constexpr quint8 kGainHigh = 1;    // -20 to 150 C ("Everyday")

    // 0x0C photo function values
    static constexpr quint8 kPhotoTake = 0;
    static constexpr quint8 kPhotoRecordToggle = 2;

    // 0x0A record status values
    static constexpr quint8 kRecordOn = 1;
    static constexpr quint8 kRecordNoCard = 2;

    // 0x0B function feedback values
    static constexpr quint8 kFeedbackSuccess = 0;
    static constexpr quint8 kFeedbackPhotoFailed = 1;
    static constexpr quint8 kFeedbackRecordFailed = 4;

    // 0x11 camera image types used here
    static constexpr quint8 kImageMainZoomSubThermal = 3;
    static constexpr quint8 kImageMainThermalSubZoom = 7;
    static constexpr quint8 kImageMainThermalSubWide = 8;
};
