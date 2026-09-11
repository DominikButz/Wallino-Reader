import Foundation

@propertyWrapper
public struct Password {
    private var keychain: KeychainPasswordItem

    public init() {
        keychain = KeychainPasswordItem(service: "wallino-reader", account: "main", accessGroup: WallabagAppGroup.identifier)
    }

    public var wrappedValue: String {
        get { (try? keychain.readPassword()) ?? "" }
        set { try? keychain.savePassword(newValue) }
    }
}
