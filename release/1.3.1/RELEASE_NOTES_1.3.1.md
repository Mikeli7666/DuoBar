# DuoBar 1.3.1

DuoBar 1.3.1 is the update after 1.3.0. It expands the Network card into a compact, native Wi-Fi control surface and improves audio output switching, while preserving the current network, Battery, Adaptive Ring, and Volume behavior.

## What's New

### Wi-Fi

- Browse nearby Wi-Fi networks on demand from the DuoBar popover.
- See the current network first, followed by deterministic signal-strength ordering.
- Refresh nearby networks explicitly without continuous background scanning.
- Join open and personal secured networks through public CoreWLAN APIs.
- Enter secured-network passwords in a native secure field; DuoBar never stores or logs them.
- Fall back to macOS Wi-Fi Settings for enterprise or unsupported association flows.
- Handle Wi-Fi Off, unavailable interfaces, empty results, scan failures, and disappearing networks without blocking the popover.

### Audio output

- Live available-output discovery with the current output first.
- Conservative device categories for built-in, headphones, AirPods, Bluetooth audio, USB, and display audio.
- Immediate output selection through the existing Core Audio service, with the system-observed state remaining authoritative.
- Sound Settings and Bluetooth Settings shortcuts.
- The AirPods/headphone temporary presentation remains transient and returns to the live Network glyph.

### Status glyph

- The Wi-Fi mark, volume dots, and ring now follow the iPhone Duo's status glyph geometry: circular Wi-Fi arcs with a solid wedge, dots on the ring's centre line below the open end, and a matching ring thickness.

### Adaptive Ring

- The Adaptive Ring no longer shows display brightness. It continues to surface CPU, memory, and thermal pressure when they matter.

### Fixes

- The popover now closes when you click another menu bar icon or anywhere outside DuoBar, matching native menu bar items. This applies with and without Open on Hover.

### Distribution

- DuoBar can be installed with Homebrew: `brew install --cask mikeli7666/duobar/duobar`.

<!-- Add a macOS 27 line here only after the menu bar icon has been confirmed on a real macOS 27 Mac (GitHub #3). -->

### Localization

- Full localization for English, Simplified Chinese, Traditional Chinese, Russian, and Ukrainian.

## Not Included

- Accessory battery is not implemented because no reliable public macOS API covers the supported accessory set.
- No arbitrary Bluetooth pairing, connection management, private API, shell polling, or fabricated battery values.

## Compatibility

- macOS 13 or later
- Apple Silicon and Intel
- Universal 2 release target
- Public macOS APIs only

This is development documentation for an unreleased version. Final signing, notarization, build number, artifact size, and SHA-256 will be added only after the 1.3.1 release candidate is finalized.
