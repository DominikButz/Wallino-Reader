import Combine
import CoreData
import Factory
import Foundation
import SharedLib
import WallabagKit

final class WallabagSession: ObservableObject {
    enum State {
        case unknown
        case connecting
        case connected
        case error(reason: String)
        case offline
    }

    @Published var state: State = .unknown
    @Injected(\.wallabagKit) var kit
    @CoreDataViewContext var coreDataContext: NSManagedObjectContext
    private var cancellable = Set<AnyCancellable>()

    func requestSession(clientId: String, clientSecret: String, username: String, password: String) async {
        kit.clientId = clientId
        kit.clientSecret = clientSecret
        kit.username = username
        kit.password = password

        do {
            let token = try await kit.requestTokenAsync()
            WallabagUserDefaults.refreshToken = token.refreshToken
            WallabagUserDefaults.accessToken = token.accessToken
            kit.accessToken = token.accessToken
            kit.refreshToken = token.refreshToken
            state = .connected
        } catch {
            guard let error = error as? WallabagKitError else {
                state = .error(reason: "Unknown error")
                return
            }
            switch error {
            case let WallabagKitError.jsonError(jsonError):
                state = .error(reason: jsonError.errorDescription)
            case WallabagKitError.invalidApiEndpoint:
                state = .error(reason: "Invalid api endpoint, check your host configuration")
            default:
                state = .error(reason: error.localizedDescription)
            }
        }
    }

    func addEntry(url: String) async throws {
        let wallabagEntry: WallabagEntry = try await kit.send(to: WallabagEntryEndpoint.add(url: url, title: nil, content: nil, tags: [], starred: false, archived: false))

        let entry = Entry(context: coreDataContext)
        entry.hydrate(from: wallabagEntry)
    }

    func update(_ entry: Entry, parameters: WallabagKit.Parameters) async throws {
        _ = try await kit.send(to: WallabagEntryEndpoint.update(id: entry.id, parameters: parameters))
    }

    func delete(entry: Entry) async throws {
        _ = try await kit.send(to: WallabagEntryEndpoint.delete(id: entry.id))
    }

    func add(tag: String, for entry: Entry) async throws {
        let wallabagEntry = try await kit.send(to: WallabagEntryEndpoint.addTag(tag: tag, entry: entry.id))
        await MainActor.run {
            syncTag(for: entry, with: wallabagEntry)
        }
    }

    func refresh(entry: Entry) async throws {
        let wallabagEntry = try await kit.send(to: WallabagEntryEndpoint.reload(id: entry.id))

        entry.hydrate(from: wallabagEntry)
    }

    func delete(tag: Tag, for entry: Entry) async throws {
        let wallabagEntry = try await kit.send(to: WallabagEntryEndpoint.deleteTag(tagId: tag.id, entry: entry.id))
        await MainActor.run {
            syncTag(for: entry, with: wallabagEntry)
        }
    }

    private func syncTag(for entry: Entry, with wallabagEntry: WallabagEntry) {
        let currentTags = entry.tags
        let newTagIds = Set(wallabagEntry.tags?.map { $0.id } ?? [])

        entry.objectWillChange.send()

        for wallabagTag in wallabagEntry.tags ?? [] {
            if !currentTags.contains(where: { $0.id == wallabagTag.id }) {
                let tag: Tag
                if let existingTag = try? self.coreDataContext.fetch(Tag.fetchOneById(wallabagTag.id)).first {
                    tag = existingTag
                } else {
                    tag = Tag(context: self.coreDataContext)
                    tag.id = wallabagTag.id
                    tag.slug = wallabagTag.slug
                    tag.label = wallabagTag.label
                }
                entry.tags.insert(tag)
            }
        }

        for tag in currentTags {
            if !newTagIds.contains(tag.id) {
                entry.tags.remove(tag)
            }
        }

        try? coreDataContext.save()
    }

    /// try retrieve wallabag config (available on server 2.5)
    func config() async throws -> WallabagConfig? {
        try? await kit.send(to: WallabagConfigEndpoint.get)
    }
}
