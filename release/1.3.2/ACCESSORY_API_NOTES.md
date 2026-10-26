# DuoBar 1.3.2 — Bluetooth & Accessories API Notes

This document is planning and research only. No Bluetooth or accessory product implementation is included in DuoBar 1.3.2 yet.

## Scope

The candidate scope is audio-device quick switching, generic AirPods/headphone integration, connected accessory state, a compact native accessory surface, and accessory battery only where a reliable public API exists. Existing `AudioOutputService` and the AirPods temporary presentation must be reused rather than duplicated.

## Public API capability matrix

| Capability | Public API | macOS 13+ | Reliability | Decision |
|---|---|---:|---|---|
| Enumerate audio output devices | Core Audio `AudioObject` device properties | Yes | High for live output endpoints | SUPPORTED; existing `AudioOutputService` already covers this |
| Identify current audio output | Core Audio default output device property | Yes | High | SUPPORTED |
| Switch audio output | Core Audio default-output-device property | Yes | High when the device accepts the change | SUPPORTED; retain current implementation |
| Detect newly connected audio endpoint | Core Audio property listeners / existing service notifications | Yes | Good for audio endpoints | SUPPORTED |
| Detect removed audio endpoint | Core Audio property listeners | Yes | Good, with normal device-lifecycle caveats | SUPPORTED |
| Identify headphones generically | Public Core Audio transport/channel/device metadata | Yes | Useful but not universal | LIMITED; use conservative generic categories |
| Identify AirPods generically | Public device name/transport metadata where exposed | Yes | Device naming is user/system-dependent | LIMITED; do not infer model generations |
| Bluetooth device enumeration | No supported general-purpose macOS app API that guarantees all paired devices | N/A | Incomplete without private/undocumented interfaces | NOT IMPLEMENTED |
| Bluetooth connect | No supported general-purpose public API for arbitrary accessory connection | N/A | Not reliable without private behavior or UI automation | NOT IMPLEMENTED |
| Bluetooth disconnect | No supported general-purpose public API for arbitrary accessory disconnection | N/A | Not reliable without private behavior or UI automation | NOT IMPLEMENTED |
| Bluetooth paired state | No supported general-purpose public API for arbitrary paired-state inspection | N/A | Incomplete | NOT IMPLEMENTED |
| Bluetooth connected state | Core Audio can expose an audio endpoint, not arbitrary Bluetooth state | Yes, audio endpoints only | Reliable only for audio devices visible to Core Audio | LIMITED |
| Accessory battery | No general public API covering arbitrary Bluetooth accessories | N/A | Not reliable across devices | NOT IMPLEMENTED |
| Left/right AirPods battery | No supported public macOS API guaranteeing these values | N/A | Unreliable and model-dependent | NOT IMPLEMENTED |
| Charging case battery | No supported public macOS API guaranteeing this value | N/A | Unreliable and model-dependent | NOT IMPLEMENTED |
| Apple keyboard/mouse battery | No supported general public API contract for these values | N/A | Not reliable across OS/device versions | NOT IMPLEMENTED |
| Open Bluetooth Settings | `NSWorkspace` URL for System Settings Bluetooth pane | Yes | High for opening the pane | SUPPORTED |
| Open Sound Settings | `NSWorkspace` URL for System Settings Sound pane | Yes | High | SUPPORTED; existing shortcut behavior remains |

## Policy

The implementation must not use private frameworks, undocumented Bluetooth APIs, reverse-engineered databases, shell polling (`blueutil`, `system_profiler`, `ioreg`), AppleScript/UI scripting, fabricated battery values, or undocumented AirPods-generation mappings. Accessory battery remains explicitly optional and is not planned unless a reliable public API is demonstrated for every supported case.

## Candidate UX

Evaluate a compact hierarchy only after the feasibility audit:

- Audio / Accessories
- Current Output
- Available Audio Outputs
- AirPods / Headphones / Speakers
- Accessory Settings…

Do not duplicate the existing Audio Output section without a demonstrated information-architecture benefit. Do not reuse the persistent volume dots for accessory state without separate design approval.

## Research checklist

- Confirm Core Audio endpoint lifecycle behavior on supported macOS versions.
- Confirm generic headphone/AirPods categorization without relying on undocumented identifiers.
- Confirm System Settings URLs on macOS 13+.
- Keep Adaptive Ring, Battery, charging, Wi-Fi, Volume, and existing Audio Output behavior unchanged.
- Mark accessory battery **NOT IMPLEMENTED** unless public API evidence changes.
