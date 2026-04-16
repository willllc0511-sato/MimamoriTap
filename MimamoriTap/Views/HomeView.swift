import SwiftUI
import SwiftData
import MessageUI
import AudioToolbox

// MARK: - 桜の花びらShape

/// 桜の花びら形状 - 楕円2つを少しずらして重ねた桜の花びら
struct SakuraPetalShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        // 左片
        path.addEllipse(in: CGRect(x: 0, y: h * 0.1, width: w * 0.65, height: h * 0.85))
        // 右片（少しずらす）
        path.addEllipse(in: CGRect(x: w * 0.35, y: 0, width: w * 0.65, height: h * 0.85))
        return path
    }
}

// MARK: - 花びら1枚のパラメータ

/// 花火のように放射状に飛ぶ花びら1枚の情報
struct PetalParticle: Identifiable {
    let id = UUID()
    /// 放射角度（ラジアン）- ボタン中心からの飛び出し方向
    let angle: CGFloat
    /// 飛距離（pt）
    let distance: CGFloat
    /// 花びらのサイズ
    let size: CGFloat
    /// 花びらの色
    let color: Color
    /// アニメーション時間（秒）
    let duration: Double
    /// 初期回転角度（度）
    let initialRotation: Double
    /// 回転量（度）
    let rotationAmount: Double
    /// ゆらゆらの振幅
    let swayAmount: CGFloat
    /// 出発点（画面座標）
    let origin: CGPoint
}

// MARK: - ホーム画面 v2

/// ホーム画面 - SOS・安否確認・定型文・ステータスの4エリア構成
struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var allRecords: [TapRecord]

    // 安否確認関連
    @State private var bouncingMood: MoodType?

    // 花びらアニメーション
    @State private var petals: [PetalParticle] = []
    /// アニメーション設定（設定画面と共有）
    @AppStorage("animationEnabled") private var animationEnabled = true
    /// タップ音設定（設定画面と共有）
    @AppStorage("soundEnabled") private var soundEnabled = true
    /// SOSボタン表示設定（設定画面と共有）
    @AppStorage("sosVisible") private var sosVisible = true

    // SOS関連
    @State private var sosProgress: CGFloat = 0
    @State private var isSOSPressing = false
    @State private var sosTimer: Timer?
    @State private var sosMessage = ""
    @State private var showEmergencyCallDialog = false
    @State private var showSOSWarning = false
    /// SOSワンタップ確認ダイアログ
    @State private var showSOSConfirmDialog = false
    /// 連絡先未登録アラート
    @State private var showNoContactAlert = false
    /// メール送信不可アラート
    @State private var showMailUnavailableAlert = false
    /// SOSメール送信シート
    @State private var showSOSMailComposer = false
    /// SOSメールの件名・本文を一時保持
    @State private var sosMailSubject = ""
    @State private var sosMailBody = ""
    /// 緊急連絡先情報（AppStorage）
    @AppStorage("emergencyContactName") private var contactName = ""
    @AppStorage("emergencyContactEmail") private var contactEmail = ""
    @AppStorage("emergencyContactPhone") private var contactPhone = ""
    @AppStorage("userName") private var userName = ""
    /// 毎日のタップ通知が有効かどうか
    @AppStorage("dailyTapNotifyEnabled") private var dailyTapNotifyEnabled = false

    /// 毎日の確認メール送信シート
    @State private var showDailyMailComposer = false
    /// 毎日の確認メールの件名・本文
    @State private var dailyMailSubject = ""
    @State private var dailyMailBody = ""

    // 定型文関連
    @State private var quickPhrases: [String] = [
        "元気です😊",
        "ちょっと疲れた😅",
        "今日も頑張る💪",
        "のんびりしてます🍵",
        "お出かけ中🚶",
        "ごはん食べた🍚",
    ]
    @State private var tappedPhrase: String?

    // カウントダウン
    @State private var remainingTime = ""
    @State private var countdownTimer: Timer?

    // 体調ボタンエリアの座標を取得するための名前空間
    @Namespace private var animationSpace

    private var hasSeenSOSWarning: Bool {
        UserDefaults.standard.bool(forKey: "hasSeenSOSWarning")
    }

    private var isTappedToday: Bool {
        allRecords.contains { Calendar.current.isDateInToday($0.timestamp) }
    }

    private var lastTapToday: Date? {
        allRecords
            .filter { Calendar.current.isDateInToday($0.timestamp) }
            .max(by: { $0.timestamp < $1.timestamp })?
            .timestamp
    }

    /// 連続確認日数（ストリーク）
    private var streakDays: Int {
        let calendar = Calendar.current
        let uniqueDays = Set(allRecords.map { calendar.startOfDay(for: $0.timestamp) })
        var streak = 0
        var checkDate = calendar.startOfDay(for: Date())
        while uniqueDays.contains(checkDate) {
            streak += 1
            guard let prev = calendar.date(byAdding: .day, value: -1, to: checkDate) else { break }
            checkDate = prev
        }
        return streak
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color("BackgroundGreen")
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        if sosVisible {
                            sosSection
                        }
                        checkInSection
                        quickPhraseSection
                        statusSection
                        Spacer().frame(height: 16)
                    }
                    .padding(.horizontal, 20)
                }

                // 花びらオーバーレイ（最前面・タッチ透過）
                petalOverlay
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            }
            .navigationTitle("みまもりタップ")
            .onAppear { startCountdownTimer() }
            .onDisappear { countdownTimer?.invalidate() }
            .alert("緊急時のみ使用してください", isPresented: $showSOSWarning) {
                Button("わかりました", role: .cancel) {
                    UserDefaults.standard.set(true, forKey: "hasSeenSOSWarning")
                }
            } message: {
                Text("SOSボタンは緊急時に家族や救急に連絡するためのものです。間違ってタップしても、長押ししなければ119番には発信されません。")
            }
            .alert("緊急連絡先に電話しますか？", isPresented: $showSOSConfirmDialog) {
                Button("はい（電話する）", role: .destructive) { sendEmergencyAction(call119: false) }
                Button("キャンセル", role: .cancel) {}
            } message: {
                Text("\(contactName)さんに電話をかけ、メールでもお知らせします。")
            }
            .alert("119番に電話しますか？", isPresented: $showEmergencyCallDialog) {
                Button("はい（119番に発信）", role: .destructive) { sendEmergencyAction(call119: true) }
                Button("キャンセル", role: .cancel) {}
            } message: {
                Text("救急車を呼びます。\(contactName)さんにもメールでお知らせします。")
            }
            .alert("連絡先が登録されていません", isPresented: $showNoContactAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("先に「連絡先」タブから、お知らせを届ける家族を登録してください。")
            }
            .alert("メールを送信できません", isPresented: $showMailUnavailableAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("メールアプリが設定されていません。\n端末の設定からメールアカウントを追加してください。")
            }
            .sheet(isPresented: $showDailyMailComposer) {
                MailComposerView(
                    toAddress: contactEmail,
                    subject: dailyMailSubject,
                    body: dailyMailBody
                )
            }
            .sheet(isPresented: $showSOSMailComposer) {
                MailComposerView(
                    toAddress: contactEmail,
                    subject: sosMailSubject,
                    body: sosMailBody,
                    onComplete: { result in
                        if result == .sent {
                            withAnimation { sosMessage = "緊急連絡先にお知らせしました" }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                                withAnimation { sosMessage = "" }
                            }
                        }
                    }
                )
            }
        }
    }

    // MARK: - 1. SOSエリア

    private var sosSection: some View {
        VStack(spacing: 8) {
            HStack {
                ZStack {
                    Circle()
                        .stroke(Color.red.opacity(0.15), lineWidth: 4)
                        .frame(width: 56, height: 56)
                    Circle()
                        .trim(from: 0, to: sosProgress)
                        .stroke(Color.red, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        .frame(width: 56, height: 56)
                        .rotationEffect(.degrees(-90))
                        .animation(.linear(duration: 0.1), value: sosProgress)
                    Text("SOS")
                        .font(.system(size: 16, weight: .heavy))
                        .foregroundStyle(.white)
                        .frame(width: 48, height: 48)
                        .background(Circle().fill(Color.red))
                }
                .onTapGesture {
                    handleSOSTap()
                }
                .onLongPressGesture(minimumDuration: 5, perform: {
                    sosTimer?.invalidate()
                    isSOSPressing = false
                    sosProgress = 0
                    // 連絡先未登録でも119番は使えるようにする
                    showEmergencyCallDialog = true
                }, onPressingChanged: { isPressing in
                    if isPressing {
                        isSOSPressing = true
                        sosProgress = 0
                        sosTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
                            if sosProgress < 1.0 { sosProgress += 0.01 }
                        }
                    } else {
                        sosTimer?.invalidate()
                        isSOSPressing = false
                        withAnimation(.easeOut(duration: 0.3)) { sosProgress = 0 }
                    }
                })

                VStack(alignment: .leading, spacing: 2) {
                    Text("緊急時はSOSをタップ")
                        .font(.system(size: 15))
                        .foregroundStyle(.secondary)
                    if isSOSPressing {
                        Text("長押し中… 119番に発信します")
                            .font(.system(size: 13))
                            .foregroundStyle(.red)
                    }
                }
                Spacer()
            }

            if !sosMessage.isEmpty {
                Text(sosMessage)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.red)
                    .transition(.opacity)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemGroupedBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.red.opacity(0.2), lineWidth: 1)
                )
        )
    }

    // MARK: - 2. 安否確認エリア

    private var checkInSection: some View {
        VStack(spacing: 20) {
            Text("今日の調子は？")
                .font(.system(size: 26, weight: .bold))
                .foregroundStyle(.primary)

            // 3つの体調ボタン - GeometryReaderで中心座標を取得
            HStack(spacing: 16) {
                ForEach(MoodType.allCases, id: \.self) { mood in
                    moodButtonWithGeometry(mood)
                }
            }

            if isTappedToday {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color("AccentGreen"))
                    Text("今日は確認済みです")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(Color("AccentGreen"))
                }
                .padding(.top, 4)
            }

            if let lastTap = lastTapToday {
                Text("最終確認: \(lastTap.formatted(date: .omitted, time: .shortened))")
                    .font(.system(size: 16))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 24)
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }

    /// 体調ボタン - GeometryReaderで画面上の中心座標を渡す
    private func moodButtonWithGeometry(_ mood: MoodType) -> some View {
        let isActive = bouncingMood == mood

        return GeometryReader { geo in
            Button {
                // ボタン中心の画面座標を計算
                let frame = geo.frame(in: .global)
                let center = CGPoint(x: frame.midX, y: frame.midY)
                moodTapped(mood, from: center)
            } label: {
                VStack(spacing: 8) {
                    Text(mood.emoji)
                        .font(.system(size: 44))
                    Text(mood.label)
                        .font(.system(size: 18, weight: .semibold))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(buttonColor(for: mood).opacity(isActive ? 1.0 : 0.15))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(buttonColor(for: mood).opacity(isActive ? 0 : 0.3), lineWidth: 1)
                )
                .foregroundStyle(isActive ? .white : .primary)
            }
            .buttonStyle(.plain)
            .scaleEffect(isActive ? 0.92 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.5), value: isActive)
        }
        .frame(height: 110)
    }

    private func buttonColor(for mood: MoodType) -> Color {
        switch mood {
        case .good: Color("AccentGreen")
        case .normal: Color.blue
        case .bad: Color("AccentOrange")
        }
    }

    // MARK: - 3. ひとことエリア（定型文）

    private var quickPhraseSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("ひとことで伝える")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(.secondary)
                .padding(.leading, 4)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(quickPhrases, id: \.self) { phrase in
                        Button {
                            quickPhraseTapped(phrase)
                        } label: {
                            Text(phrase)
                                .font(.system(size: 17, weight: .medium))
                                .padding(.horizontal, 18)
                                .padding(.vertical, 12)
                                .background(
                                    Capsule()
                                        .fill(tappedPhrase == phrase
                                              ? Color("AccentGreen")
                                              : Color("AccentGreen").opacity(0.15))
                                )
                                .overlay(
                                    Capsule()
                                        .stroke(Color("AccentGreen").opacity(tappedPhrase == phrase ? 0 : 0.3), lineWidth: 1)
                                )
                                .foregroundStyle(tappedPhrase == phrase ? .white : .primary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 4)
            }
        }
    }

    // MARK: - 4. ステータスエリア

    private var statusSection: some View {
        VStack(spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(streakDays > 0 ? Color("AccentOrange") : .secondary)
                VStack(alignment: .leading, spacing: 2) {
                    Text("連続確認")
                        .font(.system(size: 15))
                        .foregroundStyle(.secondary)
                    Text("\(streakDays)日")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(streakDays > 0 ? Color("AccentOrange") : .secondary)
                }
                Spacer()
            }
            if !isTappedToday {
                HStack(spacing: 8) {
                    Image(systemName: "bell.badge")
                        .font(.system(size: 18))
                        .foregroundStyle(Color("AccentOrange"))
                    Text("あと\(remainingTime)で家族に通知されます")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }

    // MARK: - 花びらオーバーレイ

    /// 画面全体に花びらを重ねて表示（最前面）
    private var petalOverlay: some View {
        GeometryReader { geo in
            ForEach(petals) { petal in
                PetalFireworkView(petal: petal, screenSize: geo.size) {
                    petals.removeAll { $0.id == petal.id }
                }
            }
        }
    }

    // MARK: - アクション

    /// 体調ボタンタップ時の処理（花びら出発点の座標を受け取る）
    private func moodTapped(_ mood: MoodType, from origin: CGPoint) {
        // タップ音再生（1519: やわらかい確認音）
        if soundEnabled {
            AudioServicesPlaySystemSound(1519)
        }

        // SwiftDataに保存
        let record = TapRecord(mood: mood)
        modelContext.insert(record)
        NotificationManager.shared.cancelTodayReminderIfTapped(modelContext: modelContext)

        // 毎日の確認メール送信（設定ONかつ連絡先登録済みの場合）
        sendDailyNotifyMailIfNeeded(mood: mood, memo: nil)

        // バウンスアニメーション
        bouncingMood = mood
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            bouncingMood = nil
        }

        // 花びら演出（アニメーションONの場合のみ）
        if animationEnabled {
        switch mood {
        case .good:
            spawnFireworkPetals(
                count: Int.random(in: 30...40),
                origin: origin,
                maxDistance: 280,
                colors: [
                    Color(red: 1.0, green: 0.68, blue: 0.74),  // 桜ピンク
                    Color(red: 1.0, green: 0.55, blue: 0.65),  // ローズピンク
                    Color(red: 0.96, green: 0.72, blue: 0.78), // 淡いピンク
                    Color(red: 1.0, green: 0.60, blue: 0.70),  // サーモンピンク
                    Color(red: 0.95, green: 0.65, blue: 0.75), // モーブピンク
                ],
                sizeRange: 14...22
            )
        case .normal:
            spawnFireworkPetals(
                count: Int.random(in: 15...20),
                origin: origin,
                maxDistance: 180,
                colors: [
                    Color(red: 0.72, green: 0.78, blue: 1.0),  // 淡いブルー
                    Color(red: 0.82, green: 0.76, blue: 1.0),  // ラベンダー
                    Color(red: 0.90, green: 0.90, blue: 0.96), // ほぼ白
                    Color(red: 0.78, green: 0.82, blue: 0.98), // ペールブルー
                ],
                sizeRange: 10...16
            )
        case .bad:
            break // 花びらなし
        }
        }
    }

    /// 花火型に花びらを放射状に一斉生成
    private func spawnFireworkPetals(
        count: Int,
        origin: CGPoint,
        maxDistance: CGFloat,
        colors: [Color],
        sizeRange: ClosedRange<CGFloat>
    ) {
        for i in 0..<count {
            // 微小な遅延でばらつき（0.01秒刻み、全体で約0.3秒以内にすべて出る）
            let delay = Double(i) * 0.01
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                // 上方向を中心に放射状（-140°〜-40°、真上が-90°）
                let angleRange: ClosedRange<CGFloat> = (-150)...(  -30)
                let angleDeg = CGFloat.random(in: angleRange)
                let angleRad = angleDeg * .pi / 180

                let petal = PetalParticle(
                    angle: angleRad,
                    distance: CGFloat.random(in: (maxDistance * 0.5)...maxDistance),
                    size: CGFloat.random(in: sizeRange),
                    color: colors.randomElement() ?? colors[0],
                    duration: Double.random(in: 1.5...2.0),
                    initialRotation: Double.random(in: 0...360),
                    rotationAmount: Double.random(in: 200...600) * (Bool.random() ? 1 : -1),
                    swayAmount: CGFloat.random(in: 8...20),
                    origin: origin
                )
                petals.append(petal)
            }
        }
    }

    /// 定型文ボタンタップ時
    private func quickPhraseTapped(_ phrase: String) {
        withAnimation(.easeOut(duration: 0.2)) {
            tappedPhrase = phrase
        }

        // 疲れた系かどうかで体調を判定
        let tiredKeywords = ["疲れ", "だるい", "しんどい", "つらい"]
        let isTired = tiredKeywords.contains { phrase.contains($0) }
        let mood: MoodType = isTired ? .normal : .good

        // データ保存
        let record = TapRecord(mood: mood, memo: phrase)
        modelContext.insert(record)
        NotificationManager.shared.cancelTodayReminderIfTapped(modelContext: modelContext)

        // 毎日の確認メール送信（設定ONかつ連絡先登録済みの場合）
        sendDailyNotifyMailIfNeeded(mood: mood, memo: phrase)

        // 花びらアニメーション（設定ONかつ対応する体調の場合のみ）
        if animationEnabled {
            // 定型文ボタンには座標が取れないので画面中央付近を出発点にする
            let screenWidth = UIScreen.main.bounds.width
            let origin = CGPoint(x: screenWidth / 2, y: UIScreen.main.bounds.height * 0.55)

            if isTired {
                // 疲れた系：控えめなブルー系
                spawnFireworkPetals(
                    count: Int.random(in: 15...20),
                    origin: origin,
                    maxDistance: 180,
                    colors: [
                        Color(red: 0.72, green: 0.78, blue: 1.0),
                        Color(red: 0.82, green: 0.76, blue: 1.0),
                        Color(red: 0.90, green: 0.90, blue: 0.96),
                    ],
                    sizeRange: 10...16
                )
            } else {
                // 元気系：華やかなピンク系
                spawnFireworkPetals(
                    count: Int.random(in: 30...40),
                    origin: origin,
                    maxDistance: 280,
                    colors: [
                        Color(red: 1.0, green: 0.68, blue: 0.74),
                        Color(red: 1.0, green: 0.55, blue: 0.65),
                        Color(red: 0.96, green: 0.72, blue: 0.78),
                    ],
                    sizeRange: 14...22
                )
            }
        }

        // 3秒後にボタンの色を戻す
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            withAnimation { tappedPhrase = nil }
        }
    }

    // MARK: - SOS関連アクション

    /// 緊急連絡先が登録済みかどうか（名前・メール・電話番号すべて必要）
    private var isContactRegistered: Bool {
        !contactName.trimmingCharacters(in: .whitespaces).isEmpty &&
        !contactEmail.trimmingCharacters(in: .whitespaces).isEmpty &&
        !contactPhone.trimmingCharacters(in: .whitespaces).isEmpty
    }

    /// 通知に使う表示名（本人名 or 「ご利用者」）
    private var displayUserName: String {
        let name = userName.trimmingCharacters(in: .whitespaces)
        return name.isEmpty ? "ご利用者" : name
    }

    /// SOSボタンのワンタップ処理
    private func handleSOSTap() {
        // 初回は注意表示
        if !hasSeenSOSWarning {
            showSOSWarning = true
            return
        }
        // 連絡先未登録チェック
        guard isContactRegistered else {
            showNoContactAlert = true
            return
        }
        // 確認ダイアログを表示
        showSOSConfirmDialog = true
    }

    /// SOS処理: 電話発信 + メール送信
    /// call119: trueなら119番、falseなら緊急連絡先に電話
    private func sendEmergencyAction(call119: Bool) {
        guard isContactRegistered else {
            showNoContactAlert = true
            return
        }

        // メール内容を準備
        if call119 {
            sosMailSubject = "【緊急】\(displayUserName)さんがSOSボタンを押しました（119番通報済み）"
            sosMailBody = """
            【緊急連絡】

            \(displayUserName)さんがみまもりタップのSOSボタンを押し、119番に通報しました。
            至急確認してください。

            送信日時：\(Date().formatted(date: .long, time: .shortened))

            ※このメールはみまもりタップから自動送信されています。
            """
        } else {
            sosMailSubject = "【緊急】\(displayUserName)さんがSOSボタンを押しました"
            sosMailBody = """
            【緊急連絡】

            \(displayUserName)さんがみまもりタップのSOSボタンを押しました。
            至急確認してください。

            送信日時：\(Date().formatted(date: .long, time: .shortened))

            ※このメールはみまもりタップから自動送信されています。
            """
        }

        // 電話発信（ワンタップ: 緊急連絡先、長押し: 119番）
        let phoneNumber = call119 ? "119" : contactPhone.replacingOccurrences(of: "-", with: "")
        if !phoneNumber.isEmpty, let url = URL(string: "tel://\(phoneNumber)") {
            UIApplication.shared.open(url)
        }

        // 電話発信後にメール送信画面を表示
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            if MFMailComposeViewController.canSendMail() {
                showSOSMailComposer = true
            } else {
                withAnimation { sosMessage = "緊急連絡先に電話しました" }
                DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                    withAnimation { sosMessage = "" }
                }
            }
        }
    }

    // MARK: - 毎日の確認メール送信

    /// 体調タップ時に家族へメール通知（設定ONの場合のみ）
    private func sendDailyNotifyMailIfNeeded(mood: MoodType, memo: String?) {
        guard dailyTapNotifyEnabled, isContactRegistered else { return }
        guard MFMailComposeViewController.canSendMail() else { return }

        let now = Date()
        let dateStr = now.formatted(.dateTime.month().day())
        let timeStr = now.formatted(date: .omitted, time: .shortened)

        dailyMailSubject = "【みまもりタップ】\(displayUserName)さんの安否確認"

        var body = "\(displayUserName)さんが\(dateStr) \(timeStr)に安否確認しました。\n\n今日の体調：\(mood.label)"
        if let memo, !memo.isEmpty {
            body += "\nひとこと：\(memo)"
        }
        body += "\n\n※このメールはみまもりタップから自動送信されています。"

        dailyMailBody = body
        showDailyMailComposer = true
    }

    // MARK: - カウントダウンタイマー

    private func startCountdownTimer() {
        updateRemainingTime()
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { _ in
            updateRemainingTime()
        }
    }

    private func updateRemainingTime() {
        let now = Date()
        let calendar = Calendar.current
        guard let endOfDay = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: now) else {
            remainingTime = "--"
            return
        }
        let diff = calendar.dateComponents([.hour, .minute], from: now, to: endOfDay)
        let hours = diff.hour ?? 0
        let minutes = diff.minute ?? 0
        remainingTime = hours > 0 ? "\(hours)時間\(minutes)分" : "\(minutes)分"
    }
}

// MARK: - 花火型花びらアニメーションビュー

/// 花びら1枚がボタン付近から花火のように放射状に舞い上がるビュー
/// TimelineViewで毎フレーム位置・回転・透明度を再計算する
struct PetalFireworkView: View {
    let petal: PetalParticle
    let screenSize: CGSize
    let onComplete: () -> Void

    @State private var startTime: Date?
    @State private var hasCompleted = false

    var body: some View {
        TimelineView(.animation(paused: hasCompleted)) { timeline in
            let progress = currentProgress(at: timeline.date)

            SakuraPetalShape()
                .fill(petal.color)
                .frame(width: petal.size, height: petal.size * 0.6)
                .rotationEffect(.degrees(
                    petal.initialRotation + petal.rotationAmount * progress
                ))
                .position(currentPosition(progress))
                .opacity(currentOpacity(progress))
        }
        .onAppear {
            startTime = .now
            // アニメーション完了後にメモリ解放
            DispatchQueue.main.asyncAfter(deadline: .now() + petal.duration + 0.1) {
                guard !hasCompleted else { return }
                hasCompleted = true
                onComplete()
            }
        }
    }

    /// 進行度を算出（easeOutカーブ: 最初ふわっと勢い→だんだんゆっくり）
    private func currentProgress(at date: Date) -> CGFloat {
        guard let startTime else { return 0 }
        let elapsed = date.timeIntervalSince(startTime)
        let linear = min(max(elapsed / petal.duration, 0), 1)
        // 強めのeaseOut（指数2.8）で花火的な動き
        return 1.0 - pow(1.0 - linear, 2.8)
    }

    /// 現在位置（花火の放射軌道 + 微細なゆらゆら）
    private func currentPosition(_ progress: CGFloat) -> CGPoint {
        // 出発点から放射方向にdistance分だけ移動
        let dist = petal.distance * progress
        let baseX = petal.origin.x + cos(petal.angle) * dist
        let baseY = petal.origin.y + sin(petal.angle) * dist

        // 頂点付近で外側に広がる（progress²で後半に加速）
        let spreadFactor = progress * progress
        let spreadX = cos(petal.angle) * petal.distance * 0.3 * spreadFactor
        let spreadY = sin(petal.angle) * petal.distance * 0.15 * spreadFactor

        // sin波でゆらゆら揺れる
        let sway = sin(progress * .pi * 2.5) * petal.swayAmount
        // ゆらゆらは放射方向に垂直な方向に適用
        let perpX = -sin(petal.angle) * sway
        let perpY = cos(petal.angle) * sway

        return CGPoint(
            x: baseX + spreadX + perpX,
            y: baseY + spreadY + perpY
        )
    }

    /// 不透明度（前半しっかり表示、後半でふわっとフェードアウト）
    private func currentOpacity(_ progress: CGFloat) -> Double {
        if progress < 0.55 {
            // 前半55%はしっかり表示
            return 0.9
        } else {
            // 残り45%でフェードアウト
            let fade = (progress - 0.55) / 0.45
            return 0.9 * (1.0 - fade)
        }
    }
}

#Preview {
    HomeView()
        .modelContainer(for: TapRecord.self, inMemory: true)
        .environmentObject(NotificationManager.shared)
}
