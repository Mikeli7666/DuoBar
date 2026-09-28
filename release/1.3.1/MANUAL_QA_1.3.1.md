# DuoBar 1.3.1 Manual QA

The checks below require real Wi-Fi hardware, real access points, macOS privacy UI, or human visual/accessibility judgment. Automated tests are not a substitute.

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

## 1.3.0 regression smoke test

- [ ] Adaptive Ring and MacBook Battery → Adaptive behavior remain unchanged.
- [ ] Battery/Charging rendering and Full Charge Delay behavior remain unchanged.
- [ ] Volume and Audio Output controls remain unchanged.
- [ ] AirPods temporary presentation remains unchanged.
- [ ] Icon Size and launch-from-DMG guidance remain unchanged.
