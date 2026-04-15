import Foundation
import SwiftData

/// 体調の種類
enum MoodType: String, Codable, CaseIterable {
    case good = "good"       // 😊 元気
    case normal = "normal"   // 😐 ふつう
    case bad = "bad"         // 😔 調子悪い

    /// 表示用の絵文字
    var emoji: String {
        switch self {
        case .good: "😊"
        case .normal: "😐"
        case .bad: "😔"
        }
    }

    /// 表示用のラベル
    var label: String {
        switch self {
        case .good: "元気"
        case .normal: "ふつう"
        case .bad: "調子悪い"
        }
    }

}

/// タップ記録モデル - タップした日時・体調・メモを保存する
@Model
final class TapRecord {
    /// タップした日時
    var timestamp: Date
    /// 体調（元気/ふつう/調子悪い）
    var moodRaw: String?
    /// ひとことメモ（定型文・テキスト入力時に保存）
    var memo: String?

    /// 体調のenum変換
    var mood: MoodType? {
        get { moodRaw.flatMap { MoodType(rawValue: $0) } }
        set { moodRaw = newValue?.rawValue }
    }

    init(timestamp: Date = .now, mood: MoodType? = nil, memo: String? = nil) {
        self.timestamp = timestamp
        self.moodRaw = mood?.rawValue
        self.memo = memo
    }
}
