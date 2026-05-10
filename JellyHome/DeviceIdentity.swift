import Foundation

enum DeviceIdentity {
    private static let key = "deviceId"

    static var id: String {
        if let existing = UserDefaults.standard.string(forKey: key) {
            return existing
        }
        let newValue = UUID().uuidString
        UserDefaults.standard.set(newValue, forKey: key)
        return newValue
    }
}
