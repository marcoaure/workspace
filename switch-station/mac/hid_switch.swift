import Foundation
import IOKit.hid

func sendHIDCommand(vendorID: Int, productID: Int, data: [UInt8]) -> Bool {
    let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
    
    let matching = [
        kIOHIDVendorIDKey: vendorID,
        kIOHIDProductIDKey: productID
    ] as CFDictionary
    
    IOHIDManagerSetDeviceMatching(manager, matching)
    IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone))
    
    guard let deviceSet = IOHIDManagerCopyDevices(manager) as? Set<IOHIDDevice> else {
        print("No devices found")
        return false
    }
    
    print("Found \(deviceSet.count) device(s)")
    
    for device in deviceSet {
        let usagePage = IOHIDDeviceGetProperty(device, kIOHIDPrimaryUsagePageKey as CFString) as? Int ?? 0
        let usage = IOHIDDeviceGetProperty(device, kIOHIDPrimaryUsageKey as CFString) as? Int ?? 0
        print("  Trying device usagePage=\(String(format: "0x%04X", usagePage)) usage=\(String(format: "0x%04X", usage))")
        
        let openResult = IOHIDDeviceOpen(device, IOOptionBits(kIOHIDOptionsTypeNone))
        if openResult != kIOReturnSuccess {
            print("    Open failed: \(String(format: "0x%08X", openResult))")
            continue
        }
        
        var reportData = data
        let reportID = CFIndex(data[0])
        let sendResult = IOHIDDeviceSetReport(device, kIOHIDReportTypeOutput, reportID, &reportData, reportData.count)
        if sendResult == kIOReturnSuccess {
            print("    SUCCESS!")
            IOHIDDeviceClose(device, IOOptionBits(kIOHIDOptionsTypeNone))
            IOHIDManagerClose(manager, IOOptionBits(kIOHIDOptionsTypeNone))
            return true
        } else {
            print("    Send failed: \(String(format: "0x%08X", sendResult))")
        }
        IOHIDDeviceClose(device, IOOptionBits(kIOHIDOptionsTypeNone))
    }
    
    IOHIDManagerClose(manager, IOOptionBits(kIOHIDOptionsTypeNone))
    return false
}

let args = CommandLine.arguments
guard args.count >= 4 else {
    print("Usage: hid_switch <vid> <pid> <hex_bytes>")
    exit(1)
}

let vid = Int(args[1], radix: 16) ?? 0
let pid = Int(args[2], radix: 16) ?? 0
let bytes = args[3].split(separator: ",").compactMap { UInt8($0.trimmingCharacters(in: .whitespaces), radix: 16) }

if sendHIDCommand(vendorID: vid, productID: pid, data: bytes) {
    exit(0)
} else {
    exit(1)
}
