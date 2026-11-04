# DuoBar 1.4.0

DuoBar 1.4.0 redesigns the popover with Liquid Glass, adds live network speed and richer battery details, and adds an optional Dock icon.

## What's New

### Popover

- On macOS 26 and later, every popover row is now its own Liquid Glass capsule floating over the desktop. Earlier macOS versions use a translucent capsule instead.
- The popover now opens and closes with a soft blur and fade.
- The DuoBar title row at the top of the popover is gone, and the Audio Output and Audio Input rows now have the same glass background as the rest.

### Network

- The Network row now shows live download and upload speed. It updates while the popover is open.

### Battery

- The Battery row now shows whether the battery is charging, on hold or running on the adapter, with the time remaining to full or until empty.
- "Power adapter connected" is replaced by "Charging On Hold" when the Mac is plugged in but not charging.

### Dock icon

- New optional Dock icon, off by default. Clicking it opens Settings.

### Localization

- All new text is localized in English, Simplified Chinese, Traditional Chinese, Russian, Ukrainian and Thai.

## Compatibility

- macOS 13 or later
- Apple Silicon and Intel
- Universal 2 release target
- Public macOS APIs only

Build 9. Artifact size and SHA-256 are published with the GitHub Release.
