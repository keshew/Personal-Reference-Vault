import Foundation

enum TideGame: String, CaseIterable, Hashable, Identifiable, Codable {
    case four, reversi, picross, sudoku, words, flood, routes, pegs

    enum Group: String, CaseIterable {
        case puzzles = "Puzzles"
        case versus = "Vs. Computer"
        case words = "Word play"
    }

    var id: String { rawValue }

    private var details: (String, Group, String, String, String) {
        switch self {
        case .four:
            ("Four Across", .versus, "circle.grid.3x3.fill", "Line up four discs", "Drop a disc into a column. Four in a row in any direction wins. You play cobalt; the computer plays coral.")
        case .reversi:
            ("Reversi", .versus, "circle.lefthalf.filled", "Flip the board", "Trap the computer’s discs between yours to flip them. Play a highlighted tile. The side with the most discs wins.")
        case .picross:
            ("Picture Grid", .puzzles, "square.grid.3x3.fill", "Uncover a hidden picture", "Fill squares to match the number clues. Each number marks a run of filled squares. Leave at least one empty square between runs.")
        case .sudoku:
            ("Harbor Sudoku", .puzzles, "number.square", "Solve a compact 6 × 6", "Fill each row, column and outlined box with 1 through 6. Use the keypad to enter your answer.")
        case .words:
            ("Word Dock", .words, "character", "Unscramble five words", "Read the clue and arrange the letters. Score one point per answer. You can clear your guess or skip a word.")
        case .flood:
            ("Color Lagoon", .puzzles, "drop.fill", "Flood the whole board", "Choose a color to expand the region in the upper-left corner. Make every tile the same color within 16 moves.")
        case .routes:
            ("Buoy Routes", .puzzles, "point.topleft.down.to.point.bottomright.curvepath", "Join the matching buoys", "Tap a numbered buoy, then tap adjacent tiles to draw a route to its matching buoy. Fill the board without crossing routes. Tap a starting buoy to redraw.")
        case .pegs:
            ("Peg Jump", .puzzles, "circle.dotted", "Jump down to one peg", "Jump over an adjacent peg into an empty space, horizontally or vertically. The peg you jump is removed. Leave as few pegs as possible.")
        }
    }

    var title: String { details.0 }
    var group: Group { details.1 }
    var symbol: String { details.2 }
    var subtitle: String { details.3 }
    var instructions: String { details.4 }

    var prefersLower: Bool {
        switch self {
        case .flood, .pegs: true
        default: false
        }
    }

    func format(_ value: Int) -> String {
        switch self {
        case .four: "\(value) discs played"
        case .reversi: "\(value) discs"
        case .picross: "\(value) squares"
        case .sudoku: "\(value) clean entries"
        case .words: "\(value) / 5 words"
        case .flood: "\(value) moves"
        case .routes: "\(value) routes"
        case .pegs: "\(value) \(value == 1 ? "peg" : "pegs") left"
        }
    }
}

struct TideResult {
    let title: String
    let detail: String
    var score: Int?
    var won = false
}

struct TideJournal: Codable {
    static let storageKey = "referenceVault.tide.journal"

    struct Totals: Codable {
        var played = 0
        var wins = 0
        var best: Int?
    }

    struct Entry: Codable, Identifiable {
        let id: UUID
        let game: TideGame
        let date: Date
        let title: String
        let score: Int?
    }

    private(set) var totals: [String: Totals] = [:]
    private(set) var entries: [Entry] = []

    var played: Int { totals.values.reduce(0) { $0 + $1.played } }
    var wins: Int { totals.values.reduce(0) { $0 + $1.wins } }

    subscript(game: TideGame) -> Totals {
        totals[game.rawValue] ?? Totals()
    }

    mutating func add(_ result: TideResult, game: TideGame, at date: Date = Date()) {
        var stat = self[game]
        stat.played += 1
        if result.won { stat.wins += 1 }
        if let score = result.score,
           stat.best.map({ game.prefersLower ? score < $0 : score > $0 }) ?? true {
            stat.best = score
        }
        totals[game.rawValue] = stat
        entries.insert(Entry(id: UUID(), game: game, date: date, title: result.title, score: result.score), at: 0)
        if entries.count > 30 { entries.removeLast(entries.count - 30) }
    }

    init(data: Data = Data()) {
        if let saved = try? JSONDecoder().decode(Self.self, from: data) {
            self = saved
        }
    }

    var data: Data {
        (try? JSONEncoder().encode(self)) ?? Data()
    }
}

struct TideGrid {
    let rows: Int
    let columns: Int

    var indices: Range<Int> { 0..<(rows * columns) }

    func move(from index: Int, row: Int, column: Int) -> Int? {
        let r = index / columns + row
        let c = index % columns + column
        guard (0..<rows).contains(r), (0..<columns).contains(c) else { return nil }
        return r * columns + c
    }

    func neighbors(_ index: Int) -> [Int] {
        [(-1, 0), (1, 0), (0, -1), (0, 1)].compactMap { move(from: index, row: $0.0, column: $0.1) }
    }
}

enum TideDisc: Int, CaseIterable { case player = 1, computer = 2
    var other: Self { self == .player ? .computer : .player }
}

struct FourAcrossBoard {
    static let grid = TideGrid(rows: 6, columns: 7)
    private(set) var tiles = Array<TideDisc?>(repeating: nil, count: 42)

    var columns: [Int] { (0..<7).filter { tiles[$0] == nil } }
    var discCount: Int { tiles.compactMap { $0 }.count }

    @discardableResult
    mutating func drop(_ disc: TideDisc, column: Int) -> Int? {
        guard columns.contains(column),
              let row = (0..<6).reversed().first(where: { tiles[$0 * 7 + column] == nil }) else { return nil }
        let index = row * 7 + column
        tiles[index] = disc
        return index
    }

    func line(at index: Int) -> Set<Int> {
        guard let disc = tiles[index] else { return [] }
        for (row, column) in [(0, 1), (1, 0), (1, 1), (1, -1)] {
            var matches = [index]
            for direction in [-1, 1] {
                var current = index
                while let next = Self.grid.move(from: current, row: row * direction, column: column * direction),
                      tiles[next] == disc {
                    matches.append(next)
                    current = next
                }
            }
            if matches.count >= 4 { return Set(matches) }
        }
        return []
    }

    func opponentColumn() -> Int? {
        let ordered = [3, 2, 4, 1, 5, 0, 6].filter(columns.contains)
        for disc in [TideDisc.computer, .player] {
            if let urgent = ordered.first(where: { column in
                var copy = self
                guard let spot = copy.drop(disc, column: column) else { return false }
                return !copy.line(at: spot).isEmpty
            }) { return urgent }
        }
        return ordered.prefix(4).randomElement()
    }
}

struct ReversiBoard {
    static let grid = TideGrid(rows: 6, columns: 6)
    private(set) var tiles: [TideDisc?] = {
        var values = Array<TideDisc?>(repeating: nil, count: 36)
        values[14] = .computer
        values[15] = .player
        values[20] = .player
        values[21] = .computer
        return values
    }()

    func count(_ disc: TideDisc) -> Int { tiles.filter { $0 == disc }.count }

    func flips(at index: Int, for disc: TideDisc) -> [Int] {
        guard Self.grid.indices.contains(index), tiles[index] == nil else { return [] }
        var flips: [Int] = []
        for row in -1...1 {
            for column in -1...1 where row != 0 || column != 0 {
                var chain: [Int] = []
                var position = index
                while let next = Self.grid.move(from: position, row: row, column: column) {
                    guard let match = tiles[next] else { break }
                    if match == disc {
                        flips += chain
                        break
                    }
                    chain.append(next)
                    position = next
                }
            }
        }
        return flips
    }

    func legal(_ disc: TideDisc) -> [Int] {
        tiles.indices.filter { !flips(at: $0, for: disc).isEmpty }
    }

    @discardableResult
    mutating func place(_ disc: TideDisc, at index: Int) -> Bool {
        let captured = flips(at: index, for: disc)
        guard !captured.isEmpty else { return false }
        for spot in captured { tiles[spot] = disc }
        tiles[index] = disc
        return true
    }

    func opponentMove() -> Int? {
        let corners = [0, 5, 30, 35]
        return legal(.computer).max { a, b in
            func value(_ index: Int) -> Int {
                flips(at: index, for: .computer).count + (corners.contains(index) ? 20 : 0)
            }
            return value(a) < value(b)
        }
    }
}
