# みまもりタップ (MimamoriTap)

## 概要
高齢者の安否確認iOSアプリ。毎日体調ボタンをタップすることで家族に安否を伝える。
- 開発者: Satoshi Taki（個人事業主）
- Bundle ID: `com.willllc.mimamoritap`
- 対象: iOS（Swift / SwiftUI / SwiftData）
- Xcodeプロジェクト（SPM等の外部依存なし）

## アーキテクチャ
```
MimamoriTap/
├── MimamoriTapApp.swift    # エントリーポイント、SwiftData ModelContainer設定
├── ContentView.swift        # TabView（ホーム/連絡先/履歴/設定）
├── NotificationManager.swift # ローカル通知（リマインド）管理
├── Models/
│   └── TapRecord.swift      # SwiftDataモデル（体調記録）、MoodType enum
└── Views/
    ├── HomeView.swift        # メイン画面（SOS・体調ボタン・ひとこと・ステータス）
    ├── ContactsView.swift    # 緊急連絡先登録
    ├── HistoryView.swift     # 履歴表示
    └── SettingsView.swift    # 設定（通知時刻・アニメーションON/OFF等）
```

## 主要機能
- **体調ボタン**: 元気😊 / ふつう😐 / 調子悪い😔 の3択。タップでSwiftDataに記録
- **SOSボタン**: ワンタップで緊急連絡先にメール送信、長押し(5秒)で119番発信
- **ひとこと定型文**: 「元気です」「お出かけ中」等をワンタップ送信
- **花びらアニメーション**: 体調ボタンタップ時に桜の花びらが舞う演出（設定で無効化可）
- **リマインド通知**: 未確認時にローカル通知でリマインド
- **連続確認ストリーク**: 連続タップ日数を表示

## データ保存
- **SwiftData**: TapRecord（体調記録）
- **AppStorage/UserDefaults**: 緊急連絡先、ユーザー名、通知設定、アニメーション設定等

## カスタムカラー（Assets.xcassets）
- `AccentGreen` — メインのアクセントカラー
- `AccentOrange` — 警告・ストリーク表示用
- `AccentColor` — システムアクセント

## ビルド & 実行
```bash
# シミュレータでビルド＆実行
xcodebuild -project MimamoriTap.xcodeproj -scheme MimamoriTap \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
xcrun simctl install "iPhone 17 Pro" <DerivedData>/Build/Products/Debug-iphonesimulator/MimamoriTap.app
xcrun simctl launch "iPhone 17 Pro" com.willllc.mimamoritap
```

## 設計方針
- 高齢者向けUI: 大きなボタン、シンプルな導線、わかりやすい日本語
- 体調ボタンはiPhoneが応答するのではなく、記録を家族に伝える仕組み（端末が話しかける演出は不要）
- 外部サービス依存なし（オフラインで基本機能が動作）
- メール送信はMFMailComposeViewController（標準メールアプリ経由）

## App Store公開に向けた残タスク
- [ ] アプリアイコン作成（1024x1024 PNG → AppIcon.appiconset）
- [ ] Apple Developer Program登録・署名設定
- [ ] スクリーンショット準備（6.7インチ・6.1インチ）
- [ ] プライバシーポリシーページ作成
- [ ] App Store Connect登録・審査提出
- [ ] Git リポジトリ初期化・初回コミット
