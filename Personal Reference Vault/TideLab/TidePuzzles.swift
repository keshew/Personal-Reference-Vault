import Foundation

struct PicturePuzzle {
    let name: String
    private let pixels: [[Bool]]

    var horizontal: [[Int]] { pixels.map(Self.clue) }
    var vertical: [[Int]] { (0..<5).map { column in Self.clue(pixels.map { $0[column] }) } }
    var count: Int { pixels.flatMap { $0 }.filter { $0 }.count }

    private init(name: String, pattern: [String]) {
        self.name = name
        pixels = pattern.map { $0.map { $0 == "#" } }
    }

    static let puzzles = [
        PicturePuzzle(name: "Lighthouse", pattern: ["..#..", ".###.", "..#..", "..#..", ".###."]),
        PicturePuzzle(name: "Sailboat", pattern: ["..#..", "..##.", "..###", ".....", "#####"]),
        PicturePuzzle(name: "Flipper", pattern: ["##...", "###..", ".###.", "..##.", ".####"]),
        PicturePuzzle(name: "Diamond", pattern: ["..#..", ".###.", "#####", ".###.", "..#.."]),
        PicturePuzzle(name: "Fish", pattern: [".##..", "###.#", "#####", "###.#", ".##.."]),
        PicturePuzzle(name: "Shell", pattern: [".###.", "#.#.#", "#.#.#", "#####", ".###."])
    ]

    static func clue(_ cells: [Bool]) -> [Int] {
        var groups: [Int] = []
        var length = 0
        for active in cells + [false] {
            if active { length += 1 }
            else if length > 0 { groups.append(length); length = 0 }
        }
        return groups.isEmpty ? [0] : groups
    }

    func matches(_ marks: Set<Int>) -> Bool {
        let rows = (0..<5).map { r in Self.clue((0..<5).map { marks.contains(r * 5 + $0) }) }
        let cols = (0..<5).map { c in Self.clue((0..<5).map { marks.contains($0 * 5 + c) }) }
        return rows == horizontal && cols == vertical
    }
}

struct HarborSudoku {
    let solution: [Int]
    let givens: [Int]

    init() {
        let numbers = Array(1...6).shuffled()
        let bands = Array(0..<3).shuffled()
        let rows = bands.flatMap { band in [band * 2, band * 2 + 1].shuffled() }
        let stacks = [0, 1].shuffled()
        let columns = stacks.flatMap { stack in (0..<3).shuffled().map { stack * 3 + $0 } }
        solution = rows.flatMap { row in columns.map { numbers[(row * 3 + row / 2 + $0) % 6] } }
        var puzzle = solution
        var removed = 0
        for slot in (0..<36).shuffled() {
            let value = puzzle[slot]
            puzzle[slot] = 0
            if Self.countSolutions(puzzle, limit: 2) == 1 {
                removed += 1
                if removed == 19 { break }
            } else {
                puzzle[slot] = value
            }
        }
        givens = puzzle
    }

    static func countSolutions(_ puzzle: [Int], limit: Int) -> Int {
        var index: Int?
        var candidates: [Int] = []
        for slot in puzzle.indices where puzzle[slot] == 0 {
            let row = slot / 6
            let column = slot % 6
            var used = Set((0..<6).map { puzzle[row * 6 + $0] })
            used.formUnion((0..<6).map { puzzle[$0 * 6 + column] })
            let boxRow = (row / 2) * 2
            let boxCol = (column / 3) * 3
            for r in boxRow..<(boxRow + 2) {
                for c in boxCol..<(boxCol + 3) { used.insert(puzzle[r * 6 + c]) }
            }
            let next = (1...6).filter { !used.contains($0) }
            if next.isEmpty { return 0 }
            if index == nil || next.count < candidates.count {
                index = slot
                candidates = next
                if candidates.count == 1 { break }
            }
        }
        guard let index else { return 1 }
        var count = 0
        var working = puzzle
        for candidate in candidates {
            working[index] = candidate
            count += countSolutions(working, limit: limit - count)
            if count >= limit { return limit }
        }
        return count
    }
}

struct DockWord {
    let word: String
    let clue: String

    var letters: [String] {
        let answer = word.map(String.init)
        let shuffled = answer.shuffled()
        return shuffled == answer ? Array(answer.dropFirst()) + Array(answer.prefix(1)) : shuffled
    }

    static let deck = [
        DockWord(word: "ANCHOR", clue: "Keeps a boat from drifting"),
        DockWord(word: "CORAL", clue: "Reef builder"),
        DockWord(word: "MARINA", clue: "A place to tie up a boat"),
        DockWord(word: "OTTER", clue: "A floating shellfish eater"),
        DockWord(word: "PEBBLE", clue: "A small rounded stone"),
        DockWord(word: "LAGOON", clue: "Shallow water behind a reef"),
        DockWord(word: "SHELL", clue: "A mollusk’s hard home"),
        DockWord(word: "SAIL", clue: "Cloth that catches the wind"),
        DockWord(word: "HARBOR", clue: "Sheltered water for ships"),
        DockWord(word: "DUNES", clue: "Hills made of sand"),
        DockWord(word: "GULL", clue: "A loud seabird"),
        DockWord(word: "TIDAL", clue: "Related to the rise and fall of the sea"),
        DockWord(word: "BUOY", clue: "A floating marker"),
        DockWord(word: "PADDLE", clue: "Blade used to move a canoe")
    ]
}

struct LagoonBoard {
    static let grid = TideGrid(rows: 6, columns: 6)
    static let moveLimit = 16
    private(set) var tiles: [Int]
    private(set) var moves = 0

    init(tiles: [Int]? = nil) {
        if let tiles {
            self.tiles = tiles
        } else {
            for _ in 0..<20 {
                let random = (0..<36).map { _ in Int.random(in: 0..<4) }
                var trial = LagoonBoard(tiles: random)
                while !trial.complete && trial.moves < Self.moveLimit {
                    let colors = (0..<4).filter { $0 != trial.tiles[0] }
                    let next = colors.max { trial.region(touching: $0).count < trial.region(touching: $1).count }
                    if let next { trial.flood(next) }
                }
                if trial.complete { self.tiles = random; return }
            }
            self.tiles = (0..<36).map { ($0 / 6 + $0 % 6) % 4 }
        }
    }

    var complete: Bool { tiles.allSatisfy { $0 == tiles[0] } }
    var regionCount: Int { region(touching: tiles[0]).count }

    mutating func flood(_ color: Int) {
        guard (0..<4).contains(color), color != tiles[0], !complete, moves < Self.moveLimit else { return }
        let flooded = region(touching: color)
        for index in flooded { tiles[index] = color }
        moves += 1
    }

    private func region(touching color: Int) -> Set<Int> {
        var included: Set<Int> = [0]
        func expand(_ color: Int) {
            var pending = Array(included)
            while let index = pending.popLast() {
                for next in Self.grid.neighbors(index) where tiles[next] == color {
                    if included.insert(next).inserted { pending.append(next) }
                }
            }
        }
        expand(tiles[0])
        if color != tiles[0] { expand(color) }
        return included
    }
}

struct BuoyBoard {
    static let grid = TideGrid(rows: 5, columns: 5)

    let endpoints: [[Int]]
    private(set) var routes: [[Int]]
    private(set) var selected: Int?

    init(quarterTurns: Int = Int.random(in: 0..<4), mirrored: Bool = Bool.random()) {
        let track: [Int] = (0..<5).flatMap { row -> [Int] in
            let columns = row.isMultiple(of: 2) ? Array(0..<5) : Array((0..<5).reversed())
            return columns.map { row * 5 + $0 }
        }
        func transform(_ index: Int) -> Int {
            var row = index / 5
            var col = mirrored ? 4 - index % 5 : index % 5
            for _ in 0..<quarterTurns { (row, col) = (col, 4 - row) }
            return row * 5 + col
        }
        var start = 0
        endpoints = [5, 4, 6, 5, 5].map { length in
            defer { start += length }
            return [transform(track[start]), transform(track[start + length - 1])]
        }
        routes = Array(repeating: [], count: endpoints.count)
    }

    func buoy(at index: Int) -> Int? { endpoints.firstIndex { $0.contains(index) } }
    func route(at index: Int) -> Int? { routes.firstIndex { $0.contains(index) } }

    var linked: Int {
        routes.enumerated().filter { id, path in path.count >= 2 && endpoints[id].contains(path.last!) }.count
    }

    var occupied: Int { routes.reduce(0) { $0 + $1.count } }
    var complete: Bool { linked == endpoints.count && occupied == 25 }

    mutating func tap(_ index: Int) {
        guard Self.grid.indices.contains(index) else { return }
        if let buoy = buoy(at: index) {
            if selected == buoy,
               let tail = routes[buoy].last,
               routes[buoy].first != index,
               Self.grid.neighbors(tail).contains(index) {
                routes[buoy].append(index)
                selected = nil
            } else {
                routes[buoy] = [index]
                selected = buoy
            }
            return
        }
        guard let id = selected else { return }
        if let previous = routes[id].firstIndex(of: index) {
            routes[id].removeSubrange((previous + 1)..<routes[id].count)
        } else if route(at: index) == nil,
                  let tail = routes[id].last, Self.grid.neighbors(tail).contains(index) {
            routes[id].append(index)
        }
    }
}

struct PegCross {
    static let grid = TideGrid(rows: 7, columns: 7)
    static let holes = Set(grid.indices.filter { (2...4).contains($0 / 7) || (2...4).contains($0 % 7) })
    private(set) var pegs = holes.subtracting([24])

    func landings(from start: Int) -> [Int] {
        guard pegs.contains(start) else { return [] }
        return Self.grid.neighbors(start).compactMap { middle in
            let target = middle + (middle - start)
            guard Self.holes.contains(target), Self.grid.neighbors(middle).contains(target),
                  pegs.contains(middle), !pegs.contains(target) else { return nil }
            return target
        }
    }

    var canJump: Bool { pegs.contains { !landings(from: $0).isEmpty } }

    @discardableResult
    mutating func jump(from start: Int, to end: Int) -> Bool {
        guard landings(from: start).contains(end) else { return false }
        pegs.remove(start)
        pegs.remove((start + end) / 2)
        pegs.insert(end)
        return true
    }
}
