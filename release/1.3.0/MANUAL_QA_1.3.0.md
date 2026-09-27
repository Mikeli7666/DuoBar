# DuoBar 1.3.0 Manual QA

Run this checklist only against a Developer ID-signed, notarized 1.3.0 candidate. Do not treat DEBUG simulation as a substitute for the real-hardware checks below.

## CRITICAL BEFORE RELEASE

- [ ] On a MacBook, confirm macOS **Fully Charged** maps to DuoBar **Fully charged**, not **Charging**.
- [ ] Confirm displayed 100% without an authoritative full-charge state does not start the full-charge delay.
- [ ] Confirm the production 15-minute Full Charge Delay begins only after authoritative full charge while plugged in.
- [ ] Confirm unplugging cancels a waiting delay and immediately restores the Battery Ring.
- [ ] Confirm Battery Ring → Adaptive Ring occurs after the configured charging-session rule.
- [ ] Confirm Adaptive Ring → Battery Ring occurs immediately after unplugging.
- [ ] Confirm the 0.32-second Battery/Charging → Adaptive crossfade is clean and retains the frozen 1.2 Battery/Charging renderer.
- [ ] Confirm the Network → sparkles → live Network entry presentation occurs once per Battery → Adaptive transition.
- [ ] Confirm Brightness, CPU, Memory, and Thermal source identities do not interrupt entry sparkles and restore the current live Network glyph afterward.
- [ ] Confirm real display brightness changes drive the Brightness Adaptive source.
- [ ] Confirm real sustained CPU pressure drives the CPU Adaptive source.
- [ ] Confirm real memory pressure drives the Memory Adaptive source.
- [ ] Confirm real thermal pressure drives the Thermal Adaptive source. GPU stress may only influence this indirectly through thermal pressure.
- [ ] Confirm icon-size presets and fine control update the actual menu-bar glyph cleanly.
- [ ] Launch from the final 1.3.0 DMG and confirm the install guidance appears once per launch.
- [ ] Confirm **Open Applications** opens Finder's Applications folder and does not silently move the app.
- [ ] Copy DuoBar to Applications, eject the DMG, and confirm relaunch succeeds.
- [ ] Confirm a clean install and an upgrade from 1.2.1 both preserve expected preferences and status behavior.
- [ ] Perform an Apple Silicon release-candidate smoke test.

## POLISH / VISUAL QA

- [ ] Check Settings layout and text clipping in English, Simplified Chinese, Traditional Chinese, Russian, and Ukrainian.
- [ ] Check VoiceOver labels and keyboard navigation for Icon Size presets, slider, and DMG install prompt buttons.
- [ ] Check Reduce Motion behavior for Battery/Charging → Adaptive and temporary center presentations.
- [ ] Confirm no DEBUG Simulator or DEBUG diagnostics are present in the Release candidate.
- [ ] Check the DMG Finder layout: DuoBar.app and Applications shortcut are easy to understand at default Finder icon size.
- [ ] On an Intel Mac, run a release-candidate smoke test if physical hardware is available. The x86_64 Release build is required even if hardware is unavailable.
