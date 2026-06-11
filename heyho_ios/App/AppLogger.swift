import Foundation
import os

/// アプリ共通のロガー。カテゴリ別の os.Logger を一元管理する。
/// 補間値（userId 等）はデフォルトで private 扱いになるため、明示的な privacy 指定は不要
enum AppLogger {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "com.demiflare168.HeyHo"

    static let firestore = Logger(subsystem: subsystem, category: "firestore")
    static let push      = Logger(subsystem: subsystem, category: "push")
    static let store     = Logger(subsystem: subsystem, category: "store")
    static let auth      = Logger(subsystem: subsystem, category: "auth")
    static let feedback  = Logger(subsystem: subsystem, category: "feedback")
}
