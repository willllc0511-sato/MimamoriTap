import SwiftUI
import MessageUI

// MARK: - 連絡先設定画面

/// 連絡先設定画面 - 緊急連絡先の登録・通知時間設定・テスト送信
struct ContactsView: View {
    /// 緊急連絡先の名前
    @AppStorage("emergencyContactName") private var contactName = ""
    /// 緊急連絡先のメールアドレス
    @AppStorage("emergencyContactEmail") private var contactEmail = ""
    /// 緊急連絡先の電話番号
    @AppStorage("emergencyContactPhone") private var contactPhone = ""
    /// 本人の名前（SOS通知に使用）
    @AppStorage("userName") private var userName = ""
    /// 毎日のタップ通知を送るかどうか
    @AppStorage("dailyTapNotifyEnabled") private var dailyTapNotifyEnabled = false
    /// 通知までの時間（時間単位）
    @AppStorage("notifyAfterHours") private var notifyAfterHours = 48

    /// テスト通知メール送信シート
    @State private var showMailComposer = false
    /// メール送信不可時のアラート
    @State private var showMailUnavailableAlert = false
    /// 保存完了メッセージ
    @State private var showSavedMessage = false

    /// 通知時間の選択肢
    private let hourOptions = [24, 48, 72]

    /// 連絡先が登録済みかどうか
    private var isContactRegistered: Bool {
        !contactName.trimmingCharacters(in: .whitespaces).isEmpty &&
        !contactEmail.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            List {
                // 説明テキスト
                Section {
                    HStack(spacing: 12) {
                        Image(systemName: "info.circle.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(Color("AccentGreen"))
                        Text("お知らせを届ける家族を登録してください")
                            .font(.system(size: 18))
                            .foregroundStyle(.primary)
                    }
                    .padding(.vertical, 4)
                }

                // 本人の名前
                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("あなたのお名前")
                            .font(.system(size: 16))
                            .foregroundStyle(.secondary)
                        TextField("例：田中 太郎", text: $userName)
                            .font(.system(size: 20))
                            .textContentType(.name)
                            .padding(.vertical, 4)
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("ご本人情報")
                        .font(.system(size: 16))
                } footer: {
                    Text("SOSの際に、この名前で家族にお知らせします")
                        .font(.system(size: 14))
                }

                // 緊急連絡先の入力フォーム
                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("お名前")
                            .font(.system(size: 16))
                            .foregroundStyle(.secondary)
                        TextField("例：田中 花子", text: $contactName)
                            .font(.system(size: 20))
                            .textContentType(.name)
                            .padding(.vertical, 4)
                    }
                    .padding(.vertical, 4)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("メールアドレス")
                            .font(.system(size: 16))
                            .foregroundStyle(.secondary)
                        TextField("例：hanako@example.com", text: $contactEmail)
                            .font(.system(size: 20))
                            .keyboardType(.emailAddress)
                            .textContentType(.emailAddress)
                            .autocapitalization(.none)
                            .padding(.vertical, 4)
                    }
                    .padding(.vertical, 4)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("電話番号")
                            .font(.system(size: 16))
                            .foregroundStyle(.secondary)
                        TextField("例：090-1234-5678", text: $contactPhone)
                            .font(.system(size: 20))
                            .keyboardType(.phonePad)
                            .textContentType(.telephoneNumber)
                            .padding(.vertical, 4)
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("緊急連絡先")
                        .font(.system(size: 16))
                } footer: {
                    Text("入力した内容は自動で保存されます")
                        .font(.system(size: 14))
                }

                // 毎日の確認通知設定
                Section {
                    Toggle(isOn: $dailyTapNotifyEnabled) {
                        Label {
                            Text("毎日の確認をお知らせする")
                                .font(.system(size: 20))
                        } icon: {
                            Image(systemName: "envelope.fill")
                                .foregroundStyle(Color("AccentGreen"))
                                .font(.system(size: 20))
                        }
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("毎日のお知らせ")
                        .font(.system(size: 16))
                } footer: {
                    Text("オンにすると、体調ボタンをタップした時に家族にメールでお知らせします")
                        .font(.system(size: 14))
                }

                // 通知までの時間設定
                Section {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("タップがない場合に家族へお知らせするまでの時間")
                            .font(.system(size: 16))
                            .foregroundStyle(.secondary)

                        Picker("通知までの時間", selection: $notifyAfterHours) {
                            ForEach(hourOptions, id: \.self) { hours in
                                Text("\(hours)時間").tag(hours)
                            }
                        }
                        .pickerStyle(.segmented)
                        .padding(.vertical, 4)
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("お知らせの時間")
                        .font(.system(size: 16))
                }

                // テスト通知送信
                Section {
                    Button {
                        sendTestNotification()
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "paperplane.fill")
                                .font(.system(size: 20))
                                .foregroundStyle(.white)
                                .frame(width: 40, height: 40)
                                .background(Circle().fill(Color("AccentGreen")))
                            VStack(alignment: .leading, spacing: 2) {
                                Text("テスト通知を送る")
                                    .font(.system(size: 20, weight: .medium))
                                Text("登録したメールアドレスに確認メールを送ります")
                                    .font(.system(size: 14))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .disabled(!isContactRegistered)
                    .padding(.vertical, 4)
                }

                // 登録状態の表示
                if isContactRegistered {
                    Section {
                        HStack(spacing: 10) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 22))
                                .foregroundStyle(Color("AccentGreen"))
                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(contactName)さん")
                                    .font(.system(size: 20, weight: .medium))
                                Text(contactEmail)
                                    .font(.system(size: 16))
                                    .foregroundStyle(.secondary)
                                if !contactPhone.isEmpty {
                                    Text(contactPhone)
                                        .font(.system(size: 16))
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    } header: {
                        Text("登録済みの連絡先")
                            .font(.system(size: 16))
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color("BackgroundGreen"))
            .navigationTitle("連絡先")
            .sheet(isPresented: $showMailComposer) {
                MailComposerView(
                    toAddress: contactEmail,
                    subject: "【みまもりタップ】テスト通知",
                    body: "これはみまもりタップのテスト通知です。\nこのメールが届いていれば、緊急時のお知らせも正常に届きます。"
                )
            }
            .alert("メールを送信できません", isPresented: $showMailUnavailableAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("メールアプリが設定されていません。\n端末の設定からメールアカウントを追加してください。")
            }
        }
    }

    /// テスト通知を送信
    private func sendTestNotification() {
        guard isContactRegistered else { return }
        if MFMailComposeViewController.canSendMail() {
            showMailComposer = true
        } else {
            showMailUnavailableAlert = true
        }
    }
}

// MARK: - メール送信画面（UIKit連携）

/// MFMailComposeViewControllerをSwiftUIで使うためのラッパー
struct MailComposerView: UIViewControllerRepresentable {
    let toAddress: String
    let subject: String
    let body: String
    var onComplete: ((MFMailComposeResult) -> Void)?

    @Environment(\.dismiss) private var dismiss

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let composer = MFMailComposeViewController()
        composer.mailComposeDelegate = context.coordinator
        composer.setToRecipients([toAddress])
        composer.setSubject(subject)
        composer.setMessageBody(body, isHTML: false)
        return composer
    }

    func updateUIViewController(_ uiViewController: MFMailComposeViewController, context: Context) {}

    class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        let parent: MailComposerView

        init(_ parent: MailComposerView) {
            self.parent = parent
        }

        func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
            parent.onComplete?(result)
            parent.dismiss()
        }
    }
}

#Preview {
    ContactsView()
}
