import Combine
import Foundation
@preconcurrency import IOBluetooth

struct PairedBluetoothDevice: Identifiable, Equatable, Sendable {
    let id: String
    let name: String
    let isConnected: Bool
    var batteryPercentage: Int? = nil
}

@MainActor
final class BluetoothControls: ObservableObject {
    @Published private(set) var busyDeviceID: String?
    @Published private(set) var errorMessage: String?
    private let worker = BluetoothControlWorker()

    func setConnected(_ connected: Bool, device: PairedBluetoothDevice) async {
        guard busyDeviceID == nil else { return }
        busyDeviceID = device.id
        errorMessage = nil
        defer { busyDeviceID = nil }
        let result = await worker.setConnected(connected, address: device.id)
        if result != kIOReturnSuccess {
            errorMessage = "Could not \(connected ? "connect" : "disconnect") \(device.name). Try Bluetooth Settings. (\(result))"
        }
    }
}

private actor BluetoothControlWorker {
    func setConnected(_ connected: Bool, address: String) -> IOReturn {
        guard let device = IOBluetoothDevice(addressString: address), device.isPaired() else {
            return kIOReturnNotFound
        }
        if device.isConnected() == connected { return kIOReturnSuccess }
        return connected ? device.openConnection() : device.closeConnection()
    }
}
