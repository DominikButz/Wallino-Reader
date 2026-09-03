import Foundation
import SwiftUI

enum RoutePath: Hashable {
    case registration
    case addEntry
    case entry(Entry)
    case synthesis(Entry)
    case tags(Entry)
    case entriesForTag(Tag)
    case tips
    case about
    case setting
}
