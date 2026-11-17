import SwiftUI

struct TideMatchView: View {
    let game: TideGame
    let best: Int?
    let onFinish: (TideResult) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var isPlaying = false
    @State private var result: TideResult?
    @State private var roundID = UUID()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 19) {
                Button { dismiss() } label: {
                    Label("Back", systemImage: "arrow.left")
                        .font(.subheadline.weight(.semibold))
                        .frame(minHeight: 44)
                }
                .buttonStyle(.plain)
                .foregroundStyle(TidePaint.cobalt)
                .accessibilityIdentifier("tide.back")

                VStack(alignment: .leading, spacing: 5) {
                    Text(game.title)
                        .font(.system(.largeTitle, design: .rounded).weight(.heavy))
                        .accessibilityAddTraits(.isHeader)
                    Text(game.subtitle)
                        .font(.subheadline)
                        .foregroundStyle(TidePaint.secondary)
                }

                if let result {
                    endCard(result)
                } else if isPlaying {
                    board.id(roundID)
                } else {
                    rules
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .frame(maxWidth: 540)
            .frame(maxWidth: .infinity, alignment: .top)
        }
        .background(TidePaint.canvas.ignoresSafeArea())
        .foregroundStyle(TidePaint.ink)
        .toolbar(.hidden, for: .navigationBar)
    }

    private var rules: some View {
        VStack(alignment: .leading, spacing: 16) {
            Image(systemName: game.symbol)
                .font(.system(size: 32, weight: .semibold))
                .foregroundStyle(TidePaint.cobalt)
                .frame(width: 67, height: 67)
                .background(TidePaint.swatch(game), in: RoundedRectangle(cornerRadius: 19))
                .accessibilityHidden(true)
            Text(game.instructions).foregroundStyle(TidePaint.secondary)
            if let best {
                Text("Best · " + game.format(best))
                    .font(.subheadline.weight(.semibold))
            }
            TideAction(title: "Start game", icon: "play.fill") { start() }
                .accessibilityIdentifier("tide.start")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .tideBoard()
    }

    @ViewBuilder private var board: some View {
        switch game {
        case .four: FourAcrossMatch(finish: finish)
        case .reversi: ReversiMatch(finish: finish)
        case .picross: PictureGridMatch(finish: finish)
        case .sudoku: SudokuMatch(finish: finish)
        case .words: WordDockMatch(finish: finish)
        case .flood: LagoonMatch(finish: finish)
        case .routes: BuoyRoutesMatch(finish: finish)
        case .pegs: PegJumpMatch(finish: finish)
        }
    }

    private func endCard(_ result: TideResult) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Image(systemName: result.won ? "checkmark.seal.fill" : "flag.checkered")
                .font(.largeTitle.weight(.semibold))
                .foregroundStyle(TidePaint.cobalt)
                .accessibilityHidden(true)
            Text(result.title)
                .font(.system(.title, design: .rounded).weight(.heavy))
                .accessibilityIdentifier("tide.result")
            Text(result.detail)
                .foregroundStyle(TidePaint.secondary)
            if let score = result.score {
                Text(game.format(score))
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(TidePaint.cobalt)
            }
            TideAction(title: "Play again", icon: "arrow.clockwise") { start() }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .tideBoard()
    }

    private func start() {
        result = nil
        roundID = UUID()
        isPlaying = true
    }

    private func finish(_ outcome: TideResult) {
        guard isPlaying, result == nil else { return }
        onFinish(outcome)
        result = outcome
        isPlaying = false
    }
}

extension View {
    func tideBoard(padding: CGFloat = 15) -> some View {
        self.padding(padding)
            .background(TidePaint.paper, in: RoundedRectangle(cornerRadius: 21))
            .overlay { RoundedRectangle(cornerRadius: 21).strokeBorder(TidePaint.line).allowsHitTesting(false) }
    }
}

struct TideBoardGrid<Cell: View>: View {
    let columns: Int
    let count: Int
    var spacing: CGFloat
    let cell: (Int) -> Cell

    init(columns: Int, count: Int, spacing: CGFloat = 5, @ViewBuilder cell: @escaping (Int) -> Cell) {
        self.columns = columns
        self.count = count
        self.spacing = spacing
        self.cell = cell
    }

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(minimum: 0), spacing: spacing), count: columns), spacing: spacing) {
            ForEach(0..<count, id: \.self, content: cell)
        }
    }
}

struct TideMetric: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label).font(.subheadline.weight(.semibold)).foregroundStyle(TidePaint.secondary)
            Spacer(minLength: 8)
            Text(value).font(.headline.monospacedDigit()).foregroundStyle(TidePaint.ink)
        }
    }
}

struct TideSquare: View {
    var text = ""
    var icon: String?
    var fill = TidePaint.canvas
    var ink = TidePaint.ink
    var radius: CGFloat = 8

    var body: some View {
        RoundedRectangle(cornerRadius: radius)
            .fill(fill)
            .overlay {
                if let icon {
                    Image(systemName: icon).font(.headline).foregroundStyle(ink)
                } else {
                    Text(text)
                        .font(.system(.headline, design: .rounded).weight(.heavy))
                        .minimumScaleFactor(0.45)
                        .lineLimit(1)
                        .foregroundStyle(ink)
                }
            }
            .aspectRatio(1, contentMode: .fit)
    }
}

struct FourAcrossMatch: View {
    let finish: (TideResult) -> Void
    @State private var board = FourAcrossBoard()
    @State private var thinking = false

    var body: some View {
        VStack(spacing: 12) {
            TideMetric(label: "Turn", value: thinking ? "Computer" : "You")
            TideBoardGrid(columns: 7, count: 42, spacing: 4) { index in
                let disc = board.tiles[index]
                Button {
                    play(index % 7)
                } label: {
                    Circle()
                        .fill(disc == .player ? TidePaint.cobalt : disc == .computer ? TidePaint.coral : TidePaint.paper)
                        .overlay { Circle().strokeBorder(TidePaint.ink.opacity(0.12)) }
                        .overlay {
                            if disc == .player {
                                Image(systemName: "circle.fill")
                                    .font(.system(size: 10)).foregroundStyle(.white)
                            } else if disc == .computer {
                                Image(systemName: "minus").font(.system(size: 12, weight: .black)).foregroundStyle(TidePaint.ink)
                            }
                        }
                        .aspectRatio(1, contentMode: .fit)
                }
                .buttonStyle(.plain)
                .disabled(thinking || disc != nil)
                .accessibilityLabel("Row \(index / 7 + 1), column \(index % 7 + 1), \(disc == .player ? "your disc" : disc == .computer ? "computer disc" : "empty")")
            }
            .padding(9)
            .background(TidePaint.sea, in: RoundedRectangle(cornerRadius: 12))
            Text("Tap an empty space in a column to drop your disc.")
                .font(.caption)
                .foregroundStyle(TidePaint.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .tideBoard()
        .task(id: thinking) {
            guard thinking else { return }
            do {
                try await Task.sleep(for: .milliseconds(390))
                try Task.checkCancellation()
                if let column = board.opponentColumn(),
                   let placed = board.drop(.computer, column: column), outcome(at: placed, disc: .computer) { return }
                thinking = false
            } catch { }
        }
    }

    private func play(_ column: Int) {
        guard !thinking, let index = board.drop(.player, column: column) else { return }
        if !outcome(at: index, disc: .player) { thinking = true }
    }

    private func outcome(at index: Int, disc: TideDisc) -> Bool {
        if !board.line(at: index).isEmpty {
            let won = disc == .player
            finish(TideResult(title: won ? "Four across" : "Computer wins",
                              detail: won ? "You lined up four discs." : "The computer lined up four discs.",
                              won: won))
            return true
        }
        if board.columns.isEmpty {
            finish(TideResult(title: "Draw", detail: "There are no free spaces."))
            return true
        }
        return false
    }
}

struct ReversiMatch: View {
    let finish: (TideResult) -> Void
    @State private var board = ReversiBoard()
    @State private var thinking = false
    @State private var passed = false

    var body: some View {
        let legal = Set(board.legal(.player))
        VStack(spacing: 12) {
            TideMetric(label: "You / Computer", value: "\(board.count(.player)) / \(board.count(.computer))")
            Text(thinking ? (passed ? "No legal move. Computer plays again." : "Computer’s turn") : "Tap a highlighted square")
                .font(.subheadline)
                .foregroundStyle(TidePaint.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            TideBoardGrid(columns: 6, count: 36, spacing: 4) { index in
                let disc = board.tiles[index]
                Button {
                    play(index)
                } label: {
                    RoundedRectangle(cornerRadius: 6).fill(TidePaint.sea)
                        .overlay {
                            if let disc {
                                Circle().fill(disc == .player ? TidePaint.cobalt : TidePaint.coral)
                                    .overlay {
                                        Image(systemName: disc == .player ? "circle.fill" : "minus")
                                            .font(.system(size: 10, weight: .bold))
                                            .foregroundStyle(disc == .player ? Color.white : TidePaint.ink)
                                    }
                                    .padding(6)
                            } else if !thinking && legal.contains(index) {
                                Circle().strokeBorder(TidePaint.cobalt, lineWidth: 2).frame(width: 16, height: 16)
                            }
                        }
                        .aspectRatio(1, contentMode: .fit)
                }
                .buttonStyle(.plain)
                .disabled(thinking || !legal.contains(index))
                .accessibilityLabel("Row \(index / 6 + 1), column \(index % 6 + 1), \(disc == .player ? "your disc" : disc == .computer ? "computer disc" : legal.contains(index) ? "legal move" : "empty")")
            }
        }
        .tideBoard()
        .task(id: thinking) {
            guard thinking else { return }
            do {
                while thinking {
                    try await Task.sleep(for: .milliseconds(420))
                    try Task.checkCancellation()
                    if let index = board.opponentMove() { board.place(.computer, at: index) }
                    let userCanMove = !board.legal(.player).isEmpty
                    if userCanMove {
                        thinking = false
                        passed = false
                    } else if board.legal(.computer).isEmpty {
                        complete()
                        return
                    } else {
                        passed = true
                    }
                }
            } catch { }
        }
    }

    private func play(_ index: Int) {
        guard !thinking, board.place(.player, at: index) else { return }
        if !board.legal(.computer).isEmpty {
            thinking = true
        } else if board.legal(.player).isEmpty {
            complete()
        }
    }

    private func complete() {
        let user = board.count(.player)
        let opponent = board.count(.computer)
        finish(TideResult(title: user == opponent ? "Draw" : user > opponent ? "You win" : "Computer wins",
                          detail: "\(user) of your discs and \(opponent) of the computer’s.",
                          score: user, won: user > opponent))
    }
}
