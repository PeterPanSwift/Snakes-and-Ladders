import Foundation
import Testing
@testable import MyApp

@MainActor
struct MyAppTests {
    @Test("一般移動會前進正確格數")
    func normalMove() {
        #expect(GameModel.resolvedDestination(from: 1, roll: 4) == 5)
    }

    @Test("所有梯子都會到達指定出口", arguments: [
        (3, 17),
        (9, 28),
        (20, 38),
        (32, 51),
        (45, 61)
    ])
    func ladders(start: Int, end: Int) {
        #expect(GameModel.resolvedDestination(from: start - 1, roll: 1) == end)
    }

    @Test("所有小蛇都會滑到指定出口", arguments: [
        (16, 6),
        (30, 12),
        (43, 24),
        (55, 36),
        (63, 47)
    ])
    func snakes(start: Int, end: Int) {
        #expect(GameModel.resolvedDestination(from: start - 1, roll: 1) == end)
    }

    @Test("必須剛好抵達終點")
    func exactFinish() {
        #expect(GameModel.resolvedDestination(from: 60, roll: 4) == 64)
        #expect(GameModel.resolvedDestination(from: 60, roll: 5) == 60)
        #expect(GameModel.resolvedDestination(from: 63, roll: 2) == 63)
    }

    @Test("玩家與電腦完成後會交回玩家回合")
    func turnAlternation() async {
        let defaults = makeDefaults()
        defer { defaults.removePersistentDomain(forName: defaultsSuiteName) }

        let rolls = RollSequence([1, 2])
        let model = GameModel(defaults: defaults) {
            rolls.next()
        }

        await model.playPlayerTurn(reduceMotion: true)

        #expect(model.humanPosition == 1)
        #expect(model.computerPosition == 2)
        #expect(model.turn == .human)
        #expect(model.canPlayerRoll)
    }

    @Test("完成回合後可以還原進度")
    func persistenceRoundTrip() async {
        let defaults = makeDefaults()
        defer { defaults.removePersistentDomain(forName: defaultsSuiteName) }

        let rolls = RollSequence([2, 4])
        let original = GameModel(defaults: defaults) {
            rolls.next()
        }
        await original.playPlayerTurn(reduceMotion: true)

        let restored = GameModel(defaults: defaults, rollProvider: { 1 })

        #expect(restored.snapshot() == original.snapshot())
        #expect(restored.notice == .restored)
    }

    @Test("損壞的保存資料會安全回到新遊戲")
    func corruptedPersistence() {
        let defaults = makeDefaults()
        defer { defaults.removePersistentDomain(forName: defaultsSuiteName) }
        defaults.set(Data("not-json".utf8), forKey: GameModel.storageKey)

        let model = GameModel(defaults: defaults, rollProvider: { 1 })

        #expect(model.humanPosition == 0)
        #expect(model.computerPosition == 0)
        #expect(model.turn == .human)
        #expect(model.notice == .welcome)
    }

    private var defaultsSuiteName: String {
        "MyAppTests.ForestGame"
    }

    private func makeDefaults() -> UserDefaults {
        let defaults = UserDefaults(suiteName: defaultsSuiteName)!
        defaults.removePersistentDomain(forName: defaultsSuiteName)
        return defaults
    }
}

@MainActor
private final class RollSequence {
    private var values: [Int]

    init(_ values: [Int]) {
        self.values = values
    }

    func next() -> Int {
        values.isEmpty ? 1 : values.removeFirst()
    }
}
