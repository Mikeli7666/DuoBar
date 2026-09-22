@preconcurrency import CoreAudio
import Foundation

@MainActor
final class AudioOutputService {
    var onStatusChange: ((AudioStatus) -> Void)?

    private typealias PropertyListener = AudioObjectPropertyListenerBlock

    private struct ListenerRegistration {
        let objectID: AudioObjectID
        let address: AudioObjectPropertyAddress
        let listener: PropertyListener
    }

    private static let systemObject = AudioObjectID(kAudioObjectSystemObject)

    private let listenerQueue = DispatchQueue(label: "com.mikeli.duobar.audio-listeners", qos: .utility)
    private var systemListeners: [ListenerRegistration] = []
    private var deviceListeners: [ListenerRegistration] = []
    private var currentDefaultDeviceID = AudioDeviceID(kAudioObjectUnknown)
    private var currentVolumeAddresses: [AudioObjectPropertyAddress] = []
    private var currentMuteAddress: AudioObjectPropertyAddress?
    private var lastStatus: AudioStatus?
    private var isStarted = false

    func start() {
        guard !isStarted else { return }
        isStarted = true

        registerSystemListener(selector: kAudioHardwarePropertyDefaultOutputDevice)
        registerSystemListener(selector: kAudioHardwarePropertyDevices)
        refresh(rebindDeviceListeners: true)
    }

    func refresh() {
        refresh(rebindDeviceListeners: false)
    }

    @discardableResult
    func setVolume(_ level: Double) -> Bool {
        guard currentDefaultDeviceID != kAudioObjectUnknown,
              !currentVolumeAddresses.isEmpty,
              currentVolumeAddresses.allSatisfy({ isSettable(objectID: currentDefaultDeviceID, address: $0) })
        else { return false }

        var scalar = Float32(min(max(level, 0), 1))
        for var address in currentVolumeAddresses {
            let result = AudioObjectSetPropertyData(
                currentDefaultDeviceID,
                &address,
                0,
                nil,
                UInt32(MemoryLayout<Float32>.size),
                &scalar
            )
            guard result == noErr else {
                refresh()
                return false
            }
        }

        if scalar > 0,
           var muteAddress = currentMuteAddress,
           isSettable(objectID: currentDefaultDeviceID, address: muteAddress) {
            var unmuted: UInt32 = 0
            _ = AudioObjectSetPropertyData(
                currentDefaultDeviceID,
                &muteAddress,
                0,
                nil,
                UInt32(MemoryLayout<UInt32>.size),
                &unmuted
            )
        }

        refresh()
        return true
    }

    @discardableResult
    func setMuted(_ muted: Bool) -> Bool {
        guard currentDefaultDeviceID != kAudioObjectUnknown,
              var address = currentMuteAddress,
              isSettable(objectID: currentDefaultDeviceID, address: address)
        else { return false }

        var value: UInt32 = muted ? 1 : 0
        let result = AudioObjectSetPropertyData(
            currentDefaultDeviceID,
            &address,
            0,
            nil,
            UInt32(MemoryLayout<UInt32>.size),
            &value
        )
        refresh()
        return result == noErr
    }

    @discardableResult
    func setDefaultOutput(uid: String) -> Bool {
        guard let deviceID = deviceID(forUID: uid), deviceID != kAudioObjectUnknown else {
            return false
        }
        if deviceID == currentDefaultDeviceID {
            return true
        }

        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        guard isSettable(objectID: Self.systemObject, address: address) else {
            return false
        }

        var value = deviceID
        let result = AudioObjectSetPropertyData(
            Self.systemObject,
            &address,
            0,
            nil,
            UInt32(MemoryLayout<AudioDeviceID>.size),
            &value
        )
        refresh(rebindDeviceListeners: true)
        return result == noErr && currentDefaultDeviceID == deviceID
    }

    private func refresh(rebindDeviceListeners: Bool) {
        let defaultDeviceID = readDefaultOutputDeviceID()
        if rebindDeviceListeners || defaultDeviceID != currentDefaultDeviceID {
            currentDefaultDeviceID = defaultDeviceID
            bindDefaultDeviceListeners()
        }

        let outputDevices = selectableOutputDevices()
        let defaultOutput = outputDevices.first { $0.uid == makeDeviceStatus(defaultDeviceID)?.uid }
            ?? makeDeviceStatus(defaultDeviceID)
        let bluetoothOutputs = outputDevices
            .filter { $0.isAlive && $0.transport.isBluetooth }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }

        let volume = readVolumeStatus(deviceID: defaultDeviceID)
        publish(
            AudioStatus(
                isAvailable: defaultOutput != nil || !outputDevices.isEmpty,
                defaultOutput: defaultOutput,
                volume: volume,
                connectedBluetoothOutputs: bluetoothOutputs,
                availableOutputs: outputDevices
            )
        )
    }

    private func registerSystemListener(selector: AudioObjectPropertySelector) {
        var address = AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        let listener: PropertyListener = { [weak self] _, _ in
            Task { @MainActor in self?.refresh(rebindDeviceListeners: true) }
        }
        guard AudioObjectAddPropertyListenerBlock(Self.systemObject, &address, listenerQueue, listener) == noErr else {
            return
        }
        systemListeners.append(ListenerRegistration(objectID: Self.systemObject, address: address, listener: listener))
    }

    private func bindDefaultDeviceListeners() {
        removeListeners(&deviceListeners)
        currentVolumeAddresses = []
        currentMuteAddress = nil

        guard currentDefaultDeviceID != kAudioObjectUnknown else { return }
        currentVolumeAddresses = volumeAddresses(deviceID: currentDefaultDeviceID)
        currentMuteAddress = muteAddress(deviceID: currentDefaultDeviceID)

        var addresses = currentVolumeAddresses
        if let currentMuteAddress { addresses.append(currentMuteAddress) }
        addresses.append(
            AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyDeviceIsAlive,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain
            )
        )

        for var address in addresses {
            let listener: PropertyListener = { [weak self] _, _ in
                Task { @MainActor in self?.refresh() }
            }
            guard AudioObjectAddPropertyListenerBlock(currentDefaultDeviceID, &address, listenerQueue, listener) == noErr else {
                continue
            }
            deviceListeners.append(
                ListenerRegistration(objectID: currentDefaultDeviceID, address: address, listener: listener)
            )
        }
    }

    private func readDefaultOutputDeviceID() -> AudioDeviceID {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        return readUInt32(objectID: Self.systemObject, address: &address) ?? kAudioObjectUnknown
    }

    private func readAudioDeviceIDs() -> [AudioDeviceID] {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var dataSize: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(Self.systemObject, &address, 0, nil, &dataSize) == noErr,
              dataSize >= MemoryLayout<AudioDeviceID>.size else { return [] }

        var devices = [AudioDeviceID](
            repeating: kAudioObjectUnknown,
            count: Int(dataSize) / MemoryLayout<AudioDeviceID>.size
        )
        let result = devices.withUnsafeMutableBytes { bytes in
            AudioObjectGetPropertyData(Self.systemObject, &address, 0, nil, &dataSize, bytes.baseAddress!)
        }
        return result == noErr ? devices : []
    }

    private func selectableOutputDevices() -> [AudioDeviceStatus] {
        var seen = Set<String>()
        return readAudioDeviceIDs()
            .filter(isOutputDevice)
            .filter { !isHidden($0) }
            .filter(canBeDefaultOutput)
            .compactMap(makeDeviceStatus)
            .filter(\.isAlive)
            .filter { seen.insert($0.uid).inserted }
            .sorted(by: Self.compareForPicker)
    }

    private func deviceID(forUID uid: String) -> AudioDeviceID? {
        readAudioDeviceIDs().first { makeDeviceStatus($0)?.uid == uid }
    }

    private func isHidden(_ deviceID: AudioDeviceID) -> Bool {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyIsHidden,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        return readUInt32(objectID: deviceID, address: &address).map { $0 != 0 } ?? false
    }

    private func canBeDefaultOutput(_ deviceID: AudioDeviceID) -> Bool {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceCanBeDefaultDevice,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        return readUInt32(objectID: deviceID, address: &address).map { $0 != 0 } ?? true
    }

    private static func compareForPicker(_ lhs: AudioDeviceStatus, _ rhs: AudioDeviceStatus) -> Bool {
        let leftRank = sortRank(lhs.transport)
        let rightRank = sortRank(rhs.transport)
        if leftRank != rightRank { return leftRank < rightRank }
        return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
    }

    private static func sortRank(_ transport: AudioDeviceTransport) -> Int {
        switch transport {
        case .builtIn: 0
        case .bluetooth, .bluetoothLE: 1
        case .usb: 2
        case .hdmi, .displayPort: 3
        case .airPlay: 4
        case .virtual: 5
        case .other: 6
        }
    }

    private func isOutputDevice(_ deviceID: AudioDeviceID) -> Bool {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreams,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        var dataSize: UInt32 = 0
        return AudioObjectGetPropertyDataSize(deviceID, &address, 0, nil, &dataSize) == noErr
            && dataSize >= MemoryLayout<AudioStreamID>.size
    }

    private func makeDeviceStatus(_ deviceID: AudioDeviceID) -> AudioDeviceStatus? {
        guard deviceID != kAudioObjectUnknown else { return nil }

        let name = readString(
            objectID: deviceID,
            selector: kAudioObjectPropertyName
        ) ?? localized("Audio Device")
        let uid = readString(
            objectID: deviceID,
            selector: kAudioDevicePropertyDeviceUID
        ) ?? "audio-device-\(deviceID)"
        let transportValue = readUInt32(
            objectID: deviceID,
            selector: kAudioDevicePropertyTransportType
        ) ?? kAudioDeviceTransportTypeUnknown
        let alive = readUInt32(
            objectID: deviceID,
            selector: kAudioDevicePropertyDeviceIsAlive
        ).map { $0 != 0 } ?? true

        return AudioDeviceStatus(
            uid: uid,
            name: name,
            transport: transport(from: transportValue),
            isAlive: alive,
            modelUID: readString(objectID: deviceID, selector: kAudioDevicePropertyModelUID),
            manufacturer: readString(objectID: deviceID, selector: kAudioObjectPropertyManufacturer),
            terminalType: readTerminalType(deviceID: deviceID)
        )
    }

    private func readTerminalType(deviceID: AudioDeviceID) -> AudioDeviceTerminalType {
        var streamsAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreams,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        var dataSize: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(deviceID, &streamsAddress, 0, nil, &dataSize) == noErr,
              dataSize >= MemoryLayout<AudioStreamID>.size else { return .unavailable }

        var streams = [AudioStreamID](
            repeating: kAudioObjectUnknown,
            count: Int(dataSize) / MemoryLayout<AudioStreamID>.size
        )
        let result = streams.withUnsafeMutableBytes { bytes in
            AudioObjectGetPropertyData(deviceID, &streamsAddress, 0, nil, &dataSize, bytes.baseAddress!)
        }
        guard result == noErr else { return .unavailable }

        for stream in streams {
            guard let value = readUInt32(objectID: stream, selector: kAudioStreamPropertyTerminalType) else {
                continue
            }
            return value == kAudioStreamTerminalTypeHeadphones ? .headphones : .other(value)
        }
        return .unavailable
    }

    private func readVolumeStatus(deviceID: AudioDeviceID) -> OutputVolumeStatus {
        guard deviceID != kAudioObjectUnknown else { return .unavailable }
        let addresses = volumeAddresses(deviceID: deviceID)
        let levels = addresses.compactMap { address -> Float32? in
            var address = address
            return readFloat32(objectID: deviceID, address: &address)
        }
        guard !levels.isEmpty else { return .unavailable }

        let level = levels.reduce(0, +) / Float32(levels.count)
        let muted: Bool
        if var address = muteAddress(deviceID: deviceID) {
            muted = readUInt32(objectID: deviceID, address: &address).map { $0 != 0 } ?? false
        } else {
            muted = false
        }

        return OutputVolumeStatus(
            level: min(max(Double(level), 0), 1),
            isMuted: muted,
            isSettable: addresses.allSatisfy { isSettable(objectID: deviceID, address: $0) },
            isMuteSettable: muteAddress(deviceID: deviceID).map {
                isSettable(objectID: deviceID, address: $0)
            } ?? false
        )
    }

    private func volumeAddresses(deviceID: AudioDeviceID) -> [AudioObjectPropertyAddress] {
        let main = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyVolumeScalar,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        if hasProperty(objectID: deviceID, address: main) { return [main] }

        var channelElements = preferredStereoChannels(deviceID: deviceID)
        if channelElements.isEmpty { channelElements = Array(1...32) }
        var seen: Set<UInt32> = []
        return channelElements.compactMap { element in
            guard element > 0, seen.insert(element).inserted else { return nil }
            let address = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyVolumeScalar,
                mScope: kAudioDevicePropertyScopeOutput,
                mElement: element
            )
            return hasProperty(objectID: deviceID, address: address) ? address : nil
        }
    }

    private func preferredStereoChannels(deviceID: AudioDeviceID) -> [UInt32] {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyPreferredChannelsForStereo,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        var channels: [UInt32] = [0, 0]
        var dataSize = UInt32(MemoryLayout<UInt32>.size * channels.count)
        let result = channels.withUnsafeMutableBytes { bytes in
            AudioObjectGetPropertyData(deviceID, &address, 0, nil, &dataSize, bytes.baseAddress!)
        }
        return result == noErr ? channels : []
    }

    private func muteAddress(deviceID: AudioDeviceID) -> AudioObjectPropertyAddress? {
        let address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        return hasProperty(objectID: deviceID, address: address) ? address : nil
    }

    private func transport(from value: UInt32) -> AudioDeviceTransport {
        switch value {
        case kAudioDeviceTransportTypeBuiltIn: return .builtIn
        case kAudioDeviceTransportTypeBluetooth: return .bluetooth
        case kAudioDeviceTransportTypeBluetoothLE: return .bluetoothLE
        case kAudioDeviceTransportTypeAirPlay: return .airPlay
        case kAudioDeviceTransportTypeUSB: return .usb
        case kAudioDeviceTransportTypeHDMI: return .hdmi
        case kAudioDeviceTransportTypeDisplayPort: return .displayPort
        case kAudioDeviceTransportTypeVirtual: return .virtual
        default: return .other
        }
    }

    private func readString(
        objectID: AudioObjectID,
        selector: AudioObjectPropertySelector
    ) -> String? {
        var address = AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var value: Unmanaged<CFString>?
        var dataSize = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        guard AudioObjectGetPropertyData(objectID, &address, 0, nil, &dataSize, &value) == noErr else {
            return nil
        }
        return value?.takeRetainedValue() as String?
    }

    private func readUInt32(
        objectID: AudioObjectID,
        selector: AudioObjectPropertySelector
    ) -> UInt32? {
        var address = AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        return readUInt32(objectID: objectID, address: &address)
    }

    private func readUInt32(
        objectID: AudioObjectID,
        address: inout AudioObjectPropertyAddress
    ) -> UInt32? {
        var value: UInt32 = 0
        var dataSize = UInt32(MemoryLayout<UInt32>.size)
        return AudioObjectGetPropertyData(objectID, &address, 0, nil, &dataSize, &value) == noErr ? value : nil
    }

    private func readFloat32(
        objectID: AudioObjectID,
        address: inout AudioObjectPropertyAddress
    ) -> Float32? {
        var value: Float32 = 0
        var dataSize = UInt32(MemoryLayout<Float32>.size)
        return AudioObjectGetPropertyData(objectID, &address, 0, nil, &dataSize, &value) == noErr ? value : nil
    }

    private func hasProperty(objectID: AudioObjectID, address: AudioObjectPropertyAddress) -> Bool {
        var address = address
        return AudioObjectHasProperty(objectID, &address)
    }

    private func isSettable(objectID: AudioObjectID, address: AudioObjectPropertyAddress) -> Bool {
        var address = address
        var settable = DarwinBoolean(false)
        return AudioObjectIsPropertySettable(objectID, &address, &settable) == noErr && settable.boolValue
    }

    private func publish(_ status: AudioStatus) {
        guard status != lastStatus else { return }
        lastStatus = status
        onStatusChange?(status)
    }

    private func removeListeners(_ listeners: inout [ListenerRegistration]) {
        for registration in listeners {
            var address = registration.address
            AudioObjectRemovePropertyListenerBlock(
                registration.objectID,
                &address,
                listenerQueue,
                registration.listener
            )
        }
        listeners.removeAll()
    }

    deinit {
        for registration in deviceListeners + systemListeners {
            var address = registration.address
            AudioObjectRemovePropertyListenerBlock(
                registration.objectID,
                &address,
                listenerQueue,
                registration.listener
            )
        }
    }
}
