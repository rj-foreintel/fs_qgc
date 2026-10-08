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
| Logo swap mechanism | `src/ForeViewPlugin.*` |

ArduPilot and PX4 support and the full stock QGC UI are left unchanged.

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

### Windows and Android

Run the **Windows** and **Android** workflows on the branch from the
fork's GitHub Actions tab (*Run workflow*). The installer and the APK are
attached to the run as artifacts.

The APK installs alongside stock QGroundControl on the SIYI MK15 because it
uses its own package ID. Without the `ANDROID_KEYSTORE_PASSWORD` secret, CI
signs each run with a new throwaway debug key, so to install a newer build you
must first uninstall the old one, which also deletes its settings. Set up a
release keystore before you hand ForeView to customers, so updates install
over the top.
