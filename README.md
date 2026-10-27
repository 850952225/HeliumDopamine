# HeliumDopamine — iOS 17 / Dopamine prototype

This is an independent Theos rootless tweak prototype inspired by the feature set the user wants to port from Helium. It is not the original application's code and does not yet reproduce every original feature.

## Implemented in source
- SpringBoard HUD overlay
- Approximate CPU activity for the injected SpringBoard process
- System memory statistics via Mach host statistics
- Network byte-rate estimates from interface counters
- Battery level
- Reads basic options from `/var/mobile/Library/Preferences/com.example.heliumdopamine.plist`
- Post-screenshot HUD hiding (not pre-capture exclusion)

## Build
Use Theos on a Mac/Linux build machine with a suitable iOS SDK. Run `make package`. Install the generated rootless `.deb` on a device you own, then respring. This source has **not** been compiled or tested on-device here.

## Preferences
The tweak reads these keys from `com.example.heliumdopamine.plist`: `Enabled`, `HideAfterScreenshot`, `ShowCPU`, `ShowMemory`, `ShowNetwork`, `ShowBattery`, `Opacity`, `Scale`, `X`, `Y`. A PreferenceLoader entry is only a placeholder at this stage; a real PreferenceBundle UI still needs to be implemented.

## Important limitations
- This is a prototype, not a completed full port.
- CPU figure describes SpringBoard's process activity, not whole-device CPU utilization.
- Network rate is estimated from interface byte counters and may include aggregate traffic; it is not per-app traffic.
- Weather, lock-screen lyrics, draggable placement, full settings UI, robust screenshot exclusion, and original visual parity are not implemented.
- `UIApplicationUserDidTakeScreenshotNotification` fires after capture, so the current handler cannot guarantee the HUD is absent from the captured image.
- Use a jailbreak-safe recovery path in case SpringBoard crashes.
