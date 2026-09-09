import Foundation
import SwiftUI

enum RoutePath: Hashable {
    case registration
    case addEntry
    case entry(Entry)
    case entriesForTag(Tag)
    case tips
    case about
    case setting
    case accountLogout
}
