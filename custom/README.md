# ForeView custom build

ForeView is Foreintel Solutions' build of QGroundControl. Everything that makes
it ForeView lives in this `custom/` folder, so upstream QGC can be merged into
the fork without touching our changes.

## What this folder changes

| Area | File(s) |
|---|---|
| App name, organisation, package ID (`com.foreintel.foreview`) | `cmake/CustomOverrides.cmake` |
| In-app logo (toolbar, map GCS marker) and settings icon | `res/QGCLogoFull.svg`, `res/QGCLogoWhite.svg` |
| Window / taskbar icon | `res/icons/ForeView.ico` (via `custom.qrc`) |
| Windows exe icon and installer header | `deploy/windows/` |
| Linux desktop icon | `res/icons/ForeView_256.png`, `res/icons/ForeView.svg` |
| Android launcher icon, splash and adaptive-icon background | `android/res/` |
| Logo swap and QML override mechanism, ForeView palette, light "Outdoor" colours by default | `src/ForeViewPlugin.*` |
| Customer mode / Debug Mode switch and password check | `src/ForeViewMode.*`, `CMakeLists.txt` |
| "Not connected · Tap to connect" and auto-connect retries in customer mode | `src/ForeViewLinks.*` |
| Android start-up screen (app icon + "Powered by Foreintel") | `android/res/drawable*/`, `tools/make_splash.py` |
| SIYI camera control (photo, video, zoom, centre, colour/thermal/side by side, thermal colours and range) | `src/ForeViewCamera.*` |
| Customer Fly view | `qml/Customer/` |
| Stock QML files replaced for customer mode | `qml/overrides/` (see below) |

ArduPilot and PX4 support are left unchanged, and Debug Mode is the full stock QGC UI.

Changes outside `custom/` (keep them when merging upstream QGC):

- `src/VideoManager/VideoManager.*`: `setSecondaryStreamUri()` plays a second stream in QGC's
  thermal video output when the vehicle announces no thermal stream (used for side by side).
- `src/VideoManager/VideoReceiver/GStreamer/GstVideoReceiver.cc`: the RTSP jitter buffer is
  200 ms and keeps late packets unless Low Latency Mode is on (25 ms, drops late packets).
  The short buffer smeared the SIYI A8 mini picture whenever the radio link delayed packets.
  The same file also holds frames back until the first key frame when decoding starts (no grey
  blocks at start-up; gives up after 3 s), and applies the new RTSP transport setting.
- `src/Settings/Video.SettingsGroup.json`, `VideoSettings.*`, `src/AppSettings/pages/Video.SettingsUI.json`,
  `VideoReceiver.h`, `VideoManager.cc`: "RTSP transport" (Automatic / UDP / TCP) in Settings > Video.
- `src/VideoManager/VideoReceiver/VideoLiveStreamer.h`, `GstRtmpStreamer.*`: camera rate, queued video
  and "upload too slow" for the LIVE panel.
- `src/Comms/UDPLink.*`: a UDP port that cannot be bound is retried every 2 s instead of leaving the
  link dead until restart (e.g. port still held by another app at start-up).

## Customer mode and Debug Mode

ForeView always starts in **customer mode**:

- The Fly view is replaced by `qml/Customer/CustomerFlyLayer.qml`: status, flight mode
  (shown only; modes are changed with the switches on the remote), GPS, RC, battery, LIVE,
  telemetry, warnings (signal lost, battery, pre-arm failures, GPS), and Home / Land /
  Pause / Mission buttons that each need a slide to confirm. Tapping the map does nothing.
  Tapping the status opens the drone's messages (live, with a Clear button); QGC's status
  panel (with Force Arm and vehicle setup) is never shown.
- The telemetry strip shows height, distance, speed, climb, flight time (from arming, as in stock
  QGC) and the drone's latitude / longitude (tap to copy). Tapping the GPS count shows fix, HDOP,
  VDOP and position.
- With no drone connected the status reads "Not connected · Tap to connect": tapping connects the
  saved links that have "Automatically Connect on Start" (or the only saved link). In customer
  mode those links are also retried every 5 s while no drone is connected (TCP links are probed
  first so a failed retry shows no error).
- The battery shows voltage by default and takes its colour and low/critical warnings from
  the flight controller's charge state (ArduPilot `BATT_LOW_VOLT` / `BATT_CRT_VOLT`). The
  remaining % is ArduPilot's estimate from mAh used since power-on against `BATT_CAPACITY`
  and assumes a full pack at power-on, so it is shown only in the tap-for-details panel
  (or in the bar if the customer picks it there).
- Camera buttons talk to the SIYI camera directly over SIYI's SDK (UDP port 37260 on the
  host in the RTSP URL), so customers do not need the SIYI FPV app. Each time the camera
  (re)connects, ForeView reads back its zoom, colour/thermal view, thermal colours and range.
- ZT6/ZT30 "Side by side" (camera sheet, or "Both" on the camera rail) sets the stream being
  watched to colour and plays the camera's other stream (`video1` <-> `video2` in the RTSP
  URL) as thermal in the right half. It needs an RTSP URL ending in `/video1` or `/video2`,
  is off after a restart, and the LIVE stream still sends only the main (left) video.
- The view menu has Fly, Plan, Settings and Close. Plan is the full stock Plan view: QGC's
  "advanced UI" switch is kept on in both modes because it only adds Plan options (camera
  actions at mission start, "Show all values").
- Settings shows General, Plan View, Maps, Video and Help only.

**Debug Mode** is the full QGroundControl UI. To unlock it, tap "ForeView" in the top-left
of the Fly view seven times quickly and enter the company password. It switches off again
from the view menu ("Exit Debug Mode") and on every app restart. Five wrong passwords lock
the prompt for 30 seconds.

### The password

The password is given to CMake as the `FOREVIEW_DEBUG_PASSWORD` environment variable; CI
takes it from the repository secret of the same name. CMake stores only a random salt and a
stretched SHA-256 hash in the app (`ForeViewDebugPassword.h` in the build folder), never the
password. To change it, change the secret and rebuild.

Without the variable, local and feature-branch builds use the development password
`foreview-dev` and CMake prints a warning. `foreview-main` builds fail without the secret,
so a release can never ship with the development password.

### Replaced stock QML files

These are copies of stock QGC files with small ForeView changes. When merging a newer QGC
from `master`, compare each with its original and carry upstream changes across:

| ForeView copy | Stock original | What changed |
|---|---|---|
| `qml/overrides/FlyView.qml` | `src/FlyView/FlyView.qml` | Customer layer added; stock toolbar and widgets hidden in customer mode; no guided actions from the map; critical-message "more" opens the customer message list |
| `qml/overrides/SelectViewDropdown.qml` | `src/Toolbar/SelectViewDropdown.qml` | Analyze and Configure only in Debug Mode; "Exit Debug Mode"; advanced-mode toggle removed |
| `qml/overrides/AppSettings.qml` | `src/QmlControls/AppSettings.qml` | Customer mode lists only the customer settings pages |
| `qml/overrides/FlightDisplayViewVideo.qml` | `src/FlyView/FlightDisplayViewVideo.qml` | Side by side: main video in the left half, second stream (thermal output) in the right half |

To replace a stock QGC image, add a file to `custom.qrc` under the
`/Custom` prefix with the same path as the original. For example,
`/Custom/res/Foo.svg` overrides `/res/Foo.svg`.

## Building

The `custom/` folder is picked up automatically by every build, local or CI.

### Linux (local)

You need Qt 6.10 with the modules listed in `.github/build-config.json`.

```bash
python3 tools/setup/install_dependencies.py      # system packages (Debian/Ubuntu)
python3 tools/setup/install_qt.py                # Qt 6.10 via aqtinstall
cmake -S . -B build -G Ninja -DCMAKE_BUILD_TYPE=Release -DCMAKE_PREFIX_PATH=<Qt>/gcc_64
cmake --build build
./build/Release/ForeView                         # or: cmake --install build to make an AppImage
```

### Branches and CI builds

| Branch | Purpose | CI result |
|---|---|---|
| `foreview-main` | The ForeView main branch. Everything we ship is merged here. | Linux, Windows and Android builds, published as a GitHub pre-release |
| `foreview-<feature>` (e.g. `foreview-rtmp`) | One branch per change. Merge it into `foreview-main` when it is done. | The same three builds, attached to the Actions run as artifacts (no release) |
| `master` | Untouched copy of upstream QGroundControl. Merge it into `foreview-main` to pick up QGC updates. | — |

The workflow is `.github/workflows/foreview.yml`. Other branch names are not
built automatically; use *Run workflow* on the ForeView workflow in the
Actions tab to build them.

The APK installs alongside stock QGroundControl on the SIYI MK15 because it
uses its own package ID. Without the `ANDROID_KEYSTORE_PASSWORD` secret, CI
signs each run with a new throwaway debug key, so to install a newer build you
must first uninstall the old one, which also deletes its settings. Set up a
release keystore before you hand ForeView to customers, so updates install
over the top.
