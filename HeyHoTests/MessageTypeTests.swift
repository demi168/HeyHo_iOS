import Testing
import Foundation

/// MessageType（メッセージ種別・返信チェーン）のテスト
struct MessageTypeTests {

    // MARK: - 返信チェーン

    @Test func 返信はhey_ho_letsGo_heyの順に循環する() {
        #expect(MessageType.hey.reply == .ho)
        #expect(MessageType.ho.reply == .letsGo)
        #expect(MessageType.letsGo.reply == .hey)
    }

    @Test func 三回返信すると元に戻る() {
        for type in [MessageType.hey, .ho, .letsGo] {
            #expect(type.reply.reply.reply == type)
        }
    }

    // MARK: - rawValue

    @Test(arguments: [
        (MessageType.hey, "hey"),
        (MessageType.ho, "ho"),
        (MessageType.letsGo, "letsGo"),
    ])
    func rawValueがFirestore文字列と一致する(_ type: MessageType, _ raw: String) {
        #expect(type.rawValue == raw)
        #expect(MessageType(rawValue: raw) == type)
    }

    @Test func 未知のrawValueはnil() {
        #expect(MessageType(rawValue: "unknown") == nil)
    }

    // MARK: - Codable ラウンドトリップ

    @Test(arguments: [MessageType.hey, .ho, .letsGo])
    func Codableラウンドトリップ(_ type: MessageType) throws {
        let data = try JSONEncoder().encode(type)
        let decoded = try JSONDecoder().decode(MessageType.self, from: data)
        #expect(decoded == type)
    }
}
