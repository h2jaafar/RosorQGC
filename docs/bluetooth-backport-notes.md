# Bluetooth link backport from upstream QGC v5.1.4

Branch `bt-backport-5.1.4`, based on `e99348c4` (RosorQGC master). Written 2026-09-06 without a Qt toolchain on the authoring machine: **this has not been compiled.** Expect at most a handful of trivial compile fixes; the seams are listed below.

## Why

RosorQGC's `src/Comms/BluetoothLink.cc` was the pre-BLE Qt 6 implementation. On Android 12+ (the Siyi UniRC 7 is Android 13) it requests the Bluetooth runtime permission only when a link is constructed, never before scanning, so the Comm Links scan fails silently, the paired radio never appears, and a saved link's first connect races the permission dialog and then reuses a dead socket. Upstream replaced the module in `e799c7604` (PR #13947, 2026-02-08) and hardened thread shutdown in `769445ca2` (2026-08-23); both are in v5.1.4.

## What changed

| Path | Change |
|---|---|
| `src/Comms/Bluetooth/*` | New: verbatim copy of v5.1.4 `src/Comms/Bluetooth/` (11 files), one edit below. |
| `src/Comms/BluetoothLink.{cc,h}` | Deleted. |
| `src/Comms/Bluetooth/BluetoothConfiguration.cc` | `QGCNetworkHelper::isBluetoothAvailable()` → `QGCDeviceInfo::isBluetoothAvailable()` (`DeviceInfo.h`); the fork has no `QGCNetworkHelper`. |
| `src/Comms/CMakeLists.txt` | Bluetooth block now `add_subdirectory(Bluetooth)` under the existing `QGC_ENABLE_BLUETOOTH` option. Upstream removed the option; the fork keeps it. |
| `src/Comms/LinkInterface.{h,cc}` | Added `_shutdownWorkerThread()` and `_orphanWorkerThread()` from v5.1.4. The new `BluetoothLink` destructor calls the former. Other links untouched. |
| `src/UI/AppSettings/BluetoothSettings.qml` | Replaced with the v5.1.4 page (upstream path `src/AppSettings/`). One edit: `root.qgc.showMessageDialog(root, …, Dialog.Ok)` → `mainWindow.showMessageDialog(…)`, since the fork's `QGroundControlQmlGlobal` has no `showMessageDialog`. |

Not brought over: `test/Comms/Bluetooth/*`. Upstream's tests use the April-2026 test framework (`UT_REGISTER_TEST`, `add_qgc_test`) which the fork does not have.

## Behaviour changes a pilot will notice

- Comm Links → Bluetooth now asks for the Bluetooth permission on **Scan**, lists **already-paired** devices with Pair/Unpair buttons, shows adapter state, and pops an error dialog instead of failing silently.
- Connect recreates the socket on every attempt and falls back to SDP service discovery when the SPP UUID lookup fails.
- A Classic / Low Energy mode switch appears. Siyi ground units are Classic (SPP).

## Build and test protocol

1. Build the Android APK as usual (`QGC_ENABLE_BLUETOOTH` is ON by default). Fork CI Qt is 6.10.1; the upstream module predates the 6.11 bump.
2. Factory-default UniRC 7 (datalink = Bluetooth, nothing changed in UniGCS). Install the APK. Do **not** pre-grant permissions.
3. Android Settings → Bluetooth → pair `BLUE94…`.
4. RosorQGC → Application Settings → Comm Links → Add → Bluetooth. Expected: permission prompt appears now; after Allow, `BLUE94…` shows in the paired list without scanning.
5. Select it, Connect. Expected: heartbeat within a few seconds, vehicle appears.
6. Disconnect / reconnect three times. Expected: no dead-socket state; each attempt connects.
7. Deny the permission once and confirm an error dialog is shown, then re-allow from Android app settings.
8. Regression: UDP and USB-serial links unaffected (the `LinkInterface` change is additive).
9. Windows build: confirm Comm Links still opens and the Bluetooth page renders; classic pairing UI may show "adapter unavailable" on a laptop without Bluetooth, which is correct.

Capture `adb logcat | grep -i -E "Bluetooth|qgc"` for any failure; the module logs under `Comms.Bluetooth.*` categories.

## Likely compile seams, in order of probability

1. `QThread::isCurrentThread()` needs Qt ≥ 6.8 (fork is 6.10.1, fine).
2. If `LinkInterface.h` gains a duplicate `class QThread;` forward declaration warning, drop the one I added.
3. Any `QGCPalette`/`SectionHeader` API drift between the fork's QmlControls and upstream's; both exist in the fork today.

## Follow-ups (not in this branch)

- Handheld profile auto-detect for the UniRC 7 (`Build.MODEL` = `Standard_94` / `Pro_94`): preset UDP `192.168.144.20:19856`, Bluetooth fallback. See `docs/productization-kickoff.md`.
- When the fork rebases onto `Stable_V5.1`, this whole branch collapses into upstream and should be dropped.
