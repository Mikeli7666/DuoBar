import CoreGraphics
import Foundation
import IOKit
import IOKit.graphics

protocol DisplayBrightnessReading {
    func readMainDisplay(at timestamp: TimeInterval) -> DisplayBrightnessSnapshot
}

struct DisplayBrightnessService: DisplayBrightnessReading {
    func readMainDisplay(at timestamp: TimeInterval = ProcessInfo.processInfo.systemUptime) -> DisplayBrightnessSnapshot {
        let mainDisplayID = CGDisplayPrimaryDisplay(CGMainDisplayID())
        let mainDisplay = MainDisplayDescriptor(
            displayID: mainDisplayID,
            vendorID: CGDisplayVendorNumber(mainDisplayID),
            productID: CGDisplayModelNumber(mainDisplayID),
            serialNumber: CGDisplaySerialNumber(mainDisplayID)
        )

        #if DEBUG
        let recorder = DisplayBrightnessDiagnosticRecorder(
            mainDisplay: mainDisplay,
            isBuiltIn: CGDisplayIsBuiltin(mainDisplayID) != 0,
            bounds: CGDisplayBounds(mainDisplayID)
        )
        let measured = readBrightness(for: mainDisplay, recorder: recorder)
        return DisplayBrightnessSnapshot(
            mainDisplay: mainDisplay,
            availability: Self.availability(
                measured: measured,
                slider: DisplaySliderBrightness.read(displayID: mainDisplayID)
            ),
            sampledAt: timestamp,
            diagnostic: recorder.complete(availability: measured)
        )
        #else
        return DisplayBrightnessSnapshot(
            mainDisplay: mainDisplay,
            availability: Self.availability(
                measured: readBrightness(for: mainDisplay),
                slider: DisplaySliderBrightness.read(displayID: mainDisplayID)
            ),
            sampledAt: timestamp
        )
        #endif
    }

    static func validatedBrightness(_ value: Double) -> DisplayBrightnessAvailability {
        guard value.isFinite, (0...1).contains(value) else { return .unavailable }
        return .available(value)
    }

    static func resolvedBrightness(standard: Double?, linearFallback: Double?) -> DisplayBrightnessAvailability {
        for candidate in [standard, linearFallback] {
            guard let candidate else { continue }
            if case .available = validatedBrightness(candidate) {
                return validatedBrightness(candidate)
            }
        }
        return .unavailable
    }

    /// Keeps a successful IOKit read. When the framebuffer path is missing, uses the Control Center slider.
    static func availability(
        measured: DisplayBrightnessAvailability,
        slider: Double?
    ) -> DisplayBrightnessAvailability {
        if case .available = measured { return measured }
        guard let slider else { return .unavailable }
        return validatedBrightness(slider)
    }

    #if DEBUG
    private func readBrightness(
        for mainDisplay: MainDisplayDescriptor,
        recorder: DisplayBrightnessDiagnosticRecorder
    ) -> DisplayBrightnessAvailability {
        guard let matching = IOServiceMatching("IOFramebuffer") else { return .unavailable }
        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator) == KERN_SUCCESS else {
            return .unavailable
        }
        defer { IOObjectRelease(iterator) }

        var candidates: [DiagnosticCandidate] = []
        var index = 0
        var framebuffer = IOIteratorNext(iterator)
        while framebuffer != 0 {
            recorder.recordFramebuffer()
            if let candidate = diagnosticCandidate(for: framebuffer, index: index, recorder: recorder) {
                candidates.append(candidate)
            }
            index += 1
            IOObjectRelease(framebuffer)
            framebuffer = IOIteratorNext(iterator)
        }

        recorder.recordIdentityMatching(mainDisplay: mainDisplay, candidates: candidates)
        guard let matchIndex = DisplayHardwareIdentity.uniqueMatchIndex(
            for: mainDisplay,
            candidates: candidates.map(\.identity)
        ) else {
            recorder.recordUnresolvedIdentity(mainDisplay: mainDisplay, candidateCount: candidates.count)
            return .unavailable
        }

        let selected = candidates[matchIndex]
        recorder.recordSelectedCandidate(selected)
        guard let value = selected.brightness else { return .unavailable }
        return Self.validatedBrightness(value)
    }

    private func diagnosticCandidate(
        for framebuffer: io_service_t,
        index: Int,
        recorder: DisplayBrightnessDiagnosticRecorder
    ) -> DiagnosticCandidate? {
        let info = IODisplayCreateInfoDictionary(framebuffer, IOOptionBits(kIODisplayMatchingInfo)).takeRetainedValue() as NSDictionary
        let vendorID = number(in: info, key: kDisplayVendorID)
        let productID = number(in: info, key: kDisplayProductID)
        let serialNumber = number(in: info, key: kDisplaySerialNumber)
        guard let vendorID, let productID else {
            recorder.recordCandidate(
                index: index,
                vendorID: vendorID,
                productID: productID,
                serialNumber: serialNumber,
                displayServiceResolved: nil,
                standard: .notAttempted,
                linear: .notAttempted
            )
            return nil
        }

        let identity = DisplayHardwareIdentity(vendorID: vendorID, productID: productID, serialNumber: serialNumber ?? 0)
        let displayService = IODisplayForFramebuffer(framebuffer, 0)
        guard displayService != 0 else {
            let candidate = DiagnosticCandidate(
                identity: identity,
                brightness: nil,
                framebufferIndex: index,
                displayServiceResolved: false,
                standardBrightness: .notAttempted,
                linearBrightness: .notAttempted
            )
            recorder.recordCandidate(candidate)
            return candidate
        }
        defer { IOObjectRelease(displayService) }

        let parameters = diagnosticBrightnessParameters(for: displayService)
        let candidate = DiagnosticCandidate(
            identity: identity,
            brightness: parameters.value,
            framebufferIndex: index,
            displayServiceResolved: true,
            standardBrightness: parameters.standard,
            linearBrightness: parameters.linear
        )
        recorder.recordCandidate(candidate)
        return candidate
    }

    private func diagnosticBrightnessParameters(for displayService: io_service_t) -> DiagnosticParameterRead {
        let standard = diagnosticParameter(kIODisplayBrightnessKey as CFString, for: displayService)
        let linear = standard.isValid
            ? .notAttempted
            : diagnosticParameter(kIODisplayLinearBrightnessKey as CFString, for: displayService)
        let availability = Self.resolvedBrightness(standard: standard.value, linearFallback: linear.value)
        let value: Double?
        if case .available(let resolved) = availability {
            value = resolved
        } else {
            value = nil
        }
        return DiagnosticParameterRead(value: value, standard: standard, linear: linear)
    }

    private func diagnosticParameter(_ parameterName: CFString, for displayService: io_service_t) -> DisplayBrightnessParameterDiagnostic {
        var rawValue: Float = 0
        let result = IODisplayGetFloatParameter(displayService, 0, parameterName, &rawValue)
        guard result == kIOReturnSuccess else {
            return DisplayBrightnessParameterDiagnostic(attempted: true, ioReturn: Int32(result), value: nil, isValid: false)
        }
        let value = Double(rawValue)
        let isValid: Bool
        if case .available = Self.validatedBrightness(value) {
            isValid = true
        } else {
            isValid = false
        }
        return DisplayBrightnessParameterDiagnostic(attempted: true, ioReturn: Int32(result), value: value, isValid: isValid)
    }
    #else
    // Release keeps the pre-diagnostic public IOKit read path unchanged.
    private func readBrightness(for mainDisplay: MainDisplayDescriptor) -> DisplayBrightnessAvailability {
        guard let matching = IOServiceMatching("IOFramebuffer") else { return .unavailable }
        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator) == KERN_SUCCESS else {
            return .unavailable
        }
        defer { IOObjectRelease(iterator) }

        var candidates: [Candidate] = []
        var framebuffer = IOIteratorNext(iterator)
        while framebuffer != 0 {
            if let candidate = candidate(for: framebuffer) {
                candidates.append(candidate)
            }
            IOObjectRelease(framebuffer)
            framebuffer = IOIteratorNext(iterator)
        }

        guard let matchIndex = DisplayHardwareIdentity.uniqueMatchIndex(
            for: mainDisplay,
            candidates: candidates.map(\.identity)
        ), let value = candidates[matchIndex].brightness else {
            return .unavailable
        }
        return Self.validatedBrightness(value)
    }

    private func candidate(for framebuffer: io_service_t) -> Candidate? {
        let info = IODisplayCreateInfoDictionary(framebuffer, IOOptionBits(kIODisplayMatchingInfo)).takeRetainedValue() as NSDictionary
        guard let vendorID = number(in: info, key: kDisplayVendorID),
              let productID = number(in: info, key: kDisplayProductID)
        else { return nil }

        let identity = DisplayHardwareIdentity(
            vendorID: vendorID,
            productID: productID,
            serialNumber: number(in: info, key: kDisplaySerialNumber) ?? 0
        )
        let displayService = IODisplayForFramebuffer(framebuffer, 0)
        guard displayService != 0 else { return Candidate(identity: identity, brightness: nil) }
        defer { IOObjectRelease(displayService) }
        return Candidate(identity: identity, brightness: readBrightnessParameter(for: displayService))
    }

    private func readBrightnessParameter(for displayService: io_service_t) -> Double? {
        func read(_ parameterName: CFString) -> Double? {
            var rawValue: Float = 0
            guard IODisplayGetFloatParameter(displayService, 0, parameterName, &rawValue) == kIOReturnSuccess else { return nil }
            return Double(rawValue)
        }
        let resolved = Self.resolvedBrightness(
            standard: read(kIODisplayBrightnessKey as CFString),
            linearFallback: read(kIODisplayLinearBrightnessKey as CFString)
        )
        if case .available(let value) = resolved { return value }
        return nil
    }

    private struct Candidate {
        let identity: DisplayHardwareIdentity
        let brightness: Double?
    }
    #endif

    private func number(in dictionary: NSDictionary, key: String) -> UInt32? {
        (dictionary[key] as? NSNumber)?.uint32Value
    }
}

#if DEBUG
private extension DisplayBrightnessService {
    struct DiagnosticCandidate {
        let identity: DisplayHardwareIdentity
        let brightness: Double?
        let framebufferIndex: Int
        let displayServiceResolved: Bool
        let standardBrightness: DisplayBrightnessParameterDiagnostic
        let linearBrightness: DisplayBrightnessParameterDiagnostic
    }

    struct DiagnosticParameterRead {
        let value: Double?
        let standard: DisplayBrightnessParameterDiagnostic
        let linear: DisplayBrightnessParameterDiagnostic
    }
}

private final class DisplayBrightnessDiagnosticRecorder {
    private let mainDisplay: MainDisplayDescriptor
    private let isBuiltIn: Bool
    private let bounds: CGRect
    private var framebufferCount = 0
    private var candidates: [DisplayBrightnessFramebufferDiagnostic] = []
    private var vendorMatchCount = 0
    private var vendorProductMatchCount = 0
    private var vendorProductSerialMatchCount: Int?
    private var selection: DisplayBrightnessIdentitySelection = .noMatch
    private var identityFieldsUsed = "none"
    private var selectedFramebufferIndex: Int?
    private var displayServiceResolved: Bool?
    private var standardBrightness = DisplayBrightnessParameterDiagnostic.notAttempted
    private var linearBrightness = DisplayBrightnessParameterDiagnostic.notAttempted
    private var failureStage: DisplayBrightnessFailureStage = .none

    init(mainDisplay: MainDisplayDescriptor, isBuiltIn: Bool, bounds: CGRect) {
        self.mainDisplay = mainDisplay
        self.isBuiltIn = isBuiltIn
        self.bounds = bounds
    }

    func recordFramebuffer() { framebufferCount += 1 }

    func recordCandidate(
        index: Int,
        vendorID: UInt32?,
        productID: UInt32?,
        serialNumber: UInt32?,
        displayServiceResolved: Bool?,
        standard: DisplayBrightnessParameterDiagnostic,
        linear: DisplayBrightnessParameterDiagnostic
    ) {
        candidates.append(DisplayBrightnessFramebufferDiagnostic(
            index: index,
            vendorID: vendorID,
            productID: productID,
            serialNumber: serialNumber,
            metadataReadable: vendorID != nil && productID != nil,
            displayServiceResolved: displayServiceResolved,
            standardBrightness: standard,
            linearBrightness: linear
        ))
    }

    func recordCandidate(_ candidate: DisplayBrightnessService.DiagnosticCandidate) {
        recordCandidate(
            index: candidate.framebufferIndex,
            vendorID: candidate.identity.vendorID,
            productID: candidate.identity.productID,
            serialNumber: candidate.identity.serialNumber,
            displayServiceResolved: candidate.displayServiceResolved,
            standard: candidate.standardBrightness,
            linear: candidate.linearBrightness
        )
    }

    func recordIdentityMatching(mainDisplay: MainDisplayDescriptor, candidates: [DisplayBrightnessService.DiagnosticCandidate]) {
        let identities = candidates.map(\.identity)
        vendorMatchCount = identities.filter { $0.vendorID == mainDisplay.vendorID }.count
        vendorProductMatchCount = identities.filter { $0.vendorID == mainDisplay.vendorID && $0.productID == mainDisplay.productID }.count
        vendorProductSerialMatchCount = mainDisplay.serialNumber == 0 ? nil : identities.filter {
            $0.vendorID == mainDisplay.vendorID && $0.productID == mainDisplay.productID && $0.serialNumber == mainDisplay.serialNumber
        }.count
        let matches = identities.indices.filter { identities[$0].matches(mainDisplay) }
        if matches.count == 1 {
            selection = .uniqueMatch
            let identity = identities[matches[0]]
            identityFieldsUsed = mainDisplay.serialNumber != 0 && identity.serialNumber != 0
                ? "vendor + product + serial"
                : "vendor + product (serial unavailable)"
        } else if matches.count > 1 {
            selection = .ambiguousMatch
        }
    }

    func recordUnresolvedIdentity(mainDisplay: MainDisplayDescriptor, candidateCount: Int) {
        failureStage = DisplayBrightnessDiagnostic.classifyFailure(
            framebufferCount: framebufferCount,
            mainDisplayMetadataIsUsable: mainDisplay.vendorID != 0 && mainDisplay.productID != 0,
            selection: candidateCount == 0 ? .noMatch : selection,
            displayServiceResolved: nil,
            standardBrightness: .notAttempted,
            linearBrightness: .notAttempted
        )
    }

    func recordSelectedCandidate(_ candidate: DisplayBrightnessService.DiagnosticCandidate) {
        selectedFramebufferIndex = candidate.framebufferIndex
        displayServiceResolved = candidate.displayServiceResolved
        standardBrightness = candidate.standardBrightness
        linearBrightness = candidate.linearBrightness
        guard candidate.brightness == nil else { return }
        failureStage = DisplayBrightnessDiagnostic.classifyFailure(
            framebufferCount: framebufferCount,
            mainDisplayMetadataIsUsable: mainDisplay.vendorID != 0 && mainDisplay.productID != 0,
            selection: selection,
            displayServiceResolved: displayServiceResolved,
            standardBrightness: standardBrightness,
            linearBrightness: linearBrightness
        )
    }

    func complete(availability: DisplayBrightnessAvailability) -> DisplayBrightnessDiagnostic {
        let source = DisplayBrightnessDiagnostic.resolvedSource(
            availability: availability,
            standardBrightness: standardBrightness,
            linearBrightness: linearBrightness
        )
        let value: Double?
        if case .available(let resolved) = availability {
            value = resolved
            failureStage = .none
        } else {
            value = nil
            if failureStage == .none {
                failureStage = framebufferCount == 0 ? .framebufferEnumeration : .displayIdentityMatch
            }
        }
        return DisplayBrightnessDiagnostic(
            mainDisplay: mainDisplay,
            isBuiltIn: isBuiltIn,
            bounds: bounds,
            framebufferCount: framebufferCount,
            framebufferCandidates: candidates,
            vendorMatchCount: vendorMatchCount,
            vendorProductMatchCount: vendorProductMatchCount,
            vendorProductSerialMatchCount: vendorProductSerialMatchCount,
            selection: selection,
            identityFieldsUsed: identityFieldsUsed,
            selectedFramebufferIndex: selectedFramebufferIndex,
            displayServiceResolved: displayServiceResolved,
            standardBrightness: standardBrightness,
            linearBrightness: linearBrightness,
            source: source,
            value: value,
            failureStage: failureStage
        )
    }
}
#endif

/// Control Center brightness. IOFramebuffer is not published for the built-in panel on newer macOS.
private enum DisplaySliderBrightness {
    private typealias Getter = @convention(c) (UInt32, UnsafeMutablePointer<Float>) -> Int32

    private static let getter: Getter? = {
        guard let handle = dlopen(
            "/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices",
            RTLD_LAZY
        ), let symbol = dlsym(handle, "DisplayServicesGetBrightness") else {
            return nil
        }
        return unsafeBitCast(symbol, to: Getter.self)
    }()

    static func read(displayID: CGDirectDisplayID) -> Double? {
        guard let getter else { return nil }
        var value: Float = 0
        guard getter(displayID, &value) == 0 else { return nil }
        return Double(value)
    }
}
