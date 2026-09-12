<div align="center">

# DuoBar

### I recreated the iPhone Duo status bar on my MacBook.

**Battery · Wi-Fi · Bluetooth — unified into one menu bar indicator.**

[**Download DuoBar 0.1 Beta**](https://github.com/Mikeli7666/DuoBar/releases/tag/v0.1.0-beta)

macOS 15+ · Apple Silicon · Open Source

</div>

## One glyph, three live states

DuoBar recreates the iPhone Duo three-in-one status concept on macOS, mapping real Mac system state into one compact menu-bar glyph:

- **Outer arc** → live battery level
- **Center Wi-Fi glyph** → live Wi-Fi connection and signal
- **Four lower dots** → Bluetooth state, connected-device count, pinned devices, or an accessory battery gauge
- **Separate lightning indicator beside the ring** → charging

## DuoBar on macOS

<p align="center">
  <img src="marketing/screenshots/duobar-hero.png" alt="DuoBar running in the macOS menu bar with its compact status popover open" width="670">
</p>

The screenshot above is captured from the running app. The compact glyph is one system object—not three menu-bar icons placed side by side.

## Three-in-one, at a glance

<p align="center">
  <img src="marketing/social/duobar-three-in-one.png" alt="DuoBar's real macOS menu-bar glyph annotated with battery, Wi-Fi, and Bluetooth state" width="800">
</p>

## Live states

<p align="center">
  <img src="marketing/social/duobar-states.png" alt="DuoBar menu-bar glyph in full, half, low-battery, and charging states" width="800">
</p>

[Watch the 15-second real-app demo](marketing/video/duobar-demo.mp4) · [See the charging popover](marketing/screenshots/duobar-charging.png)

## Features

- Live battery level and optional menu bar percentage
- Charging state
- Live Wi-Fi status
- Bluetooth status
- Single compact menu-bar glyph
- Light and Dark Mode
- Launch at Login
- Expand Wi-Fi to switch its radio on/off, scan networks, and join open or personal-password networks
- Expand Bluetooth to connect or disconnect supported paired devices
- Choose the dots' function in the Bluetooth dropdown or DuoBar Settings → Bluetooth Dots; assign devices in Settings
- Expand Battery to change percentage display preferences
- Native SwiftUI + AppKit
- No Dock icon

## Requirements

<strong>macOS 15.0+</strong><br>
<strong>Apple Silicon</strong>

## Installation

1. Download `DuoBar-0.1.0-beta.dmg` from the [latest Beta release](https://github.com/Mikeli7666/DuoBar/releases/tag/v0.1.0-beta).
2. Open the DMG.
3. Drag DuoBar into Applications.
4. Open DuoBar from Applications.

DuoBar 0.1 Beta is not currently Developer ID signed or notarized. macOS may therefore ask you to explicitly approve the app on first launch. If it is blocked, use Finder's contextual **Open** option where available, or go to **System Settings → Privacy & Security → Open Anyway**.

Do not disable Gatekeeper, System Integrity Protection, or other macOS security protections to install DuoBar.

## Permissions

- **Location:** macOS may require authorization before CoreWLAN can expose the current Wi-Fi network name. If access is denied, Wi-Fi connection and signal information remain available where public APIs permit, while the network name may be unavailable.
- **Bluetooth:** used to display controller and paired-device status and to connect or disconnect supported devices. If macOS does not expose a device, manage it in Bluetooth Settings.

When macOS withholds the network name, the popover explains why and offers an explicit permission button or a shortcut to Location Services settings. DuoBar does not repeatedly request permission after the user has made a choice.

## Privacy

- System-status processing occurs locally.
- No analytics or tracking SDKs.
- No backend.
- No system-status uploads.
- No unrelated network requests.

## Known limitations

- DuoBar 0.1 is Beta software and is not Developer ID signed or notarized.
- The current Beta supports Apple Silicon Macs only.
- The Wi-Fi network name may be unavailable without Location permission or when macOS withholds it.
- Wi-Fi network selection needs Location access. Enterprise, hidden, and other networks requiring advanced setup use Wi-Fi Settings. DuoBar does not store entered network passwords.
- Bluetooth controls use devices exposed by IOBluetooth; some accessories and Bluetooth LE devices require Bluetooth Settings. Pairing new devices and turning the Bluetooth radio on/off use System Settings.
- Power modes and battery health settings remain in System Settings.
- Accessory battery mode uses optional battery readings published by macOS input-device drivers. Some mice, keyboards, and trackpads report a level; headphones and other accessories may not. Missing readings or disconnected devices show hollow dots, not an empty battery. No private Bluetooth APIs are used.

## Bluetooth dot modes

- **Bluetooth on/off** (default): all four dots brighten when Bluetooth is on.
- **Connected-device count:** one bright dot per connected device exposed by macOS; four means four or more.
- **Pinned devices:** fixed left-to-right assignments. Bright means connected, dim means disconnected, hollow means unassigned or unavailable.
- **Accessory battery:** choose one paired device. The four dots show 1–25%, 26–50%, 51–75%, and 76–100%; a reported 0% shows four dim dots. Hollow dots mean no current reading.

Modes and assignments persist across restarts. Count and pinned modes cover devices exposed by IOBluetooth, which may omit some Bluetooth LE accessories.

## How to quit

Click the DuoBar glyph, then choose **Quit DuoBar** from the popover. Settings are available from the same popover.

## Build from source

Open `DuoBar.xcodeproj` in Xcode, select the **DuoBar** scheme, and run. Debug builds include status simulation and glyph-tuning tools; those tools are excluded from Release builds.

## Disclaimer

DuoBar is an independent project and is not affiliated with or endorsed by Apple Inc.

## License

DuoBar is available under the [MIT License](LICENSE).
