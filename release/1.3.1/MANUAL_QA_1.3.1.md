# DuoBar 1.3.1 Manual QA

The checks below cover Wi-Fi and audio output. They require real Wi-Fi hardware, real access points, real audio devices, macOS privacy UI, or human visual/accessibility judgment. Automated tests are not a substitute.

## Critical before release — physical networking

- [ ] With Wi-Fi On and Location allowed, open **Nearby Networks** and verify real SSIDs appear.
- [ ] Confirm the current associated Wi-Fi network is first and marked with a checkmark.
- [ ] Confirm signal indicators broadly follow real Strong/Medium/Weak conditions without implying fake precision.
- [ ] Confirm repeated access points with the same SSID/security appear as one strongest useful row.
- [ ] Press **Refresh** and confirm one new scan occurs without UI blocking or overlapping work.
- [ ] Rapidly press **Refresh** and confirm duplicate scans are prevented.
- [ ] Close and reopen the popover during a scan; confirm there is no duplicate work, crash, or stale result corruption.
- [ ] Turn Wi-Fi Off and confirm Nearby Networks shows **Wi-Fi is Off** and does not scan.
- [ ] Turn Wi-Fi On through DuoBar, wait for the system state to update, then refresh and verify networks appear.
- [ ] With Location denied, confirm the existing permission model remains truthful and the UI fails gracefully without fabricated names or repeated prompts.
- [ ] With Location not determined, confirm the existing Location prompt is requested only through the established popover flow.
- [ ] Join an open network and verify DuoBar waits for the real association result.
- [ ] Select a secured personal network, enter a wrong password, and verify a concise failure with no password exposure.
- [ ] Enter the correct password and verify the prompt dismisses, current state refreshes, and the current network is marked.
- [ ] Select the already-current network and verify no reconnect occurs.
- [ ] Select an enterprise/unsupported network and verify DuoBar opens Wi-Fi Settings rather than faking a join.
- [ ] Make a selected network disappear during Join and verify the request fails safely.
- [ ] Test Ethernet as the active route while Wi-Fi remains enabled; confirm DuoBar's persistent center stays Ethernet while Nearby Networks remains a Wi-Fi control surface.
- [ ] Sleep and wake the Mac, then scan and join again.
- [ ] Verify **Network Settings…** opens the expected macOS settings surface.

## Privacy and credentials

- [ ] Confirm no nearby SSID or BSSID is written to production logs or persisted as history.
- [ ] Confirm passwords do not appear in Console, UserDefaults, diagnostics, crash text, or UI after the password sheet closes.
- [ ] Confirm DuoBar does not claim that macOS remembered a credential.

## Localization and accessibility

- [ ] Check Nearby Networks, scan/error/off states, password entry, Join, Refresh, and Settings labels in English.
- [ ] Repeat the UI/text-clipping review in Simplified Chinese.
- [ ] Repeat the UI/text-clipping review in Traditional Chinese.
- [ ] Repeat the UI/text-clipping review in Russian.
- [ ] Repeat the UI/text-clipping review in Ukrainian.
- [ ] Use VoiceOver to verify network names, current-network state, secured status, signal strength, scanning/joining progress, and buttons.
- [ ] Verify keyboard navigation reaches network rows, Password, Cancel, Join, Refresh, and Network Settings.
- [ ] Confirm the secure password field behaves like a native macOS secure field.

## Core Audio output QA — MANUAL QA REQUIRED

- Built-in speakers remain selectable and current output appears first.
- Wired headphones, if available, enumerate and switch correctly.
- AirPods and generic Bluetooth headphones, if available, enumerate as audio outputs.
- USB audio and HDMI/display audio, if available, enumerate and switch correctly.
- Switch between outputs repeatedly; the observed default output must settle correctly.
- Disconnect the current output and confirm the list/current state refreshes without stale selection.
- Sleep/wake and reconnect devices; confirm lifecycle updates without polling artifacts.
- Volume and mute follow the newly authoritative output.
- Fixed-volume outputs remain usable and do not expose an editable slider incorrectly.

## Audio presentation and settings — MANUAL QA REQUIRED

- A genuine new AirPods/headphone endpoint produces one temporary presentation and returns to the live Network glyph.
- Startup and ordinary refresh do not produce a false connection presentation.
- Sound Settings and Bluetooth Settings open the native macOS panes.
- Verify English, Simplified Chinese, Traditional Chinese, Russian, and Ukrainian labels.
- Verify VoiceOver announces the output name, current state, and actions.
- Verify keyboard navigation and Reduce Motion behavior.

## Audio policy checks

- No accessory battery values are shown.
- No Bluetooth pairing/connect/disconnect UI is presented.
- No private API, shell command, UI scripting, or undocumented product-ID mapping is used.

## Adaptive Ring — display brightness removed

- [ ] On a desktop Mac, change the display brightness; confirm the Adaptive Ring does not react.
- [ ] Confirm the idle state looks as intended now that there is no brightness baseline.
- [ ] Generate CPU load; confirm the ring shows CPU pressure (blue) and returns to idle afterwards.
- [ ] Confirm memory pressure (purple) and thermal pressure (orange) still surface.
- [ ] On a MacBook, confirm Battery → Adaptive behavior and Full Charge Delay are unchanged.
- [ ] Open Settings; confirm no brightness-related option or text is left in any of the five languages.
- [ ] Confirm README, Reddit/Xiaohongshu/Bilibili copy, and the 1.3.0 launch materials do not still promise a brightness feature.

## Status glyph fidelity

- [ ] Take a Retina screenshot of the glyph; compare it with Apple's iPhone Duo glyph at the same size (ring thickness, Wi-Fi arcs, wedge, four dots).
- [ ] Wi-Fi at strong, medium, weak, and disconnected levels: the three bands dim correctly (arcs and wedge).
- [ ] Volume at 0, 1, 2, 3, and 4 dots: active and dimmed dots look right.
- [ ] Charging, low battery, and Low Power Mode ring colours still read clearly with the thicker-measured ring.
- [ ] Icon Size small / default / large: the glyph stays crisp and centred in the menu bar.
- [ ] Light and dark menu bars, and a tinted wallpaper: the glyph is legible.
- [ ] Ethernet, offline, AirPods, headphones, and Adaptive Ring centre states are still centred inside the ring.
- [ ] Popover header and any other place that draws the glyph look correct.

## Popover dismissal (GitHub #10)

Run each check with Open on Hover **off**, then again with it **on**.

- [ ] Open DuoBar's popover, then click the Wi-Fi, Control Center, Battery, or Sound icon; confirm DuoBar's popover closes and the other menu opens.
- [ ] Open the popover, then click the desktop, the Dock, and another app's window; confirm it closes each time.
- [ ] Open the popover, then press a third-party menu bar icon; confirm it closes.
- [ ] Clicking inside the popover, using the volume slider, and opening the audio output menu do not close it.
- [ ] Open the Wi-Fi password sheet from Nearby Networks; typing and clicking inside the sheet do not close the popover.
- [ ] Click DuoBar's own icon while the popover is open; confirm it closes once and reopens on the next click (no flicker or double toggle).
- [ ] With Open on Hover on, hover to open, click to pin, then click another menu bar icon; confirm it closes and hover opening still works afterwards.
- [ ] First launch with Location not determined: confirm the system Location prompt can be answered, and the popover can be reopened afterwards.
- [ ] Test on a Mac with an external display and with Spaces/full-screen apps.

## Homebrew

- [ ] `brew audit --cask --online` and `brew style` pass for the cask.
- [ ] `brew install --cask` installs DuoBar to /Applications and it launches without a Gatekeeper warning.
- [ ] The cask's SHA-256 matches the published `DuoBar-1.3.1.dmg`.
- [ ] `brew uninstall --cask duobar` removes the app; `--zap` removes preferences.
- [ ] Launching from /Applications after a Homebrew install does not show the launch-from-DMG guidance.

## macOS 27 (GitHub #3)

- [ ] On macOS 27.x (note the exact point release), a fresh install shows DuoBar's icon in the menu bar.
- [ ] Icon still appears after relaunch, after sleep/wake, and after changing Icon Size.
- [ ] Check System Settings → Menu Bar: DuoBar is allowed in the menu bar.
- [ ] Check with and without a menu bar manager (Bartender, Ice, Thaw) and with a crowded menu bar on a notched MacBook (macOS 27 overflow arrow).
- [ ] Confirm the popover, hover opening, Wi-Fi browsing, and audio output menu all work on macOS 27.
- [ ] Ask the reporter of #3 to retest 1.3.1 and record their macOS 27 point release.

## 1.3.0 regression smoke test

- [ ] MacBook Battery → Adaptive behavior remains unchanged (see Adaptive Ring checks above).
- [ ] Battery/Charging rendering and Full Charge Delay behavior remain unchanged.
- [ ] Volume slider and mute behavior remain correct (see audio QA above for per-output behavior).
- [ ] Icon Size and launch-from-DMG guidance remain unchanged.
