#pragma once

#include <QtCore/QObject>
#include <QtCore/QTimer>

/// Customer mode / Debug Mode switch for ForeView.
///
/// ForeView always starts in customer mode: a simplified Fly view, no vehicle setup, parameters
/// or analyze tools. Debug Mode is the full QGroundControl UI and is unlocked with the company
/// password. The password itself is never stored in the app: CMake hashes it at configure time
/// (see custom/CMakeLists.txt) and only the salt and the stretched SHA-256 hash are compiled in.
/// Debug Mode is not persisted, so the app re-locks on every restart.
class ForeViewMode : public QObject
{
    Q_OBJECT

    Q_PROPERTY(bool debugMode       READ debugMode      NOTIFY debugModeChanged)
    Q_PROPERTY(int  lockoutSeconds  READ lockoutSeconds NOTIFY lockoutSecondsChanged)

public:
    explicit ForeViewMode(QObject *parent = nullptr);

    bool debugMode() const { return _debugMode; }

    /// Seconds left before another password attempt is accepted (0 when not locked out).
    int lockoutSeconds() const { return _lockoutSeconds; }

    /// Switches to Debug Mode when @p password is the company password.
    /// @return true if Debug Mode is now on.
    Q_INVOKABLE bool unlock(const QString &password);

    /// Returns to customer mode.
    Q_INVOKABLE void lock();

    /// Stretched hash used both here and in custom/CMakeLists.txt:
    ///   h = sha256hex(salt + password), then (iterations - 1) times h = sha256hex(h + salt)
    static QByteArray hashPassword(const QString &password, const QByteArray &salt, int iterations);

signals:
    void debugModeChanged(bool debugMode);
    void lockoutSecondsChanged();

private:
    void _setDebugMode(bool enabled);
    void _onLockoutTick();

    bool _debugMode = false;
    int _failedAttempts = 0;
    int _lockoutSeconds = 0;
    QTimer _lockoutTimer;

    static constexpr int kMaxFailedAttempts = 5;
    static constexpr int kLockoutSeconds = 30;
};
