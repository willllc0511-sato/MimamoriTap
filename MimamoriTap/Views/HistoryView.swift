import SwiftUI
import SwiftData

/// 履歴画面 - タップ履歴を一覧表示（体調アイコン付き）
struct HistoryView: View {
    @Query(sort: \TapRecord.timestamp, order: .reverse) private var records: [TapRecord]

    var body: some View {
        NavigationStack {
            ZStack {
                Color("BackgroundGreen")
                    .ignoresSafeArea()

                if records.isEmpty {
                    // 履歴がない場合
                    VStack(spacing: 16) {
                        Image(systemName: "clock")
                            .font(.system(size: 60))
                            .foregroundStyle(.secondary)
                        Text("まだ記録がありません")
                            .font(.system(size: 20))
                            .foregroundStyle(.secondary)
                        Text("ホーム画面でタップすると\nここに履歴が表示されます")
                            .font(.system(size: 16))
                            .foregroundStyle(.tertiary)
                            .multilineTextAlignment(.center)
                    }
                } else {
                    List(records) { record in
                        HStack(spacing: 14) {
                            // 体調アイコン（あれば絵文字、なければチェックマーク）
                            if let mood = record.mood {
                                Text(mood.emoji)
                                    .font(.system(size: 32))
                                    .frame(width: 40)
                            } else {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 28))
                                    .foregroundStyle(Color("AccentGreen"))
                                    .frame(width: 40)
                            }

                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 8) {
                                    Text(record.timestamp.formatted(date: .long, time: .omitted))
                                        .font(.system(size: 18, weight: .medium))
                                    // 体調ラベル
                                    if let mood = record.mood {
                                        Text(mood.label)
                                            .font(.system(size: 14, weight: .medium))
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 2)
                                            .background(Capsule().fill(Color("AccentGreen").opacity(0.15)))
                                    }
                                }
                                Text(record.timestamp.formatted(date: .omitted, time: .shortened))
                                    .font(.system(size: 16))
                                    .foregroundStyle(.secondary)
                                // メモがあれば表示
                                if let memo = record.memo, !memo.isEmpty {
                                    Text(memo)
                                        .font(.system(size: 15))
                                        .foregroundStyle(.secondary)
                                        .lineLimit(2)
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle("履歴")
        }
    }
}

#Preview("履歴なし") {
    HistoryView()
        .modelContainer(for: TapRecord.self, inMemory: true)
}

#Preview("履歴あり") {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: TapRecord.self, configurations: config)
    let context = container.mainContext

    // 直近7日分のダミーデータ
    let sampleData: [(Int, MoodType, String?)] = [
        (0, .good, "今日も元気です"),
        (1, .good, nil),
        (2, .normal, "少し眠いです"),
        (3, .good, "散歩しました"),
        (4, .bad, "腰が痛い"),
        (5, .normal, nil),
        (6, .good, "お出かけ中"),
    ]
    for (daysAgo, mood, memo) in sampleData {
        let date = Calendar.current.date(byAdding: .day, value: -daysAgo, to: .now)!
        let hour = [8, 9, 10, 7, 11, 9, 8][daysAgo]
        let timestamp = Calendar.current.date(bySettingHour: hour, minute: 30, second: 0, of: date)!
        let record = TapRecord(timestamp: timestamp, mood: mood, memo: memo)
        context.insert(record)
    }

    return HistoryView()
        .modelContainer(container)
}
