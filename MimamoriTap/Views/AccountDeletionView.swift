import SwiftUI

/// アカウント削除確認画面
struct AccountDeletionView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var isDeleting = false
    @State private var showConfirmation = false
    @State private var errorMessage: String?
    @State private var isDeleted = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(.red)

                    Text("アカウントを削除しますか？")
                        .font(.system(size: 24, weight: .bold))

                    VStack(alignment: .leading, spacing: 12) {
                        warningRow("サーバーに保存された体調記録が削除されます")
                        warningRow("家族とのLINE連携が解除されます")
                        warningRow("削除後30日で完全に消去されます")
                        warningRow("端末内のデータ（履歴など）は残ります")
                    }
                    .padding(18)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(.secondarySystemGroupedBackground))
                    )

                    Text("サブスクリプションの解約はiOSの設定アプリから別途行ってください。")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)

                    if isDeleted {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(Color("AccentGreen"))
                            Text("アカウントが削除されました")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundStyle(Color("AccentGreen"))
                        }
                    } else {
                        Button {
                            showConfirmation = true
                        } label: {
                            if isDeleting {
                                ProgressView()
                                    .tint(.white)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 56)
                            } else {
                                Text("アカウントを削除する")
                                    .font(.system(size: 20, weight: .bold))
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 56)
                            }
                        }
                        .foregroundStyle(.white)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.red)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .disabled(isDeleting)
                    }

                    if let error = errorMessage {
                        Text(error)
                            .font(.system(size: 16))
                            .foregroundStyle(.red)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("アカウント削除")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("閉じる") { dismiss() }
                        .font(.system(size: 17))
                }
            }
            .alert("本当に削除しますか？", isPresented: $showConfirmation) {
                Button("削除する", role: .destructive) {
                    Task { await deleteAccount() }
                }
                Button("キャンセル", role: .cancel) {}
            } message: {
                Text("この操作は取り消せません。")
            }
        }
    }

    private func warningRow(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "circle.fill")
                .font(.system(size: 6))
                .foregroundStyle(.secondary)
                .padding(.top, 8)
            Text(text)
                .font(.system(size: 17))
        }
    }

    private func deleteAccount() async {
        isDeleting = true
        errorMessage = nil

        do {
            try await APIClient.shared.deleteAccount()
            isDeleted = true
        } catch {
            errorMessage = "削除に失敗しました。通信環境をご確認ください。"
        }

        isDeleting = false
    }
}

#Preview {
    AccountDeletionView()
}
