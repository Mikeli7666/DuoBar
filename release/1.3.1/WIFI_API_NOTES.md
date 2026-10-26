# DuoBar 1.3.1 Wi-Fi Public API Notes

Deployment baseline: macOS 13 or later. DuoBar uses only public CoreWLAN, Core Location, Network.framework, AppKit, and SwiftUI APIs.

Apple documents CoreWLAN as the framework for querying Wi-Fi interfaces and choosing wireless networks. `CWInterface` instances are obtained from `CWWiFiClient.shared()` so no App Sandbox exception or private socket access is introduced.

## Capability matrix

| Capability | Status | DuoBar 1.3.1 behavior |
| --- | --- | --- |
| Scan nearby Wi-Fi networks | SUPPORTED | `scanForNetworks(withName: nil)` runs on a dedicated background queue. Scans occur only when Nearby Networks is opened or manually refreshed; there is no scan loop. |
| Retrieve SSID | SUPPORTED WITH PRIVACY LIMITS | CoreWLAN exposes SSID, but macOS can withhold Wi-Fi identity information when Location access is unavailable. DuoBar reuses its existing Core Location authorization flow and never fabricates an SSID. |
| Retrieve BSSID | SUPPORTED WITH PRIVACY LIMITS | Used only as an internal, ephemeral scan-result identity/current-network match. It is not shown, logged, or persisted. |
| RSSI | SUPPORTED | Used for Strong/Medium/Weak presentation with the existing DuoBar thresholds. |
| Channel | SUPPORTED | Captured in the ephemeral scan model for deterministic/internal use; not displayed in the compact UI. |
| Security type | SUPPORTED | Derived with public `CWNetwork.supportsSecurity(_:)`. The UI distinguishes open, personal, enterprise, and unsupported networks without exposing protocol detail. |
| Connect to an open network | SUPPORTED WITH SYSTEM LIMITS | Uses public `associate(to:password:)` with no password, off the main thread. Association may still fail or require system authorization; DuoBar reports failure rather than claiming success. |
| Connect to a secured personal network | SUPPORTED WITH SYSTEM LIMITS | Uses a user-entered password with public `associate(to:password:)`. The password is transient and is never logged or persisted. |
| Connect to enterprise Wi-Fi | NOT IMPLEMENTED | Public enterprise association requires identity/username policy that cannot be represented safely by DuoBar's compact password UI. DuoBar opens Wi-Fi Settings instead. |
| Switch to a previously known secured network without a password | LIMITED | CoreWLAN does not document an API for DuoBar to retrieve saved credentials. DuoBar never reads Keychain data; secured networks use explicit password entry or Wi-Fi Settings. |
| Remember credentials | LIMITED / SYSTEM-OWNED | DuoBar does not maintain a credential database and does not promise persistence. Any system persistence is owned by macOS/CoreWLAN behavior. |
| Disconnect | SUPPORTED BY API, NOT IMPLEMENTED IN UI | Public `disassociate()` exists, but 1.3.1 focuses on selecting/joining networks and keeps disconnect out of the compact surface. |
| Turn Wi-Fi on/off | SUPPORTED WITH SYSTEM LIMITS | Existing public `CWInterface.setPower(_:)` path remains unchanged and verifies the actual read-back state. |

## Deliberate exclusions

- No `airport` or `networksetup` command-line tools.
- No shell commands, AppleScript, `sudo`, Keychain scraping, private frameworks, private SystemConfiguration behavior, UI scripting, or polling.
- No scan history, SSID history, analytics, production SSID logging, or password persistence.
- No hidden-network workflow in 1.3.1.

## Public documentation references

- [Core WLAN](https://developer.apple.com/documentation/corewlan)
- [CWInterface](https://developer.apple.com/documentation/corewlan/cwinterface)
- [Scanning for networks](https://developer.apple.com/documentation/corewlan/cwinterface/scanfornetworks(withssid:))
- [Associating to a network](https://developer.apple.com/documentation/corewlan/cwinterface/associate(to:password:))
- [CWNetwork RSSI](https://developer.apple.com/documentation/corewlan/cwnetwork/rssivalue)
