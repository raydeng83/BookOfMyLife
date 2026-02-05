//
//  AppleIntelligenceChecker.swift
//  BookOfMyLife
//
//  Checks availability of Apple Intelligence and Foundation Models
//

import Foundation

/// Checks if Apple Intelligence and Foundation Models are available
@available(iOS 18.0, *)
class AppleIntelligenceChecker {

    /// Check if Foundation Models is available on this device
    /// - Returns: true if Foundation Models can be used, false otherwise
    func isAvailable() async -> Bool {
        // Check iOS version - Foundation Models requires iOS 26.0+
        guard #available(iOS 26.0, *) else {
            print("[AI Checker] Foundation Models requires iOS 26.0+ (current system is older)")
            return false
        }

        // Check device capability
        // Foundation Models requires A17 Pro or M-series chips
        guard isDeviceSupported() else {
            print("[AI Checker] Device not supported")
            return false
        }

        // Check if Apple Intelligence is enabled
        // Note: As of iOS 18.0, there's no public API to check if user has enabled Apple Intelligence
        // We'll attempt to use Foundation Models and handle errors gracefully
        // For now, we assume if iOS 18+ and supported device, it's available
        print("[AI Checker] Foundation Models available")
        return true
    }

    /// Check if the device supports Apple Intelligence
    /// - Returns: true if device has capable chip (A17 Pro, M1+)
    private func isDeviceSupported() -> Bool {
        // Get device model identifier
        var systemInfo = utsname()
        uname(&systemInfo)
        let machineMirror = Mirror(reflecting: systemInfo.machine)
        let identifier = machineMirror.children.reduce("") { identifier, element in
            guard let value = element.value as? Int8, value != 0 else { return identifier }
            return identifier + String(UnicodeScalar(UInt8(value)))
        }

        // Check against known supported devices
        // iPhone 15 Pro and Pro Max (A17 Pro chip)
        let supportedIPhones = [
            "iPhone16,1",  // iPhone 15 Pro
            "iPhone16,2",  // iPhone 15 Pro Max
            "iPhone17,1",  // iPhone 16 Pro
            "iPhone17,2",  // iPhone 16 Pro Max
        ]

        // iPad with M1+ chips
        let supportedIPads = [
            // iPad Pro with M1
            "iPad13,4", "iPad13,5", "iPad13,6", "iPad13,7",   // iPad Pro 11" (3rd gen, M1) 2021
            "iPad13,8", "iPad13,9", "iPad13,10", "iPad13,11", // iPad Pro 12.9" (5th gen, M1) 2021

            // iPad Pro with M2
            "iPad14,3", "iPad14,4",  // iPad Pro 11" (4th gen, M2) 2022
            "iPad14,5", "iPad14,6",  // iPad Pro 12.9" (6th gen, M2) 2022

            // iPad Air with M1
            "iPad13,16", "iPad13,17", // iPad Air (5th gen, M1) 2022

            // iPad Air with M2
            "iPad14,8", "iPad14,9", "iPad14,10", "iPad14,11", // iPad Air (6th gen, M2) 2024

            // iPad Pro with M4
            "iPad16,3", "iPad16,4",  // iPad Pro 11" (M4) 2024
            "iPad16,5", "iPad16,6",  // iPad Pro 13" (M4) 2024
        ]

        // Mac always supported (M-series)
        #if targetEnvironment(macCatalyst)
        return true
        #endif

        let isSupported = supportedIPhones.contains(identifier) || supportedIPads.contains(identifier)

        if !isSupported {
            print("[AI Checker] Device \(identifier) does not support Apple Intelligence")
            print("[AI Checker] Requires: iPhone 15 Pro+, iPad with M1+ chip, or Mac with M-series")
            print("[AI Checker] Falling back to template-based summaries")
        } else {
            print("[AI Checker] Device \(identifier) supports Apple Intelligence")
        }

        return isSupported
    }

    /// Get user-facing status message
    /// - Returns: Status message explaining availability
    func getStatusMessage() async -> String {
        let available = await isAvailable()

        if available {
            return "AI-powered summaries available"
        } else {
            if !isDeviceSupported() {
                return "Device does not support AI summaries (requires iPhone 15 Pro or later, iPad with M1+ chip)"
            } else {
                return "Template-based summaries (Apple Intelligence not available)"
            }
        }
    }
}
