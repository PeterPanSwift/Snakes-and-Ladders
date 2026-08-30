import SwiftUI

struct ContentView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var game = GameModel()
    @State private var showsResetConfirmation = false

    var body: some View {
        ZStack {
            ForestBackground()

            ScrollView {
                VStack(spacing: 16) {
                    HeaderView(
                        turn: game.turn,
                        notice: game.notice,
                        isBusy: game.isBusy
                    )

                    PlayerStatusView(
                        humanPosition: game.humanPosition,
                        computerPosition: game.computerPosition,
                        turn: game.turn
                    )

                    GameBoardView(
                        humanPosition: game.humanPosition,
                        computerPosition: game.computerPosition,
                        reduceMotion: reduceMotion
                    )
                    .frame(maxWidth: 620)

                    DiceControls(
                        roll: game.lastRoll,
                        canRoll: game.canPlayerRoll,
                        isBusy: game.isBusy
                    ) {
                        Task {
                            await game.playPlayerTurn(reduceMotion: reduceMotion)
                        }
                    }
                }
                .frame(maxWidth: 680)
                .padding(.horizontal, 16)
                .padding(.vertical, 20)
                .frame(maxWidth: .infinity)
            }

            if let winner = game.winner {
                WinnerCard(winner: winner) {
                    game.reset()
                }
                .transition(.scale.combined(with: .opacity))
                .zIndex(2)
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("重新開始", systemImage: "arrow.counterclockwise") {
                    showsResetConfirmation = true
                }
            }
        }
        .confirmationDialog("要重新開始嗎？", isPresented: $showsResetConfirmation) {
            Button("重新開始", role: .destructive) {
                game.reset()
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("目前進度會被清除。")
        }
        .sensoryFeedback(.impact(flexibility: .soft, intensity: 0.55), trigger: game.movementFeedback)
        .sensoryFeedback(.impact(flexibility: .rigid, intensity: 0.8), trigger: game.specialFeedback)
        .sensoryFeedback(.success, trigger: game.victoryFeedback)
        .animation(reduceMotion ? nil : .bouncy, value: game.winner)
        .task {
            await game.resumeComputerTurnIfNeeded(reduceMotion: reduceMotion)
        }
    }
}

private struct ForestBackground: View {
    var body: some View {
        LinearGradient(
            colors: [
                Color(red: 0.89, green: 0.96, blue: 0.83),
                Color(red: 0.98, green: 0.93, blue: 0.77)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
        .overlay(alignment: .topLeading) {
            Text("🍃")
                .font(.system(size: 74))
                .rotationEffect(.degrees(-18))
                .opacity(0.32)
                .padding()
                .accessibilityHidden(true)
        }
        .overlay(alignment: .bottomTrailing) {
            Text("🌿")
                .font(.system(size: 92))
                .rotationEffect(.degrees(12))
                .opacity(0.3)
                .padding()
                .accessibilityHidden(true)
        }
    }
}

private struct HeaderView: View {
    let turn: Player
    let notice: GameNotice
    let isBusy: Bool

    var body: some View {
        VStack(spacing: 5) {
            Text("森林蛇梯棋")
                .font(.system(.largeTitle, design: .rounded, weight: .heavy))
                .foregroundStyle(Color(red: 0.16, green: 0.36, blue: 0.21))

            Text(statusText)
                .font(.system(.headline, design: .rounded, weight: .semibold))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .contentTransition(.numericText())
        }
        .accessibilityElement(children: .combine)
    }

    private var statusText: String {
        switch notice {
        case .welcome:
            return "小狐狸先走，擲骰子出發吧！"
        case .restored:
            return turn == .human ? "歡迎回來，輪到小狐狸" : "歡迎回來，小熊準備擲骰"
        case let .rolled(player, roll):
            return "\(name(for: player))擲出了 \(roll) 點"
        case let .climbed(player):
            return "\(name(for: player))爬上藤蔓梯子！"
        case let .slid(player):
            return "\(name(for: player))被小蛇送下來了"
        case let .exactRollRequired(required):
            return required == 0 ? "已經抵達終點" : "需要剛好 \(required) 點才能抵達終點"
        case let .winner(player):
            return "\(name(for: player))抵達終點！"
        }
    }

    private func name(for player: Player) -> String {
        player == .human ? "小狐狸" : "小熊"
    }
}

private struct PlayerStatusView: View {
    let humanPosition: Int
    let computerPosition: Int
    let turn: Player

    var body: some View {
        HStack(spacing: 12) {
            StatusCard(
                emoji: "🦊",
                title: "你的小狐狸",
                position: humanPosition,
                isCurrent: turn == .human,
                tint: .orange
            )
            StatusCard(
                emoji: "🐻",
                title: "電腦小熊",
                position: computerPosition,
                isCurrent: turn == .computer,
                tint: .brown
            )
        }
    }
}

private struct StatusCard: View {
    let emoji: String
    let title: String
    let position: Int
    let isCurrent: Bool
    let tint: Color

    var body: some View {
        HStack(spacing: 8) {
            Text(emoji)
                .font(.title2)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                Text(position == 0 ? "準備出發" : "第 \(position) 格")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .padding(11)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(isCurrent ? tint : .clear, lineWidth: 3)
        }
        .accessibilityElement(children: .combine)
        .accessibilityValue(isCurrent ? "目前回合" : "")
    }
}

private struct DiceControls: View {
    let roll: Int?
    let canRoll: Bool
    let isBusy: Bool
    let action: () -> Void

    var body: some View {
        HStack(spacing: 18) {
            DiceFace(value: roll)
                .frame(width: 68, height: 68)
                .rotationEffect(.degrees(isBusy ? 8 : 0))
                .scaleEffect(isBusy ? 0.94 : 1)
                .animation(.snappy.repeatCount(isBusy ? 2 : 0, autoreverses: true), value: isBusy)

            Button(action: action) {
                Label(buttonTitle, systemImage: "dice.fill")
                    .font(.system(.headline, design: .rounded, weight: .bold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color(red: 0.35, green: 0.58, blue: 0.31))
            .disabled(!canRoll)
            .accessibilityHint("擲出一到六點並移動小狐狸")
        }
        .padding(14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var buttonTitle: String {
        if canRoll {
            return "擲骰子"
        }
        return isBusy ? "移動中…" : "等待小熊"
    }
}

private struct DiceFace: View {
    let value: Int?

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 17, style: .continuous)
                .fill(.white)
                .shadow(color: .black.opacity(0.12), radius: 6, y: 3)

            if let value {
                Text(diceSymbol(for: value))
                    .font(.system(size: 43, weight: .bold))
                    .foregroundStyle(Color(red: 0.20, green: 0.39, blue: 0.24))
                    .contentTransition(.numericText())
            } else {
                Image(systemName: "dice")
                    .font(.system(size: 35, weight: .bold))
                    .foregroundStyle(Color(red: 0.35, green: 0.58, blue: 0.31))
            }
        }
        .accessibilityLabel(value.map { "骰子，\($0) 點" } ?? "尚未擲骰")
    }

    private func diceSymbol(for value: Int) -> String {
        ["⚀", "⚁", "⚂", "⚃", "⚄", "⚅"][value - 1]
    }
}

private struct WinnerCard: View {
    let winner: Player
    let newGame: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.28)
                .ignoresSafeArea()

            VStack(spacing: 14) {
                Text(winner == .human ? "🦊🏆" : "🐻🌟")
                    .font(.system(size: 62))
                    .accessibilityHidden(true)

                Text(winner == .human ? "小狐狸獲勝！" : "小熊先到終點")
                    .font(.system(.title, design: .rounded, weight: .heavy))
                    .multilineTextAlignment(.center)

                Text(winner == .human ? "森林裡響起了歡呼聲！" : "再挑戰一次，小狐狸一定可以！")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                Button("再玩一局", systemImage: "arrow.clockwise", action: newGame)
                    .buttonStyle(.borderedProminent)
                    .tint(Color(red: 0.35, green: 0.58, blue: 0.31))
            }
            .padding(28)
            .frame(maxWidth: 330)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
            .padding(24)
        }
        .accessibilityAddTraits(.isModal)
    }
}

#Preview {
    NavigationStack {
        ContentView()
    }
}
