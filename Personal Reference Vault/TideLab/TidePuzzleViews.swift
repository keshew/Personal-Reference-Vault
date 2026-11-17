import SwiftUI

struct PictureGridMatch: View {
    let finish: (TideResult) -> Void
    @State private var puzzle = PicturePuzzle.puzzles.randomElement() ?? PicturePuzzle.puzzles[0]
    @State private var marks: Set<Int> = []
    @State private var crosses: Set<Int> = []
    @State private var markingBlank = false

    var body: some View {
        VStack(spacing: 13) {
            Picker("Marking mode", selection: $markingBlank) {
                Text("Fill").tag(false)
                Text("Cross out").tag(true)
            }
            .pickerStyle(.segmented)

            TideBoardGrid(columns: 6, count: 36, spacing: 3) { index in
                let row = index / 6
                let col = index % 6
                if row == 0 {
                    VStack(spacing: 0) {
                        if col > 0 {
                            ForEach(Array(puzzle.vertical[col - 1].enumerated()), id: \.offset) { clue in
                                Text(String(clue.element))
                            }
                        }
                    }
                    .font(.caption2.monospacedDigit().weight(.bold))
                    .frame(maxWidth: .infinity, minHeight: 30)
                } else if col == 0 {
                    Text(puzzle.horizontal[row - 1].map(String.init).joined(separator: " "))
                        .font(.caption2.monospacedDigit().weight(.bold))
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity)
                } else {
                    let tile = (row - 1) * 5 + col - 1
                    Button { mark(tile) } label: {
                        TideSquare(icon: crosses.contains(tile) ? "xmark" : nil,
                                   fill: marks.contains(tile) ? TidePaint.cobalt : TidePaint.canvas,
                                   ink: TidePaint.secondary, radius: 5)
                            .overlay { RoundedRectangle(cornerRadius: 5).strokeBorder(TidePaint.line) }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Row \(row), column \(col), \(marks.contains(tile) ? "filled" : crosses.contains(tile) ? "crossed out" : "empty")")
                }
            }
            .foregroundStyle(TidePaint.secondary)

            Text("Use the clues along the top and left edges.")
                .font(.caption)
                .foregroundStyle(TidePaint.secondary)
        }
        .tideBoard(padding: 12)
    }

    private func mark(_ index: Int) {
        if markingBlank {
            marks.remove(index)
            crosses.formSymmetricDifference([index])
        } else {
            crosses.remove(index)
            marks.formSymmetricDifference([index])
        }
        if puzzle.matches(marks) {
            finish(TideResult(title: "Picture complete", detail: "You uncovered the \(puzzle.name.lowercased()).",
                              score: puzzle.count, won: true))
        }
    }
}

struct SudokuMatch: View {
    let finish: (TideResult) -> Void
    @State private var puzzle: HarborSudoku
    @State private var values: [Int]
    @State private var chosen: Int?
    @State private var misses = 0

    init(finish: @escaping (TideResult) -> Void) {
        let puzzle = HarborSudoku()
        self.finish = finish
        _puzzle = State(initialValue: puzzle)
        _values = State(initialValue: puzzle.givens)
    }

    var body: some View {
        VStack(spacing: 13) {
            TideMetric(label: "Open cells", value: String(values.filter { $0 == 0 }.count))
            TideBoardGrid(columns: 6, count: 36, spacing: 2) { index in
                let given = puzzle.givens[index] != 0
                let wrong = values[index] != 0 && values[index] != puzzle.solution[index]
                Button {
                    if !given { chosen = index }
                } label: {
                    TideSquare(text: values[index] == 0 ? "" : String(values[index]),
                               fill: chosen == index ? TidePaint.cobalt.opacity(0.16) : given ? TidePaint.sea : TidePaint.canvas,
                               ink: wrong ? TidePaint.coral : given ? TidePaint.ink : TidePaint.cobalt, radius: 1)
                        .overlay(alignment: .trailing) {
                            if index % 6 == 2 {
                                Rectangle().fill(TidePaint.cobalt.opacity(0.40)).frame(width: 2)
                            }
                        }
                        .overlay(alignment: .bottom) {
                            if [1, 3].contains(index / 6) {
                                Rectangle().fill(TidePaint.cobalt.opacity(0.40)).frame(height: 2)
                            }
                        }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Row \(index / 6 + 1), column \(index % 6 + 1), \(values[index] == 0 ? "empty" : String(values[index]))")
                .accessibilityAddTraits(chosen == index ? [.isSelected] : [])
            }

            TideBoardGrid(columns: 6, count: 6) { index in
                Button {
                    enter(index + 1)
                } label: {
                    TideSquare(text: String(index + 1),
                               fill: TidePaint.cobalt.opacity(0.11), ink: TidePaint.cobalt)
                }
                .buttonStyle(.plain)
                .disabled(chosen == nil)
                .accessibilityLabel("Enter \(index + 1)")
            }
            HStack {
                Text(chosen == nil ? "Tap an empty square" : "Choose a number")
                    .font(.caption).foregroundStyle(TidePaint.secondary)
                Spacer()
                Button("Erase", systemImage: "delete.left") { enter(0) }
                    .font(.subheadline.weight(.semibold))
                    .disabled(chosen == nil)
            }
        }
        .tideBoard(padding: 12)
    }

    private func enter(_ number: Int) {
        guard let chosen, puzzle.givens[chosen] == 0, values[chosen] != number else { return }
        values[chosen] = number
        if number != 0 && number != puzzle.solution[chosen] { misses += 1 }
        if values == puzzle.solution {
            let editable = puzzle.givens.filter { $0 == 0 }.count
            finish(TideResult(title: "Sudoku solved", detail: misses == 0 ? "A clean solve." : "\(misses) incorrect entries corrected.",
                              score: max(0, editable - misses), won: true))
        }
    }
}

struct WordDockMatch: View {
    let finish: (TideResult) -> Void
    @State private var deck: [DockWord]
    @State private var letters: [String]
    @State private var selected: [Int] = []
    @State private var step = 0
    @State private var score = 0
    @State private var feedback: String?

    init(finish: @escaping (TideResult) -> Void) {
        let deck = Array(DockWord.deck.shuffled().prefix(5))
        self.finish = finish
        _deck = State(initialValue: deck)
        _letters = State(initialValue: deck[0].letters)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            TideMetric(label: "Word \(step + 1) of \(deck.count)", value: "\(score) correct")
            Text(deck[step].clue)
                .font(.system(.title3, design: .rounded).weight(.heavy))
            TideBoardGrid(columns: letters.count, count: letters.count) { index in
                let filled = selected.indices.contains(index)
                Button {
                    if filled { selected.removeSubrange(index...) }
                    feedback = nil
                } label: {
                    TideSquare(text: filled ? letters[selected[index]] : "",
                               fill: TidePaint.sea)
                }
                .buttonStyle(.plain)
                .disabled(!filled)
                .accessibilityLabel(filled ? "Remove \(letters[selected[index]]) and following letters" : "Empty slot")
            }
            TideBoardGrid(columns: letters.count, count: letters.count) { index in
                let used = selected.contains(index)
                Button {
                    selected.append(index)
                    feedback = nil
                } label: {
                    TideSquare(text: letters[index], fill: used ? TidePaint.canvas : TidePaint.cobalt.opacity(0.11),
                               ink: used ? TidePaint.secondary : TidePaint.cobalt)
                }
                .buttonStyle(.plain)
                .disabled(used)
                .accessibilityLabel("Letter \(letters[index])")
            }
            if let feedback {
                Text(feedback).font(.subheadline).foregroundStyle(TidePaint.coral)
            }
            HStack {
                TideAction(title: "Check", icon: "checkmark") { check() }
                    .disabled(selected.count != letters.count)
                    .opacity(selected.count == letters.count ? 1 : 0.48)
                Spacer()
                Button("Clear") { selected.removeAll(); feedback = nil }
                    .disabled(selected.isEmpty)
                Button("Skip") { next() }
            }
            .font(.subheadline.weight(.semibold))
        }
        .tideBoard()
    }

    private func check() {
        if selected.map({ letters[$0] }).joined() == deck[step].word {
            score += 1
            next()
        } else {
            feedback = "That doesn’t match the clue. Try another order."
        }
    }

    private func next() {
        if step + 1 == deck.count {
            finish(TideResult(title: score == deck.count ? "Perfect round" : "Round complete",
                              detail: "You worked through all five clues.", score: score, won: score == deck.count))
            return
        }
        step += 1
        selected.removeAll()
        feedback = nil
        letters = deck[step].letters
    }
}

struct LagoonMatch: View {
    let finish: (TideResult) -> Void
    @State private var board = LagoonBoard()

    private let paint: [Color] = [TidePaint.cobalt, TidePaint.sea, TidePaint.coral, Color(red: 0.96, green: 0.79, blue: 0.35)]
    private let names = ["Cobalt", "Mint", "Coral", "Gold"]
    private let glyphs = ["circle.fill", "plus", "triangle.fill", "diamond.fill"]

    var body: some View {
        VStack(spacing: 13) {
            TideMetric(label: "Moves left", value: String(LagoonBoard.moveLimit - board.moves))
            TideBoardGrid(columns: 6, count: 36, spacing: 3) { index in
                let color = board.tiles[index]
                TideSquare(icon: glyphs[color], fill: paint[color],
                           ink: color == 0 ? .white : TidePaint.ink, radius: 5)
                    .accessibilityLabel("Row \(index / 6 + 1), column \(index % 6 + 1), \(names[color])")
                    .overlay {
                        if index == 0 {
                            RoundedRectangle(cornerRadius: 5).strokeBorder(TidePaint.ink, lineWidth: 2)
                        }
                    }
            }
            TideMetric(label: "Connected", value: "\(board.regionCount) / 36")
            HStack(spacing: 7) {
                ForEach(paint.indices, id: \.self) { color in
                    Button {
                        flood(color)
                    } label: {
                        Image(systemName: glyphs[color])
                            .font(.headline)
                            .foregroundStyle(color == 0 ? Color.white : TidePaint.ink)
                            .frame(maxWidth: .infinity, minHeight: 46)
                            .background(paint[color], in: RoundedRectangle(cornerRadius: 11))
                    }
                    .buttonStyle(.plain)
                    .disabled(color == board.tiles[0])
                    .accessibilityLabel("Flood \(names[color])")
                }
            }
        }
        .tideBoard()
    }

    private func flood(_ color: Int) {
        board.flood(color)
        if board.complete {
            finish(TideResult(title: "Lagoon cleared", detail: "Every tile is connected.", score: board.moves, won: true))
        } else if board.moves == LagoonBoard.moveLimit {
            finish(TideResult(title: "Out of moves", detail: "You connected \(board.regionCount) of 36 tiles."))
        }
    }
}

struct BuoyRoutesMatch: View {
    let finish: (TideResult) -> Void
    @State private var board = BuoyBoard()

    private let paint = [TidePaint.cobalt, TidePaint.coral, Color(red: 0.08, green: 0.55, blue: 0.40),
                         Color(red: 0.51, green: 0.29, blue: 0.71), Color(red: 0.71, green: 0.43, blue: 0.12)]

    var body: some View {
        VStack(spacing: 13) {
            TideMetric(label: "Linked buoys", value: "\(board.linked) / \(board.endpoints.count)")
            TideBoardGrid(columns: 5, count: 25) { index in
                let buoy = board.buoy(at: index)
                let route = board.route(at: index)
                let tint = (buoy ?? route).map { paint[$0] } ?? TidePaint.line
                Button { tap(index) } label: {
                    TideSquare(text: buoy.map { String($0 + 1) } ?? "",
                               icon: buoy == nil && route != nil ? "circle.fill" : nil,
                               fill: buoy != nil ? tint : route != nil ? tint.opacity(0.22) : TidePaint.canvas,
                               ink: buoy != nil ? .white : tint, radius: 7)
                        .overlay {
                            if let buoy, board.selected == buoy {
                                RoundedRectangle(cornerRadius: 7).strokeBorder(TidePaint.ink, lineWidth: 2)
                            }
                        }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Row \(index / 5 + 1), column \(index % 5 + 1)" + (buoy.map { ", buoy \($0 + 1)" } ?? ""))
            }
            TideMetric(label: "Tiles used", value: "\(board.occupied) / 25")
            Text(board.selected.map { "Draw route \($0 + 1)" } ?? "Select a buoy to draw a route")
                .font(.caption).foregroundStyle(TidePaint.secondary)
        }
        .tideBoard()
    }

    private func tap(_ tile: Int) {
        board.tap(tile)
        if board.complete {
            finish(TideResult(title: "All routes linked", detail: "The buoys are connected and every tile is used.",
                              score: board.linked, won: true))
        }
    }
}

struct PegJumpMatch: View {
    let finish: (TideResult) -> Void
    @State private var board = PegCross()
    @State private var selected: Int?

    var body: some View {
        VStack(spacing: 13) {
            TideMetric(label: "Pegs left", value: String(board.pegs.count))
            TideBoardGrid(columns: 7, count: 49, spacing: 3) { index in
                if PegCross.holes.contains(index) {
                    let occupied = board.pegs.contains(index)
                    let landing = selected.map { board.landings(from: $0).contains(index) } ?? false
                    Button {
                        tap(index)
                    } label: {
                        Circle().fill(selected == index ? TidePaint.cobalt.opacity(0.17) : TidePaint.canvas)
                            .overlay {
                                if occupied {
                                    Circle().fill(selected == index ? TidePaint.coral : TidePaint.cobalt).padding(5)
                                } else if landing {
                                    Circle().fill(TidePaint.coral.opacity(0.47)).padding(9)
                                }
                            }
                            .overlay { Circle().strokeBorder(TidePaint.line) }
                            .aspectRatio(1, contentMode: .fit)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Row \(index / 7 + 1), column \(index % 7 + 1), \(occupied ? "peg" : landing ? "legal landing" : "empty")")
                } else {
                    Color.clear.aspectRatio(1, contentMode: .fit).accessibilityHidden(true)
                }
            }
            Text("Select a peg, then tap a highlighted landing.")
                .font(.caption).foregroundStyle(TidePaint.secondary)
        }
        .tideBoard(padding: 12)
    }

    private func tap(_ index: Int) {
        if board.pegs.contains(index) {
            selected = selected == index ? nil : index
        } else if let selected, board.jump(from: selected, to: index) {
            self.selected = nil
            if !board.canJump {
                let won = board.pegs.count == 1
                finish(TideResult(title: won ? "One peg left" : "No jumps left",
                                  detail: won ? "You solved the cross." : "Try a different opening to leave fewer pegs.",
                                  score: board.pegs.count, won: won))
            }
        }
    }
}
