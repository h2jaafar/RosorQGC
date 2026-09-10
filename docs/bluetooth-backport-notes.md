# Bluetooth link backport from upstream QGC v5.1.4

Branch `bt-backport-5.1.4`, based on `e99348c4` (RosorQGC master). Written 2026-09-06 without a Qt toolchain on the authoring machine: **this has not been compiled.** Expect at most a handful of trivial compile fixes; the seams are listed below.

## Why

RosorQGC's `src/Comms/BluetoothLink.cc` was the pre-BLE Qt 6 implementation. It requests the Bluetooth runtime permission only when a link is constructed, never before scanning, so the Comm Links scan fails silently, the paired radio never appears, and a saved link's first connect races the permission dialog and then reuses a dead socket. The trigger is the app's **targetSdk**, not the OS version: `BLUETOOTH_SCAN`/`BLUETOOTH_CONNECT` are only runtime-enforced for apps targeting SDK >= 31. The fork targets SDK 35 (`android_platform` in `.github/build-config.json`), so it is in the enforced regime. Verified on the bench 2026-09-10: stock QGC v4.4.5 (targetSdk 28) is auto-granted both permissions at install on the same Android 13 handheld and its old-module scan works, which is why this only bites builds that target 31+. Upstream replaced the module in `e799c7604` (PR #13947, 2026-02-08) and hardened thread shutdown in `769445ca2` (2026-08-23); both are in v5.1.4.

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

1. Build the Android APK as usual (`QGC_ENABLE_BLUETOOTH` is ON by default). Fork CI Qt is 6.10.1. Note the module does **not** wholly predate upstream's Qt 6.11 bump: upstream moved to 6.11.1 in `a03f300df` (2026-06-17) and `769445ca2` landed 2026-08-23, after it. That commit is still 6.10-safe because the only version-sensitive API it adds is `QThread::isCurrentThread()` (Qt >= 6.8), but the original reasoning here was wrong and should not be reused for further backports from that tree.
2. Factory-default UniRC 7 (datalink = Bluetooth, nothing changed in UniGCS). Install the APK. Do **not** pre-grant permissions.
3. Android Settings → Bluetooth → pair `BLUE94…`.
4. RosorQGC → Application Settings → Comm Links → Add → Bluetooth. Expected: the page opens showing "Bluetooth adapter unavailable" and logs `allDevices() failed due to missing permissions`; the permission prompt fires on **Scan for Devices**, not on opening the page. After Allow, the adapter resolves and `BLUE94…` appears under **Known Devices** without a further scan.
5. Select it, Connect. Expected: heartbeat within a few seconds, vehicle appears.
6. Disconnect / reconnect three times. Expected: no dead-socket state; each attempt connects.
7. Deny the permission once and confirm an error dialog is shown, then re-allow from Android app settings.
8. Regression: UDP and USB-serial links unaffected (the `LinkInterface` change is additive).
9. Windows build: confirm Comm Links still opens and the Bluetooth page renders; classic pairing UI may show "adapter unavailable" on a laptop without Bluetooth, which is correct.

Capture `adb logcat | grep -i -E "Bluetooth|qgc"` for any failure; the module logs under `Comms.Bluetooth.*` categories.

## Likely compile seams, in order of probability

1. `QThread::isCurrentThread()` needs Qt ≥ 6.8 (fork is 6.10.1, fine).
2. ~~If `LinkInterface.h` gains a duplicate `class QThread;` forward declaration warning, drop the one I added.~~ **Hit, and it was a hard error, not a warning.** The declaration was emitted twice: correctly at file scope and again *inside* the class body. In class scope that declares a nested `LinkInterface::QThread` which shadows the global `::QThread` for the whole class, so both new thread helpers took a pointer to an incomplete nested type: every `thread->quit()/wait()/terminate()` in `LinkInterface.cc` fails and `BluetoothLink.cc`'s real `::QThread*` argument will not convert. Fixed by deleting the in-class one.
3. Any `QGCPalette`/`SectionHeader` API drift between the fork's QmlControls and upstream's; both exist in the fork today.

## Rig test 2026-09-10 (Leo, bench)

Run against **stock QGC v5.1.4** on a factory-default UniRC 7 (`Standard_94`, Android 13 / SDK 33,
arm64-v8a), driven over `adb`. Stock v5.1.4 carries the same module this branch backports, so this
exercises the upstream code on the real handheld and radio *before* the fork's own APK exists.
It does **not** test this branch's port. Radio `BLUE-9401143881` (`41:42:80:8A:20:A6`, BR/EDR) was
already bonded from the factory, so protocol step 3 was a no-op.

Result: steps 4-7 all pass.

- Step 4 pass, with the timing correction above. Adapter resolved to `QCOM-BTD`, Connectable,
  Powered On; `BLUE-9401143881` listed under Known Devices; nearby devices under Available.
- Step 5 pass. Vehicle STATUSTEXT and `AUTOPILOT_VERSION` arrived over SPP; ArduPilot 4.6.3
  identified. MAVLink flows.
- Step 6 pass, 3/3 reconnects, plus a 4th across an app restart and a permission revoke. No
  dead-socket state. The documented recovery paths do fire and do recover:
  `read failed, socket might closed or timeout` then `Falling back to reverse uuid workaround`
  (SDP fallback), and Android logs `Cannot start RFCOMM listener: UUID ... already in use` on each
  connect, which is benign since every connect succeeded.
- Step 7 pass. Denying at the prompt produced the dialog **"Bluetooth Link Error" / "Link SiyiBT:
  (Device: BLUE-9401143881) Bluetooth Permission Denied"**, logged from
  `BluetoothLink::_handlePermissionStatus:160` and `_onErrorOccurred:102`. The link reverted to
  Connect rather than sticking; re-allowing recovered.
- Step 8 not exercised on the bench: no UDP source was reachable because the handheld's `wlan0`
  was on office Wi-Fi, which displaces the `192.168.144.x` link to the air unit (the UniRC 7 has
  only `wlan0`; there is no separate Siyi interface). Verified statically instead: the
  `LinkInterface` change is additive and no other link calls the new helpers.

### Upstream defects observed (present in upstream, not introduced here)

1. **Stale pairing label.** With no device selected, the Pairing row reads "Adapter unavailable"
   even once the adapter is up and Connectable. It is reporting the *selected device's* pairing
   state through an adapter-flavoured string; it should say no device is selected. Clears as soon
   as a device is picked ("Paired" + Unpair).
2. **Discovery start/stop race on first grant.** Immediately after the permission is granted the
   module calls `startDiscovery` then `cancelDiscovery` twice within ~14 ms, and Qt reports
   `QBluetoothDeviceDiscoveryAgent::InputOutputError "Discovery cannot be stopped"` via
   `BluetoothConfiguration::_onDiscoveryErrorOccurred:688`. Discovery then works, so it is cosmetic
   in effect, but it is a real race and worth reporting upstream.

Also noted: stock v4.4.5 installs as package `org.mavlink.qgroundcontrolbeta`, v5.1.4 as
`org.mavlink.qgroundcontrol`, and this fork as `ca.rosor.qgc`. All three coexist on one handheld,
so bracketing needs no uninstall cycles and no fork/stock permission bleed is possible.

## Follow-ups (not in this branch)

- Handheld profile auto-detect for the UniRC 7 (`Build.MODEL` = `Standard_94` / `Pro_94`): preset UDP `192.168.144.20:19856`, Bluetooth fallback. See `docs/productization-kickoff.md`.
- When the fork rebases onto `Stable_V5.1`, this whole branch collapses into upstream and should be dropped.
