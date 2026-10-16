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
| SIYI camera control (photo, video, zoom, centre, colour/thermal, thermal colours and range) | `src/ForeViewCamera.*` |
| Customer Fly view | `qml/Customer/` |
| Stock QML files replaced for customer mode | `qml/overrides/` (see below) |

ArduPilot and PX4 support are left unchanged, and Debug Mode is the full stock QGC UI.

## Customer mode and Debug Mode

ForeView always starts in **customer mode**:

- The Fly view is replaced by `qml/Customer/CustomerFlyLayer.qml`: status, flight mode
  (shown only; modes are changed with the switches on the remote), GPS, RC, battery, LIVE,
  telemetry, and Home / Land / Pause / Mission buttons that each need a slide to confirm.
  Tapping the map does nothing.
- Camera buttons talk to the SIYI camera directly over SIYI's SDK (UDP port 37260 on the
  host in the RTSP URL), so customers do not need the SIYI FPV app.
- The view menu has Fly, Plan, Settings and Close. Plan is the full stock Plan view.
- Settings shows General, Plan View, Maps, Video and Help only.

**Debug Mode** is the full QGroundControl UI. To unlock it, tap "ForeView" in the top-left
of the Fly view seven times quickly and enter the company password. It switches off again
from the view menu ("Exit Debug Mode") and on every app restart. QGC's own "Advanced Mode"
switch cannot turn it on.

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
| `qml/overrides/FlyView.qml` | `src/FlyView/FlyView.qml` | Customer layer added; stock toolbar and widgets hidden in customer mode; no guided actions from the map |
| `qml/overrides/SelectViewDropdown.qml` | `src/Toolbar/SelectViewDropdown.qml` | Configure only in Debug Mode; "Exit Debug Mode"; advanced-mode toggle removed |
| `qml/overrides/AppSettings.qml` | `src/QmlControls/AppSettings.qml` | Customer mode lists only the customer settings pages |

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
