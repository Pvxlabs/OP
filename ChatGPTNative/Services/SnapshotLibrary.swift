import Foundation
import Observation

@MainActor @Observable
final class SnapshotLibrary {
    static let shared = SnapshotLibrary()
    let store: SnapshotStore?
    var recent: [ConversationSummary] = []
    var revision = 0
    var conversationRevisions: [String: Int] = [:]
    var clearEpoch = 0
    var warning: String?
    var enabled: Bool {
        didSet { preferences?.set(enabled, forKey: "localSnapshotsEnabled") }
    }
    private let preferences: UserDefaults?
    private var generation = 0
    private var refreshSequence = 0

    init(store: SnapshotStore? = nil, preferences: UserDefaults? = .standard) {
        self.preferences = preferences
        enabled = preferences?.object(forKey: "localSnapshotsEnabled") as? Bool ?? true
        if let store { self.store = store }
        else {
            do {
                let root = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
                    .appendingPathComponent(Bundle.main.bundleIdentifier ?? "local.personal.ChatGPTNative", isDirectory: true)
                    .appendingPathComponent("Snapshots", isDirectory: true)
                self.store = try SnapshotStore(url: root.appendingPathComponent("replies.sqlite"))
            } catch { self.store = nil; warning = "本地快照存储不可用，当前回复尚未受保护。" }
        }
    }
    func refresh() async {
        guard let store else { return }
        refreshSequence += 1
        let sequence = refreshSequence
        let epoch = generation
        do {
            let loaded = try await store.recent()
            guard sequence == refreshSequence, epoch == generation else { return }
            recent = loaded
        } catch {
            if sequence == refreshSequence, epoch == generation { warning = "无法读取本地快照。网站数据不受影响。" }
        }
    }
    func receive(_ batch: ObservedConversation) async -> Bool {
        guard enabled, let store else { return false }
        let current = generation
        do {
            let changed = try await store.ingest(batch)
            guard current == generation else { return false }
            warning = nil
            if changed {
                revision += 1
                conversationRevisions[batch.conversationID, default: 0] += 1
                await refresh()
                let retained = Set(recent.map(\.id))
                conversationRevisions = conversationRevisions.filter { retained.contains($0.key) }
            }
            return true
        } catch { warning = "本地快照写入失败，当前更新尚未受保护。"; return false }
    }
    func messages(_ id: String) async -> [SavedMessage] {
        guard let store else { return [] }
        do { return try await store.messages(in: id) }
        catch { warning = "无法读取本地快照。"; return [] }
    }
    func interrupt(_ id: String?) {
        guard let id, let store else { return }
        Task {
            try? await store.interrupt(id)
            revision += 1
            if recent.contains(where: { $0.id == id }) { conversationRevisions[id, default: 0] += 1 }
        }
    }
    func clear() async {
        // Disabling capture prevents already open pages from immediately recreating deleted copies.
        enabled = false
        generation += 1
        guard let store else { return }
        do { try await store.clear(); recent = []; revision += 1; conversationRevisions = [:]; clearEpoch += 1; warning = nil }
        catch { warning = "本地快照未能清除，请重试。" }
    }
}
