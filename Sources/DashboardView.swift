import SwiftUI

enum AppSection: String, CaseIterable, Identifiable {
    case today
    case coach
    case decide
    case bets
    case git
    case parking
    case evidence
    case icons
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .today: "今天"
        case .coach: "Better Coach"
        case .decide: "我不知道做什么"
        case .bets: "三条押注"
        case .git: "Git 上下文"
        case .parking: "停车场"
        case .evidence: "证据"
        case .icons: "图标实验室"
        case .settings: "提醒与启动"
        }
    }

    var symbol: String {
        switch self {
        case .today: "scope"
        case .coach: "bubble.left.and.sparkles"
        case .decide: "signpost.right.and.left"
        case .bets: "square.stack.3d.up"
        case .git: "point.topleft.down.to.point.bottomright.curvepath"
        case .parking: "tray.full"
        case .evidence: "chart.bar.doc.horizontal"
        case .icons: "app.badge.checkmark"
        case .settings: "gearshape"
        }
    }
}

struct DashboardView: View {
    @ObservedObject var store: AppStore
    @ObservedObject var launchAtLogin: LaunchAtLoginController
    @ObservedObject var iconController: AppIconController
    @State private var selection: AppSection = .today

    var body: some View {
        NavigationSplitView {
            VStack(spacing: 0) {
                HStack(spacing: 11) {
                    BetterLogo(image: iconController.currentImage, size: 44)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("BETTER")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .tracking(1.6)
                            .foregroundStyle(BetterTheme.accent)
                        Text("少做，但做穿")
                            .font(.headline.weight(.semibold))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 14)

                List(AppSection.allCases, selection: $selection) { section in
                    Label(section.title, systemImage: section.symbol)
                        .tag(section)
                }
                .listStyle(.sidebar)

                VStack(alignment: .leading, spacing: 5) {
                    BetterStatusPill(
                        title: "活跃押注 \(store.activeBets.count)/3",
                        symbol: "circle.grid.2x2.fill",
                        color: BetterTheme.blue
                    )
                    Text(store.data.currentFocus == nil ? "今天尚未锁定焦点" : "今天已锁定一件事")
                        .padding(.top, 3)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
            }
            .background(.thinMaterial)
            .navigationSplitViewColumnWidth(min: 205, ideal: 235, max: 270)
        } detail: {
            Group {
                switch selection {
                case .today:
                    TodayView(
                        store: store,
                        onManageBets: { selection = .bets },
                        onOpenCoach: { selection = .coach }
                    )
                case .coach:
                    BetterCoachView(store: store) { selection = .today }
                case .decide:
                    DecisionView(store: store) { selection = .today }
                case .bets:
                    BetsView(store: store)
                case .git:
                    GitContextView(store: store)
                case .parking:
                    ParkingLotView(store: store)
                case .evidence:
                    EvidenceView(store: store)
                case .icons:
                    AppIconLabView(iconController: iconController)
                case .settings:
                    ReminderSettingsView(store: store, launchAtLogin: launchAtLogin)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(BetterTheme.canvas)
        }
        .alert(
            "Better",
            isPresented: Binding(
                get: { store.errorMessage != nil },
                set: { if !$0 { store.clearError() } }
            )
        ) {
            Button("知道了") { store.clearError() }
        } message: {
            Text(store.errorMessage ?? "未知错误")
        }
    }
}

struct PageHeader: View {
    let eyebrow: String
    let title: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(eyebrow.uppercased())
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .tracking(1.3)
                .foregroundStyle(BetterTheme.accent)
            Text(title)
                .font(.system(size: 30, weight: .bold, design: .rounded))
            Text(detail)
                .font(.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct BetterCard<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.regularMaterial)
                    .shadow(color: BetterTheme.indigo.opacity(0.08), radius: 18, y: 6)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [Color.white.opacity(0.18), BetterTheme.indigo.opacity(0.08)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
    }
}

struct EmptyCallout: View {
    let symbol: String
    let title: String
    let detail: String
    let actionTitle: String?
    let action: (() -> Void)?

    init(symbol: String, title: String, detail: String, actionTitle: String? = nil, action: (() -> Void)? = nil) {
        self.symbol = symbol
        self.title = title
        self.detail = detail
        self.actionTitle = actionTitle
        self.action = action
    }

    var body: some View {
        BetterCard {
            VStack(alignment: .leading, spacing: 12) {
                Image(systemName: symbol)
                    .font(.system(size: 28))
                    .foregroundStyle(.tint)
                Text(title).font(.title3.weight(.semibold))
                Text(detail).foregroundStyle(.secondary)
                if let actionTitle, let action {
                    Button(actionTitle, action: action)
                        .buttonStyle(.borderedProminent)
                }
            }
        }
    }
}

extension AppStore {
    func present(_ error: Error) {
        errorMessage = error.localizedDescription
    }
}
