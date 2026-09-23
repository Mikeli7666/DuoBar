<div align="center">

# DuoBar

### One compact macOS menu bar indicator for Battery, Network, and Volume.

**Three live states. One glyph. Less menu bar clutter.**

[English](README.md) | [简体中文](README.zh-CN.md) | [Русский](README.ru.md) | [Українська](README.uk.md)

[**Download DuoBar 1.2.1**](https://github.com/Mikeli7666/DuoBar/releases/download/v1.2.1/DuoBar-1.2.1.dmg) · [**All Releases**](https://github.com/Mikeli7666/DuoBar/releases) · [**Report a Bug**](https://github.com/Mikeli7666/DuoBar/issues)

DuoBar 1.2.1 (Build 5) · macOS 13+ · Apple Silicon or Intel · Universal 2 · Free and Open Source

<br>

<img src="marketing/1.0/launch-film/final/DuoBar-1.0-Launch-Poster.png" alt="DuoBar 1.0" width="820">

</div>

## One glyph, three live states

DuoBar adapts the iPhone Duo-style three-in-one status concept for the Mac menu bar. One compact glyph presents the system information normally spread across several indicators:

- **Outer arc** → a live Battery Ring on MacBooks, or an Adaptive Ring on desktop Macs
- **Center** → the active network: Wi-Fi, Ethernet, or an offline/fallback state
- **Four lower dots** → live output volume

Persistent status stays monochrome and native-looking. When AirPods or another supported Bluetooth audio output becomes active, the center briefly transitions from Network → AirPods/headphones → Network. Disconnecting does not trigger an animation.

## Adaptive Ring and Battery Ring

On MacBooks, the outer Battery Ring shows live battery level, a dynamic charging bolt, and optional battery color coding for charging, Low Power Mode, and low-battery states. On desktop Macs, Adaptive Ring shows display brightness when publicly available and automatically surfaces sustained CPU, memory, or thermal pressure when it needs attention. It remains automatic: there is no manual metric selector.

## DuoBar on macOS

The original 1.0 release established DuoBar's Battery, Network, and Volume foundation. The current 1.2.1 release builds on it with broader connectivity controls, refined visuals, localization, and compatibility fixes.

<p align="center">
  <img src="marketing/1.0/DuoBar-1.0-Feature-Overview.png" alt="DuoBar 1.0 feature states: Default, Battery Low, Ethernet, AirPods Connected, and No Connection" width="100%">
</p>

<p align="center">
  <a href="https://github.com/Mikeli7666/DuoBar/releases/download/v1.0.0/DuoBar-1.0-Official-Launch-Film.mp4">
    Watch the DuoBar 1.0 Official Launch Film →
  </a>
</p>
## Features

- Battery Ring with live level, dynamic charging bolt, low-battery state, and optional Battery Color Coding
- Adaptive Ring for desktop Macs: brightness baseline with automatic CPU, memory, and thermal pressure awareness
- Refined native Duo visual language, rounded Wi-Fi indicator, Battery Ring, volume indicators, and charging presentation
- Automatic Wi-Fi, Ethernet, and offline network states
- Wi-Fi network name display and public Wi-Fi power control
- Optional Open on Hover popover behavior
- Four-dot live volume indicator
- Compact volume slider, public Core Audio mute, and output-device switching where supported
- Temporary AirPods/headphones connection presentation
- Adjustable menu-bar Icon Size
- English, Russian, Ukrainian, Simplified Chinese, and Traditional Chinese
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

1. Open the [DuoBar 1.2.1 release](https://github.com/Mikeli7666/DuoBar/releases/tag/v1.2.1) and find **Assets**.
2. Download **DuoBar-1.2.1.dmg**. Do not download `Source code (zip)` or `Source code (tar.gz)`.
3. Double-click the DMG and drag **DuoBar.app** to **Applications**.
4. Open Applications and launch DuoBar. It is a menu-bar utility and normally does not appear in the Dock.

DuoBar 1.2.1 uses Developer ID signing, Hardened Runtime, and Apple notarization. Normal installation does not require disabling Gatekeeper/SIP, Terminal, `sudo`, or `xattr`.

SHA-256: `ac4c3acbe4569c2ccc984ff52c007c208a557abb96b32764a8ec6eeab79f0235`

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
