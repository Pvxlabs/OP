import Foundation
import SQLite3

private final class SnapshotDatabase: @unchecked Sendable {
    let handle: OpaquePointer
    init(url: URL) throws {
        let directory = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true,
                                               attributes: [.posixPermissions: 0o700])
        var pointer: OpaquePointer?
        guard sqlite3_open_v2(url.path, &pointer, SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_FULLMUTEX, nil) == SQLITE_OK,
              let pointer else {
            if let pointer { sqlite3_close(pointer) }
            throw CocoaError(.fileWriteUnknown)
        }
        handle = pointer
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
        sqlite3_busy_timeout(handle, 3000)
    }
    deinit { sqlite3_close(handle) }
}

/// The actor is the only owner that uses its connection. No website data or network access.
actor SnapshotStore {
    struct Limits: Sendable {
        var conversations = 200
        var messages = 500
        var bytes = 64 * 1024 * 1024
        var age: TimeInterval = 30 * 24 * 60 * 60
    }
    private let database: SnapshotDatabase
    private let limits: Limits
    private var prepared = false
    private var sequences: [String: Int] = [:]
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private var db: OpaquePointer { database.handle }
    private let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

    init(url: URL, limits: Limits = Limits()) throws {
        database = try SnapshotDatabase(url: url)
        self.limits = limits
    }

    private func execute(_ sql: String, values: [String] = []) throws {
        let statement = try statement(sql, values: values)
        defer { sqlite3_finalize(statement) }
        var status = sqlite3_step(statement)
        while status == SQLITE_ROW { status = sqlite3_step(statement) }
        guard status == SQLITE_DONE else { throw CocoaError(.fileWriteUnknown) }
    }
    private func statement(_ sql: String, values: [String]) throws -> OpaquePointer {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK, let statement else {
            throw CocoaError(.fileReadCorruptFile)
        }
        for (index, value) in values.enumerated() {
            guard sqlite3_bind_text(statement, Int32(index + 1), value, -1, transient) == SQLITE_OK else {
                sqlite3_finalize(statement)
                throw CocoaError(.fileWriteUnknown)
            }
        }
        return statement
    }
    private func rows(_ sql: String, values: [String] = []) throws -> [[String]] {
        let statement = try statement(sql, values: values)
        defer { sqlite3_finalize(statement) }
        var result: [[String]] = []
        while true {
            let status = sqlite3_step(statement)
            if status == SQLITE_DONE { return result }
            guard status == SQLITE_ROW else { throw CocoaError(.fileReadCorruptFile) }
            result.append((0..<sqlite3_column_count(statement)).map { index in
                guard let text = sqlite3_column_text(statement, index) else { return "" }
                return String(cString: text)
            })
        }
    }
    private func prepare() throws {
        guard !prepared else { return }
        try execute("PRAGMA journal_mode=WAL")
        try execute("PRAGMA synchronous=FULL")
        try execute("PRAGMA secure_delete=ON")
        try execute("CREATE TABLE IF NOT EXISTS conversations (id TEXT PRIMARY KEY, updated REAL NOT NULL)")
        try execute("CREATE TABLE IF NOT EXISTS messages (conversation TEXT NOT NULL REFERENCES conversations(id) ON DELETE CASCADE, id TEXT NOT NULL, record TEXT NOT NULL, bytes INTEGER NOT NULL, PRIMARY KEY(conversation,id))")
        if !(try rows("PRAGMA table_info(messages)")).contains(where: { $0[1] == "position" }) {
            try execute("ALTER TABLE messages ADD COLUMN position REAL NOT NULL DEFAULT 0")
            try execute("UPDATE messages SET position=json_extract(record,'$.order')")
        }
        try execute("PRAGMA foreign_keys=ON")
        // A prior process's streaming observation is never upgraded by restart.
        try execute("UPDATE messages SET record=json_set(record,'$.state','interrupted','$.lastObservation','interrupted') WHERE json_extract(record,'$.state')='streaming'")
        try execute("UPDATE messages SET record=json_set(record,'$.state','pageEnded','$.lastObservation','pageEnded') WHERE json_extract(record,'$.state')='complete' AND json_extract(record,'$.evidence')='turn-completed-stable'")
        prepared = true
        try prune(now: Date())
    }

    func recent() throws -> [ConversationSummary] {
        try prepare()
        return try rows("SELECT c.id,c.updated,count(m.id) FROM conversations c JOIN messages m ON m.conversation=c.id GROUP BY c.id ORDER BY c.updated DESC LIMIT 200").compactMap {
            guard let timestamp = Double($0[1]), let count = Int($0[2]), SnapshotIdentity.valid($0[0]) else { return nil }
            return ConversationSummary(id: $0[0], updatedAt: Date(timeIntervalSince1970: timestamp), messageCount: count)
        }
    }
    func messages(in conversation: String) throws -> [SavedMessage] {
        try prepare()
        return try readMessages(conversation)
    }
    private func readMessages(_ conversation: String) throws -> [SavedMessage] {
        try rows("SELECT record,position FROM messages WHERE conversation=? ORDER BY position", values: [conversation]).map {
            var message = try decoder.decode(SavedMessage.self, from: Data($0[0].utf8))
            message.order = Double($0[1]) ?? message.order
            return message
        }
    }
    private func save(_ message: SavedMessage, conversation: String) throws {
        let data = try encoder.encode(message)
        try execute("INSERT INTO messages(conversation,id,record,bytes,position) VALUES(?,?,?,?,?) ON CONFLICT(conversation,id) DO UPDATE SET record=excluded.record,bytes=excluded.bytes,position=excluded.position",
                    values: [conversation, message.id, String(decoding: data, as: UTF8.self), String(data.count), String(message.order)])
    }

    @discardableResult
    func ingest(_ batch: ObservedConversation, now: Date = Date()) throws -> Bool {
        try prepare()
        guard batch.schema == 1, SnapshotIdentity.valid(batch.documentID),
              SnapshotIdentity.valid(batch.conversationID), batch.sequence > 0,
              batch.messages.count <= 500,
              batch.messages.reduce(0, { $0 + $1.body.utf8.count }) <= 2 * 1024 * 1024 else { return false }
        let source = batch.documentID + ":" + batch.conversationID
        guard batch.sequence > (sequences[source] ?? 0) else { return false }
        let conversation = batch.conversationID.lowercased()
        let incoming = batch.messages.filter {
            SnapshotIdentity.valid($0.id) && ["assistant", "user"].contains($0.role) && $0.body.utf8.count <= 1024 * 1024
        }
        guard Set(incoming.map { $0.id.lowercased() }).count == incoming.count else { return false }
        let context = (batch.order ?? incoming.map(\.id)).map { $0.lowercased() }
        guard context.count <= 500, context.allSatisfy(SnapshotIdentity.valid), Set(context).count == context.count else { return false }
        var orderedIDs = try rows("SELECT id FROM messages WHERE conversation=? ORDER BY position", values: [conversation]).map { $0[0] }
        let oldOrder = orderedIDs
        for observed in incoming where !orderedIDs.contains(observed.id.lowercased()) &&
            !observed.body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !SnapshotIdentity.isErrorText(observed.body) {
            let id = observed.id.lowercased()
            let position = context.firstIndex(of: id) ?? context.count
            let next = context.dropFirst(position + 1).first { orderedIDs.contains($0) }
            let previous = context.prefix(position).last { orderedIDs.contains($0) }
            if let next, let anchor = orderedIDs.firstIndex(of: next) { orderedIDs.insert(id, at: anchor) }
            else if let previous, let anchor = orderedIDs.firstIndex(of: previous) { orderedIDs.insert(id, at: anchor + 1) }
            else { orderedIDs.append(id) }
        }
        let positions = Dictionary(uniqueKeysWithValues: orderedIDs.enumerated().map { ($0.element, Double($0.offset)) })
        var changed = false
        try execute("BEGIN IMMEDIATE")
        do {
            try execute("INSERT OR IGNORE INTO conversations(id,updated) VALUES(?,?)", values: [conversation, String(now.timeIntervalSince1970)])
            if oldOrder != orderedIDs {
                for id in oldOrder {
                    try execute("UPDATE messages SET position=? WHERE conversation=? AND id=?", values: [String(positions[id]!), conversation, id])
                }
            }
            for observed in incoming {
                let id = observed.id.lowercased()
                let existingData = try rows("SELECT record FROM messages WHERE conversation=? AND id=?", values: [conversation, id]).first
                let existing = try existingData.map { try decoder.decode(SavedMessage.self, from: Data($0[0].utf8)) }
                let useful = !observed.body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !SnapshotIdentity.isErrorText(observed.body)
                var last = observed.state
                if !useful && last != .interrupted { last = .readFailure }
                if existing == nil && !useful { continue }
                let order = positions[id] ?? 0
                // A DOM 'complete' value proves only that the page ended this turn. It cannot
                // distinguish a stopped/truncated reply from a fully generated reply.
                let complete = observed.state == .complete && observed.evidence == "explicit-complete"
                let ended = observed.state == .pageEnded && observed.evidence == "turn-completed-stable"
                let state: ReplyState = complete ? .complete : (ended ? .pageEnded : (observed.state == .streaming ? .streaming : (observed.state == .interrupted ? .interrupted : .unverified)))
                var record = existing ?? SavedMessage(id: id, role: observed.role, body: observed.body,
                    fingerprint: SavedMessage.hash(observed.body), state: state, lastObservation: last,
                    evidence: complete || ended ? observed.evidence : nil, firstSeen: now, updatedAt: now, order: order)
                guard record.role == observed.role else { continue }
                record.order = order
                let before = try encoder.encode(record)
                record.lastObservation = last
                if observed.state == .interrupted && observed.evidence == "user-stop" {
                    record.interruptionReason = "user-stop"
                    if record.state != .complete && record.state != .pageEnded { record.state = .interrupted }
                }
                if useful {
                    let fingerprint = SavedMessage.hash(observed.body)
                    if record.fingerprint == fingerprint {
                        if complete { record.state = .complete; record.evidence = observed.evidence }
                        else if record.state != .complete && record.state != .pageEnded {
                            record.state = record.interruptionReason == nil ? state : .interrupted
                            if ended { record.evidence = observed.evidence }
                        }
                        // Matching official text resolves a candidate without duplicating the message.
                        if complete || ended { record.alternativeBody = nil }
                    } else if record.state == .complete || record.state == .pageEnded {
                        record.alternativeBody = observed.body
                    } else if observed.body.hasPrefix(record.body) || complete || ended {
                        let previousBody = record.body
                        let extensionOnly = observed.body.hasPrefix(previousBody)
                        record.body = observed.body
                        record.fingerprint = fingerprint
                        record.state = record.interruptionReason == nil ? state : .interrupted
                        record.evidence = complete || ended ? observed.evidence : nil
                        record.alternativeBody = extensionOnly || complete ? nil : previousBody
                    } else {
                        // Shrinkage or non-prefix replacement may be virtualization, a branch, or a render error.
                        if observed.body.utf8.count >= (record.alternativeBody?.utf8.count ?? 0) {
                            record.alternativeBody = observed.body
                        }
                    }
                } else if record.state == .streaming { record.state = .interrupted }
                let after = try encoder.encode(record)
                if existing == nil || before != after {
                    record.updatedAt = now
                    try save(record, conversation: conversation)
                    changed = true
                }
            }
            if batch.pageState == .readFailure || batch.pageState == .interrupted {
                for var record in try readMessages(conversation) where record.lastObservation != batch.pageState {
                    record.lastObservation = batch.pageState
                    if record.state == .streaming { record.state = .interrupted }
                    try save(record, conversation: conversation)
                    changed = true
                }
            }
            if changed {
                try execute("UPDATE conversations SET updated=? WHERE id=?", values: [String(now.timeIntervalSince1970), conversation])
            }
            try execute("DELETE FROM conversations WHERE id=? AND NOT EXISTS(SELECT 1 FROM messages WHERE conversation=?)", values: [conversation, conversation])
            try execute("COMMIT")
        } catch { try? execute("ROLLBACK"); throw error }
        if sequences.count > 128 { sequences.removeAll(keepingCapacity: true) }
        sequences[source] = batch.sequence
        if changed { try prune(now: now) }
        return changed
    }

    func interrupt(_ conversation: String) throws {
        try prepare()
        for var message in try readMessages(conversation) where message.state == .streaming {
            message.state = .interrupted
            message.lastObservation = .interrupted
            try save(message, conversation: conversation)
        }
    }

    private func prune(now: Date) throws {
        try execute("DELETE FROM conversations WHERE updated < ?", values: [String(now.addingTimeInterval(-limits.age).timeIntervalSince1970)])
        try execute("DELETE FROM conversations WHERE id IN (SELECT id FROM conversations ORDER BY updated DESC LIMIT -1 OFFSET ?)", values: [String(limits.conversations)])
        // The recovery UI explicitly describes this as a bounded partial local history.
        while let row = try rows("SELECT conversation FROM messages GROUP BY conversation HAVING count(*) > CAST(? AS INTEGER) LIMIT 1", values: [String(limits.messages)]).first {
            try execute("DELETE FROM messages WHERE conversation=? AND id IN (SELECT id FROM messages WHERE conversation=? ORDER BY position DESC LIMIT -1 OFFSET ?)",
                        values: [row[0], row[0], String(limits.messages)])
        }
        while (Int(try rows("SELECT coalesce(sum(bytes),0) FROM messages")[0][0]) ?? 0) > limits.bytes {
            try execute("DELETE FROM conversations WHERE id=(SELECT id FROM conversations ORDER BY updated ASC LIMIT 1)")
        }
    }

    func clear() throws {
        try prepare()
        try execute("DELETE FROM conversations")
        try execute("PRAGMA wal_checkpoint(TRUNCATE)")
        try execute("VACUUM")
        sequences.removeAll()
    }
}
