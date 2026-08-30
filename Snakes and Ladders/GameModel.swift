import Foundation
import Observation

enum Player: String, Codable, Sendable {
    case human
    case computer
}

enum GameNotice: Equatable, Sendable {
    case welcome
    case restored
    case rolled(Player, Int)
    case climbed(Player)
    case slid(Player)
    case exactRollRequired(Int)
    case winner(Player)
}

struct GameSnapshot: Codable, Equatable, Sendable {
    static let currentVersion = 1

    let version: Int
    var humanPosition: Int
    var computerPosition: Int
    var turn: Player
    var lastRoll: Int?
    var winner: Player?
}

@MainActor
@Observable
final class GameModel {
    static let finalSquare = 64

    static let ladders = [
        3: 17,
        9: 28,
        20: 38,
        32: 51,
        45: 61
    ]

    static let snakes = [
        16: 6,
        30: 12,
        43: 24,
        55: 36,
        63: 47
    ]

    static let storageKey = "forestSnakesAndLadders.game.v1"

    private(set) var humanPosition = 0
    private(set) var computerPosition = 0
    private(set) var turn: Player = .human
    private(set) var lastRoll: Int?
    private(set) var winner: Player?
    private(set) var notice: GameNotice = .welcome
    private(set) var isBusy = false
    private(set) var movementFeedback = 0
    private(set) var specialFeedback = 0
    private(set) var victoryFeedback = 0

    private let defaults: UserDefaults
    private let rollProvider: @MainActor () -> Int
    private var session = UUID()

    init(
        defaults: UserDefaults = .standard,
        rollProvider: @escaping @MainActor () -> Int = { Int.random(in: 1...6) }
    ) {
        self.defaults = defaults
        self.rollProvider = rollProvider
        restore()
    }

    var canPlayerRoll: Bool {
        turn == .human && winner == nil && !isBusy
    }

    static func resolvedDestination(from position: Int, roll: Int) -> Int {
        guard (1...6).contains(roll), position + roll <= finalSquare else {
            return position
        }

        let landedSquare = position + roll
        return ladders[landedSquare] ?? snakes[landedSquare] ?? landedSquare
    }

    func position(for player: Player) -> Int {
        switch player {
        case .human:
            humanPosition
        case .computer:
            computerPosition
        }
    }

    func playPlayerTurn(reduceMotion: Bool) async {
        guard canPlayerRoll else { return }

        let activeSession = session
        await playTurn(for: .human, reduceMotion: reduceMotion, session: activeSession)
        guard activeSession == session, winner == nil else { return }

        turn = .computer
        save()
        isBusy = true
        await pause(seconds: reduceMotion ? 0.15 : 0.8)
        guard activeSession == session else { return }

        await playTurn(for: .computer, reduceMotion: reduceMotion, session: activeSession)
        guard activeSession == session, winner == nil else { return }

        turn = .human
        isBusy = false
        save()
    }

    func resumeComputerTurnIfNeeded(reduceMotion: Bool) async {
        guard turn == .computer, winner == nil, !isBusy else { return }

        let activeSession = session
        isBusy = true
        await pause(seconds: reduceMotion ? 0.15 : 0.8)
        guard activeSession == session else { return }

        await playTurn(for: .computer, reduceMotion: reduceMotion, session: activeSession)
        guard activeSession == session, winner == nil else { return }

        turn = .human
        isBusy = false
        save()
    }

    func reset() {
        session = UUID()
        humanPosition = 0
        computerPosition = 0
        turn = .human
        lastRoll = nil
        winner = nil
        notice = .welcome
        isBusy = false
        save()
    }

    func snapshot() -> GameSnapshot {
        GameSnapshot(
            version: GameSnapshot.currentVersion,
            humanPosition: humanPosition,
            computerPosition: computerPosition,
            turn: turn,
            lastRoll: lastRoll,
            winner: winner
        )
    }

    private func playTurn(for player: Player, reduceMotion: Bool, session activeSession: UUID) async {
        isBusy = true

        let roll = min(max(rollProvider(), 1), 6)
        lastRoll = roll
        notice = .rolled(player, roll)

        let start = position(for: player)
        guard start + roll <= Self.finalSquare else {
            notice = .exactRollRequired(Self.finalSquare - start)
            movementFeedback += 1
            await pause(seconds: reduceMotion ? 0.1 : 0.45)
            guard activeSession == session else { return }
            isBusy = false
            save()
            return
        }

        if reduceMotion {
            setPosition(start + roll, for: player)
            movementFeedback += 1
        } else {
            for square in (start + 1)...(start + roll) {
                guard activeSession == session else { return }
                setPosition(square, for: player)
                movementFeedback += 1
                await pause(seconds: 0.12)
            }
        }

        guard activeSession == session else { return }
        let landedSquare = position(for: player)

        if let destination = Self.ladders[landedSquare] {
            await pause(seconds: reduceMotion ? 0.05 : 0.18)
            guard activeSession == session else { return }
            setPosition(destination, for: player)
            notice = .climbed(player)
            specialFeedback += 1
            await pause(seconds: reduceMotion ? 0.05 : 0.35)
        } else if let destination = Self.snakes[landedSquare] {
            await pause(seconds: reduceMotion ? 0.05 : 0.18)
            guard activeSession == session else { return }
            setPosition(destination, for: player)
            notice = .slid(player)
            specialFeedback += 1
            await pause(seconds: reduceMotion ? 0.05 : 0.35)
        }

        guard activeSession == session else { return }

        if position(for: player) == Self.finalSquare {
            winner = player
            notice = .winner(player)
            victoryFeedback += 1
        }

        isBusy = false
        save()
    }

    private func setPosition(_ position: Int, for player: Player) {
        switch player {
        case .human:
            humanPosition = position
        case .computer:
            computerPosition = position
        }
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(snapshot()) else { return }
        defaults.set(data, forKey: Self.storageKey)
    }

    private func restore() {
        guard
            let data = defaults.data(forKey: Self.storageKey),
            let saved = try? JSONDecoder().decode(GameSnapshot.self, from: data),
            saved.version == GameSnapshot.currentVersion,
            (0...Self.finalSquare).contains(saved.humanPosition),
            (0...Self.finalSquare).contains(saved.computerPosition)
        else {
            return
        }

        humanPosition = saved.humanPosition
        computerPosition = saved.computerPosition
        turn = saved.turn
        lastRoll = saved.lastRoll
        winner = saved.winner
        notice = saved.winner.map(GameNotice.winner) ?? .restored
    }

    private func pause(seconds: Double) async {
        try? await Task.sleep(for: .seconds(seconds))
    }
}
