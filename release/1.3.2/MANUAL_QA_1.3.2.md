# DuoBar 1.3.2 Manual QA

Run on the notarized DMG build, not the Xcode debug build.

## Install
- [ ] DMG opens, drag DuoBar to Applications, first launch shows no Gatekeeper warning
- [ ] Version shows 1.3.2 (build 8)

## Charging
- [ ] Plug in: ring knocks out around the bolt, no overlap
- [ ] Unplug: bolt disappears, ring returns to normal
- [ ] 100% and still plugged in: bolt dims
- [ ] Default, Large and Extra Large sizes all look clean in the menu bar

## Battery Percentage
- [ ] Setting on: number appears on the icon and updates
- [ ] Setting off: icon returns to the normal glyph
- [ ] Popover battery row percentage setting still works independently

## Network and volume (regression)
- [ ] Wi-Fi glyph and nearby networks list work
- [ ] Ethernet icon shows `< ••• >` when wired (skip if no adapter available)
- [ ] Volume dots follow the slider and the keyboard volume keys

## Audio
- [ ] Audio Output picker still switches output
- [ ] Audio Input row lists available inputs
- [ ] Switching input works, including iPhone Microphone
- [ ] No microphone permission prompt appears from switching

## Localization
- [ ] Switch to each of the 6 languages: Extra Large, Battery Percentage and Default are translated
- [ ] Thai: no truncated text in Settings and the popover

## Popover behavior (regression)
- [ ] Closes on outside click and when clicking another menu bar icon
- [ ] Open on Hover still works
