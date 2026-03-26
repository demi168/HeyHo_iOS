import Foundation
import FirebaseFirestore

struct AppUser: Identifiable, Codable {
    @DocumentID var id: String?
    var displayName: String
    var createdAt: Date
    /// アイコンカラー（16進数文字列、例: "FF6B6B"）
    var iconColor: String?

    enum CodingKeys: String, CodingKey {
        case id
        case displayName = "displayName"
        case createdAt = "createdAt"
        case iconColor = "iconColor"
    }

    init(id: String? = nil, displayName: String, createdAt: Date = Date(), iconColor: String? = nil) {
        self.id = id
        self.displayName = displayName
        self.createdAt = createdAt
        self.iconColor = iconColor
    }
}
