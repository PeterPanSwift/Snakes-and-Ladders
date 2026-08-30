import SwiftUI

struct GameBoardView: View {
    let humanPosition: Int
    let computerPosition: Int
    let reduceMotion: Bool

    private let columns = Array(
        repeating: GridItem(.flexible(), spacing: 2),
        count: 8
    )

    var body: some View {
        GeometryReader { proxy in
            let boardSize = min(proxy.size.width, proxy.size.height)
            let cellSize = boardSize / 8

            ZStack {
                LazyVGrid(columns: columns, spacing: 2) {
                    ForEach(0..<64, id: \.self) { displayIndex in
                        BoardCell(
                            number: boardNumber(for: displayIndex),
                            isSpecial: isSpecial(boardNumber(for: displayIndex))
                        )
                        .frame(height: cellSize - 2)
                    }
                }

                BoardConnections()
                    .allowsHitTesting(false)

                if humanPosition > 0 {
                    AnimalPiece(emoji: "🦊", color: .orange, name: "小狐狸")
                        .frame(width: cellSize * 0.62, height: cellSize * 0.62)
                        .position(position(for: humanPosition, boardSize: boardSize, offset: -0.11))
                        .animation(reduceMotion ? nil : .snappy(duration: 0.18), value: humanPosition)
                }

                if computerPosition > 0 {
                    AnimalPiece(emoji: "🐻", color: .brown, name: "小熊")
                        .frame(width: cellSize * 0.62, height: cellSize * 0.62)
                        .position(position(for: computerPosition, boardSize: boardSize, offset: 0.11))
                        .animation(reduceMotion ? nil : .snappy(duration: 0.18), value: computerPosition)
                }
            }
            .frame(width: boardSize, height: boardSize)
            .background(Color(red: 0.94, green: 0.91, blue: 0.75))
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(Color.white.opacity(0.9), lineWidth: 4)
            }
            .shadow(color: Color.green.opacity(0.18), radius: 12, y: 7)
            .accessibilityElement(children: .contain)
            .accessibilityLabel("蛇梯棋棋盤，共六十四格")
        }
        .aspectRatio(1, contentMode: .fit)
    }

    private func boardNumber(for displayIndex: Int) -> Int {
        let displayRow = displayIndex / 8
        let column = displayIndex % 8
        let logicalRow = 7 - displayRow
        let positionInRow = logicalRow.isMultiple(of: 2) ? column : 7 - column
        return logicalRow * 8 + positionInRow + 1
    }

    private func isSpecial(_ number: Int) -> Bool {
        GameModel.ladders[number] != nil || GameModel.snakes[number] != nil || number == 64
    }

    private func position(for square: Int, boardSize: CGFloat, offset: CGFloat) -> CGPoint {
        let cellSize = boardSize / 8
        let zeroBased = square - 1
        let logicalRow = zeroBased / 8
        let positionInRow = zeroBased % 8
        let column = logicalRow.isMultiple(of: 2) ? positionInRow : 7 - positionInRow
        let displayRow = 7 - logicalRow

        return CGPoint(
            x: (CGFloat(column) + 0.5 + offset) * cellSize,
            y: (CGFloat(displayRow) + 0.5) * cellSize
        )
    }
}

private struct BoardCell: View {
    let number: Int
    let isSpecial: Bool

    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(cellColor)

            if number == 64 {
                Image(systemName: "flag.checkered")
                    .font(.caption2)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            Text(number, format: .number)
                .font(.system(.caption2, design: .rounded, weight: .bold))
                .foregroundStyle(number == 64 ? .white : Color(red: 0.19, green: 0.34, blue: 0.22))
                .padding(4)
        }
        .accessibilityLabel(accessibilityDescription)
    }

    private var cellColor: Color {
        if number == 64 {
            return Color(red: 0.35, green: 0.58, blue: 0.31)
        }
        if isSpecial {
            return Color(red: 0.98, green: 0.84, blue: 0.52)
        }
        return number.isMultiple(of: 2)
            ? Color(red: 0.84, green: 0.92, blue: 0.72)
            : Color(red: 0.96, green: 0.94, blue: 0.78)
    }

    private var accessibilityDescription: String {
        if let destination = GameModel.ladders[number] {
            return "第 \(number) 格，梯子通往第 \(destination) 格"
        }
        if let destination = GameModel.snakes[number] {
            return "第 \(number) 格，小蛇滑到第 \(destination) 格"
        }
        if number == 64 {
            return "第六十四格，終點"
        }
        return "第 \(number) 格"
    }
}

private struct AnimalPiece: View {
    let emoji: String
    let color: Color
    let name: String

    var body: some View {
        Text(emoji)
            .font(.system(size: 23))
            .minimumScaleFactor(0.5)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(color.opacity(0.94), in: Circle())
            .overlay {
                Circle().stroke(.white, lineWidth: 2)
            }
            .shadow(color: .black.opacity(0.2), radius: 3, y: 2)
            .accessibilityLabel(name)
    }
}

private struct BoardConnections: View {
    var body: some View {
        Canvas { context, size in
            for (start, end) in GameModel.ladders {
                drawLadder(from: point(for: start, size: size), to: point(for: end, size: size), in: &context)
            }

            for (start, end) in GameModel.snakes {
                drawSnake(from: point(for: start, size: size), to: point(for: end, size: size), in: &context)
            }
        }
    }

    private func point(for square: Int, size: CGSize) -> CGPoint {
        let cell = size.width / 8
        let zeroBased = square - 1
        let logicalRow = zeroBased / 8
        let positionInRow = zeroBased % 8
        let column = logicalRow.isMultiple(of: 2) ? positionInRow : 7 - positionInRow
        let displayRow = 7 - logicalRow

        return CGPoint(
            x: (CGFloat(column) + 0.5) * cell,
            y: (CGFloat(displayRow) + 0.5) * cell
        )
    }

    private func drawLadder(from start: CGPoint, to end: CGPoint, in context: inout GraphicsContext) {
        let vector = CGVector(dx: end.x - start.x, dy: end.y - start.y)
        let length = max(hypot(vector.dx, vector.dy), 1)
        let perpendicular = CGVector(dx: -vector.dy / length * 5, dy: vector.dx / length * 5)
        let sideOneStart = CGPoint(x: start.x + perpendicular.dx, y: start.y + perpendicular.dy)
        let sideOneEnd = CGPoint(x: end.x + perpendicular.dx, y: end.y + perpendicular.dy)
        let sideTwoStart = CGPoint(x: start.x - perpendicular.dx, y: start.y - perpendicular.dy)
        let sideTwoEnd = CGPoint(x: end.x - perpendicular.dx, y: end.y - perpendicular.dy)

        var rails = Path()
        rails.move(to: sideOneStart)
        rails.addLine(to: sideOneEnd)
        rails.move(to: sideTwoStart)
        rails.addLine(to: sideTwoEnd)
        context.stroke(rails, with: .color(Color(red: 0.48, green: 0.31, blue: 0.16)), lineWidth: 3)

        for step in 1...4 {
            let fraction = CGFloat(step) / 5
            let center = CGPoint(
                x: start.x + vector.dx * fraction,
                y: start.y + vector.dy * fraction
            )
            var rung = Path()
            rung.move(to: CGPoint(x: center.x + perpendicular.dx, y: center.y + perpendicular.dy))
            rung.addLine(to: CGPoint(x: center.x - perpendicular.dx, y: center.y - perpendicular.dy))
            context.stroke(rung, with: .color(.white.opacity(0.9)), lineWidth: 2)
        }
    }

    private func drawSnake(from start: CGPoint, to end: CGPoint, in context: inout GraphicsContext) {
        let midpoint = CGPoint(x: (start.x + end.x) / 2, y: (start.y + end.y) / 2)
        let bend = max(abs(start.y - end.y) * 0.18, 12)

        var path = Path()
        path.move(to: start)
        path.addCurve(
            to: end,
            control1: CGPoint(x: midpoint.x + bend, y: start.y + (end.y - start.y) * 0.25),
            control2: CGPoint(x: midpoint.x - bend, y: start.y + (end.y - start.y) * 0.75)
        )
        context.stroke(path, with: .color(Color(red: 0.77, green: 0.30, blue: 0.34)), style: StrokeStyle(lineWidth: 7, lineCap: .round))

        let headRect = CGRect(x: start.x - 6, y: start.y - 6, width: 12, height: 12)
        context.fill(Path(ellipseIn: headRect), with: .color(Color(red: 0.91, green: 0.42, blue: 0.43)))
    }
}
