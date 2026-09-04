import Foundation

@propertyWrapper
public struct Password {
    private var keychain: KeychainPasswordItem

    public init() {
        keychain = KeychainPasswordItem(service: "wallino-reader", account: "main", accessGroup: "group.com.duoyun.wallino-reader")
    }

    public var wrappedValue: String {
        get { (try? keychain.readPassword()) ?? "" }
        set { try? keychain.savePassword(newValue) }
    }
}
