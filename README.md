<div align="center">

# DuoBar

### One compact macOS menu bar indicator for Battery, Network, and Volume.

**Three live states. One glyph. Less menu bar clutter.**

[English](README.md) | [简体中文](README.zh-CN.md) | [Русский](README.ru.md) | [Українська](README.uk.md) | [ไทย](README.th.md)

[**Download DuoBar 1.3.0**](https://github.com/Mikeli7666/DuoBar/releases/download/v1.3.0/DuoBar-1.3.0.dmg) · [**All Releases**](https://github.com/Mikeli7666/DuoBar/releases) · [**Report a Bug**](https://github.com/Mikeli7666/DuoBar/issues)

DuoBar 1.3.0 (Build 6) · macOS 13+ · Apple Silicon or Intel · Universal 2 · Free and Open Source

<br>

<img src="marketing/1.2.1/readme/duobar-1.2.1-menubar.png" alt="DuoBar 1.3.0 in the macOS menu bar" width="1340">

</div>



  [![▶ Watch the release video](https://img.shields.io/badge/Watch_the_release_video-0969da?style=for-the-badge)](https://github.com/user-attachments/assets/3af8d3cf-230b-4073-932b-c54c4a1553e6)
</p>

## One glyph, three live states

DuoBar adapts the iPhone Duo-style three-in-one status concept for the Mac menu bar. One compact glyph presents the system information normally spread across several indicators:

- **Outer arc** → a live Battery Ring on MacBooks, or an Adaptive Ring on desktop Macs
- **Center** → the active network: Wi-Fi, Ethernet, or an offline/fallback state
- **Four lower dots** → live output volume

Persistent status stays monochrome and native-looking. When AirPods or another supported Bluetooth audio output becomes active, the center briefly transitions from Network → AirPods/headphones → twork. Disconnecting does not trigger an animation.
p>

<p align="center">
  <img src="marketing/1.2.1/readme/duobar-1.2.1-popover.png" alt="DuoBar 1.3.0 popover" width="480">
</p>

## Adaptive Ring and Battery Ring

On MacBooks, the outer Battery Ring shows live battery level, a dynamic charging bolt, and optional battery color coding for charging, Low Power Mode, and low-battery states. On desktop Macs, Adaptive Ring remains Neutral when there is no meaningful performance activity and automatically surfaces sustained CPU, memory, or thermal pressure when appropriate. It remains automatic: there is no manual metric selector.

## DuoBar on macOS

The current 1.3.0 release brings the Battery, Network, and Volume foundation together with MacBook Adaptive Ring behavior, refined controls, adjustable icon size, and installation polish.

<p align="center">
## Features

- Battery Ring with live level, dynamic charging bolt, low-battery state, and optional Battery Color Coding
- Adaptive Ring for desktop Macs: Neutral by default, with automatic CPU, memory, and thermal pressure awareness
- Refined native Duo visual language, rounded Wi-Fi indicator, Battery Ring, volume indicators, and charging presentation
- Automatic Wi-Fi, Ethernet, and offline network states
- Wi-Fi network name display and public Wi-Fi power control
- Optional Open on Hover popover behavior
- Four-dot live volume indicator
- Compact volume slider, public Core Audio mute, and output-device switching where supported
- Temporary AirPods/headphones connection presentation
- Adjustable menu-bar Icon Size
- English, Russian, Ukrainian, Simplified Chinese, Traditional Chinese, and Thai
- Compact custom popover: Network and Battery open System Settings, Wi-Fi power, Volume, Audio Output selection, Settings, and Quit
- Light and Dark Mode
- Launch at Login
- Universal 2: Apple Silicon and Intel support on macOS 13+
- Native Swift, SwiftUI, and AppKit
- No Dock icon

## Requirements

**macOS 13.0+**<br>
**Apple Silicon or Intel**

## Installation

1. Open the [DuoBar 1.3.0 release](https://github.com/Mikeli7666/DuoBar/releases/tag/v1.3.0) and find **Assets**.
2. Download **DuoBar-1.3.0.dmg**. Do not download `Source code (zip)` or `Source code (tar.gz)`.
3. Double-click the DMG and drag **DuoBar.app** to **Applications**.
4. Open Applications and launch DuoBar. It is a menu-bar utility and normally does not appear in the Dock.

DuoBar 1.3.0 uses Developer ID signing, Hardened Runtime, and Apple notarization. Normal installation does not require disabling Gatekeeper/SIP, Terminal, `sudo`, or `xattr`.

SHA-256: `bd638b5fac84b7bc56ab71988e10d6d4a3188bea973584c77b1fe6979f243fb5`

Build and compatibility/reliability work was checked using Xcode 27 and the macOS 27 SDK while continuing to support macOS 13+. This does not claim macOS 27 hardware validation.

## Permissions

- **Location:** macOS may require authorization before CoreWLAN can expose the current Wi-Fi network name. Denying access does not break basic connection, interface, or signal state; the SSID may simply remain unavailable. DuoBar requests SSID access only when it is useful to the interface.
- **Bluetooth:** DuoBar retains public Bluetooth controller observation while Core Audio provides the primary source for Bluetooth audio endpoints. The app does not manage or pair devices.

## Audio output behavior

Volume control is available only when the active Core Audio output exposes software-settable public volume properties. HDMI, AirPlay, USB, and other external outputs may instead display **Controlled by device**.

AirPods and Bluetooth audio classification is best-effort using public system metadata. DuoBar does not claim exact AirPods generation detection.

## Privacy

- System-status processing occurs locally.
- No analytics or tracking.
- No backend or telemetry.
- No system-status uploads.
- No unrelated network requests.

## Known limitations

- The Wi-Fi network name may be unavailable without Location permission or when macOS withholds it.
- Wi-Fi strength uses documented RSSI data and broad signal ranges; it does not reproduce Apple's private icon algorithm.
- Some audio devices expose fixed or externally controlled volume.
- DuoBar does not join Wi-Fi networks or pair Bluetooth devices.
- Bluetooth audio and AirPods family detection is best-effort through public APIs.

## Build from source

Open `DuoBar.xcodeproj` in Xcode, select the **DuoBar** scheme, and run. Debug builds include status simulation and marketing-capture tools; those tools are excluded from Release behavior.

## Disclaimer

DuoBar is an independent project and is not affiliated with or endorsed by Apple Inc.

## License

DuoBar is available under the [MIT License](LICENSE).
