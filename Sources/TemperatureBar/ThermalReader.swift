import Foundation
import IOKit

/// Reads Apple Silicon die temperatures via private IOHIDEventSystem APIs.
final class ThermalReader {
    private typealias IOHIDEventSystemClientCreateFn = @convention(c) (CFAllocator?) -> Unmanaged<AnyObject>?
    private typealias IOHIDEventSystemClientSetMatchingFn = @convention(c) (AnyObject, CFDictionary) -> Void
    private typealias IOHIDEventSystemClientCopyServicesFn = @convention(c) (AnyObject) -> Unmanaged<CFArray>?
    private typealias IOHIDServiceClientCopyEventFn = @convention(c) (AnyObject, Int64, Int64, Int64) -> Unmanaged<AnyObject>?
    private typealias IOHIDEventGetFloatValueFn = @convention(c) (AnyObject, Int64) -> Double
    private typealias IOHIDServiceClientCopyPropertyFn = @convention(c) (AnyObject, CFString) -> Unmanaged<CFTypeRef>?

    private static let kIOHIDEventTypeTemperature: Int64 = 15
    private static let kIOHIDEventFieldTemperature: Int64 = 15 << 16 // 983040

    private let createClient: IOHIDEventSystemClientCreateFn
    private let setMatching: IOHIDEventSystemClientSetMatchingFn
    private let copyServices: IOHIDEventSystemClientCopyServicesFn
    private let copyEvent: IOHIDServiceClientCopyEventFn
    private let getFloatValue: IOHIDEventGetFloatValueFn
    private let copyProperty: IOHIDServiceClientCopyPropertyFn

    private let client: AnyObject?

    init?() {
        guard let handle = dlopen("/System/Library/Frameworks/IOKit.framework/IOKit", RTLD_LAZY) else {
            return nil
        }

        func load<T>(_ name: String) -> T? {
            guard let sym = dlsym(handle, name) else { return nil }
            return unsafeBitCast(sym, to: T.self)
        }

        guard
            let createClient: IOHIDEventSystemClientCreateFn = load("IOHIDEventSystemClientCreate"),
            let setMatching: IOHIDEventSystemClientSetMatchingFn = load("IOHIDEventSystemClientSetMatching"),
            let copyServices: IOHIDEventSystemClientCopyServicesFn = load("IOHIDEventSystemClientCopyServices"),
            let copyEvent: IOHIDServiceClientCopyEventFn = load("IOHIDServiceClientCopyEvent"),
            let getFloatValue: IOHIDEventGetFloatValueFn = load("IOHIDEventGetFloatValue"),
            let copyProperty: IOHIDServiceClientCopyPropertyFn = load("IOHIDServiceClientCopyProperty")
        else {
            return nil
        }

        self.createClient = createClient
        self.setMatching = setMatching
        self.copyServices = copyServices
        self.copyEvent = copyEvent
        self.getFloatValue = getFloatValue
        self.copyProperty = copyProperty

        guard let unmanaged = createClient(kCFAllocatorDefault) else {
            return nil
        }
        let client = unmanaged.takeRetainedValue()
        self.client = client

        let matching: [String: Any] = [
            "PrimaryUsagePage": 0xff00,
            "PrimaryUsage": 5
        ]
        setMatching(client, matching as CFDictionary)
    }

    /// Returns the best CPU temperature in °C, or nil if unavailable.
    func readCPUTemperature() -> Double? {
        guard let client else { return nil }
        guard let servicesUnmanaged = copyServices(client) else { return nil }
        let services = servicesUnmanaged.takeRetainedValue() as [AnyObject]

        var accTemps: [Double] = []
        var tdieTemps: [Double] = []
        var allTemps: [Double] = []

        for service in services {
            guard let name = productName(of: service) else { continue }
            guard let temp = temperature(of: service), isValid(temp) else { continue }

            allTemps.append(temp)

            let lower = name.lowercased()
            if name.hasPrefix("pACC") || name.hasPrefix("eACC") {
                accTemps.append(temp)
            } else if lower.contains("tdie") {
                tdieTemps.append(temp)
            }
        }

        if let maxAcc = accTemps.max() {
            return maxAcc
        }
        if let maxTdie = tdieTemps.max() {
            return maxTdie
        }
        return allTemps.max()
    }

    private func productName(of service: AnyObject) -> String? {
        guard let unmanaged = copyProperty(service, "Product" as CFString) else {
            return nil
        }
        let value = unmanaged.takeRetainedValue()
        return value as? String
    }

    private func temperature(of service: AnyObject) -> Double? {
        guard let eventUnmanaged = copyEvent(
            service,
            Self.kIOHIDEventTypeTemperature,
            0,
            0
        ) else {
            return nil
        }
        let event = eventUnmanaged.takeRetainedValue()
        return getFloatValue(event, Self.kIOHIDEventFieldTemperature)
    }

    private func isValid(_ temp: Double) -> Bool {
        temp.isFinite && temp > 0 && temp < 120
    }
}
