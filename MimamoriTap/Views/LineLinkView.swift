import SwiftUI

/// LINE連携画面 - 連携コード生成・QRコード表示・連携状態表示
struct LineLinkView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var linkCode: String?
    @State private var isLoading = false
    @State private var errorMessage: String?

    private let lineAddFriendURL = "https://lin.ee/t6A8cS4"

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    headerSection
                    stepsSection

                    if let code = linkCode {
                        codeDisplaySection(code: code)
                    } else {
                        generateCodeButton
                    }

                    if let error = errorMessage {
                        Text(error)
                            .font(.system(size: 16))
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("LINE連携")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("閉じる") { dismiss() }
                        .font(.system(size: 17))
                }
            }
        }
    }

    // MARK: - ヘッダー

    private var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "bell.badge.fill")
                .font(.system(size: 48))
                .foregroundStyle(Color("AccentGreen"))

            Text("家族にLINEで通知")
                .font(.system(size: 26, weight: .bold))

            Text("タップがない時や体調不良が続いた時に、\n家族のLINEに自動でお知らせします")
                .font(.system(size: 16))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 8)
    }

    // MARK: - 手順説明

    private var stepsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            stepRow(number: 1, text: "下のボタンで連携コードを発行")
            stepRow(number: 2, text: "家族にLINE公式アカウントを\n友だち追加してもらう")
            stepRow(number: 3, text: "家族がLINEに連携コードを送信")
            stepRow(number: 4, text: "連携完了！自動で通知が届きます")
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }

    private func stepRow(number: Int, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number)")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 28, height: 28)
                .background(Circle().fill(Color("AccentGreen")))

            Text(text)
                .font(.system(size: 18))
                .lineSpacing(4)
        }
    }

    // MARK: - コード表示

    private func codeDisplaySection(code: String) -> some View {
        VStack(spacing: 16) {
            Text("連携コード")
                .font(.system(size: 16))
                .foregroundStyle(.secondary)

            Text(code)
                .font(.system(size: 40, weight: .bold, design: .monospaced))
                .tracking(6)
                .foregroundStyle(Color("AccentGreen"))
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color("AccentGreen").opacity(0.1))
                )

            Text("24時間有効・1回限り")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)

            HStack(spacing: 16) {
                // コピーボタン
                Button {
                    UIPasteboard.general.string = code
                } label: {
                    Label("コピー", systemImage: "doc.on.doc")
                        .font(.system(size: 16, weight: .medium))
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(Capsule().fill(Color("AccentGreen").opacity(0.15)))
                }

                // LINEで送るシェアボタン
                ShareLink(
                    item: "みまもりタップの連携コード：\(code)\n\nLINE公式アカウント「みまもりタップ」を友だち追加して、このコードを送ってください。",
                    subject: Text("みまもりタップ 連携コード")
                ) {
                    Label("送る", systemImage: "square.and.arrow.up")
                        .font(.system(size: 16, weight: .medium))
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(Capsule().fill(Color("AccentGreen").opacity(0.15)))
                }
            }

            // 新しいコード発行ボタン
            Button {
                Task { await generateCode() }
            } label: {
                Text("新しいコードを発行")
                    .font(.system(size: 16))
                    .foregroundStyle(Color("AccentGreen"))
            }
            .padding(.top, 8)
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }

    // MARK: - コード生成ボタン

    private var generateCodeButton: some View {
        Button {
            Task { await generateCode() }
        } label: {
            if isLoading {
                ProgressView()
                    .tint(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
            } else {
                Text("連携コードを発行する")
                    .font(.system(size: 20, weight: .bold))
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
            }
        }
        .foregroundStyle(.white)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color("AccentGreen"))
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .disabled(isLoading)
    }

    // MARK: - Actions

    private func generateCode() async {
        isLoading = true
        errorMessage = nil

        do {
            // まずユーザーが存在することを確認
            await APIClient.shared.ensureUserExists()
            let code = try await APIClient.shared.generateLinkCode()
            linkCode = code
        } catch {
            errorMessage = "コードの発行に失敗しました。通信環境をご確認ください。"
        }

        isLoading = false
    }
}

#Preview {
    LineLinkView()
}
