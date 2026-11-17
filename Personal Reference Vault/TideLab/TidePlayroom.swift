import SwiftUI
import UIKit

enum TidePaint {
    static let canvas = Color(red: 0.94, green: 0.97, blue: 0.955)
    static let paper = Color(red: 0.997, green: 0.993, blue: 0.973)
    static let ink = Color(red: 0.065, green: 0.16, blue: 0.23)
    static let secondary = Color(red: 0.28, green: 0.38, blue: 0.41)
    static let cobalt = Color(red: 0.12, green: 0.29, blue: 0.78)
    static let sea = Color(red: 0.76, green: 0.90, blue: 0.85)
    static let coral = Color(red: 0.90, green: 0.35, blue: 0.23)
    static let line = Color(red: 0.84, green: 0.89, blue: 0.87)

    static func swatch(_ game: TideGame) -> Color {
        switch game {
        case .four, .sudoku: Color(red: 0.84, green: 0.89, blue: 1)
        case .reversi, .flood: sea
        case .picross, .pegs: Color(red: 0.97, green: 0.87, blue: 0.71)
        case .words, .routes: Color(red: 1, green: 0.86, blue: 0.80)
        }
    }
}

enum TideTab: String, CaseIterable, Hashable {
    case play = "Play"
    case log = "Log"

    var icon: String {
        switch self {
        case .play: "sailboat"
        case .log: "list.bullet.rectangle"
        }
    }
}

struct TidePlayroom: View {
    @Binding var tab: TideTab
    @Binding var path: [TideGame]
    @AppStorage(TideJournal.storageKey) private var saved = Data()
    @State private var filter: Filter = .all

    private enum Filter: String, CaseIterable {
        case all = "All"
        case puzzles = "Puzzles"
        case versus = "Vs. Computer"
        case word = "Word play"
    }

    private var journal: TideJournal { TideJournal(data: saved) }

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    topLine
                    if tab == .play { playContent } else { logContent }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
                .padding(.bottom, 10)
                .frame(maxWidth: 660)
                .frame(maxWidth: .infinity)
            }
            .id(tab)
            .background(TidePaint.canvas.ignoresSafeArea())
            .foregroundStyle(TidePaint.ink)
            .safeAreaInset(edge: .bottom, spacing: 0) { navigationBar }
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: TideGame.self) { game in
                TideMatchView(game: game, best: journal[game].best) { result in
                    var updated = journal
                    updated.add(result, game: game)
                    saved = updated.data
                }
            }
        }
        .tint(TidePaint.cobalt)
        .preferredColorScheme(.light)
    }

    private var topLine: some View {
        HStack(spacing: 10) {
            Image(systemName: tab == .play ? "water.waves" : "book.closed")
                .font(.system(.headline, design: .rounded).weight(.bold))
                .frame(width: 38, height: 38)
                .foregroundStyle(.white)
                .background(TidePaint.cobalt, in: RoundedRectangle(cornerRadius: 12))
                .accessibilityHidden(true)
            Text(tab == .play ? "Diamond Luck" : "Play log")
                .font(.system(.largeTitle, design: .rounded).weight(.heavy))
                .accessibilityAddTraits(.isHeader)
            Spacer()
            if tab == .play {
                Text("Offline")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(TidePaint.secondary)
            }
        }
    }

    @ViewBuilder private var playContent: some View {
        featuredCard
        HStack {
            Text("All games")
                .font(.system(.title2, design: .rounded).weight(.heavy))
                .accessibilityAddTraits(.isHeader)
            Spacer()
            Text("\(games.count) \(games.count == 1 ? "game" : "games")")
                .font(.subheadline)
                .foregroundStyle(TidePaint.secondary)
        }
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 7) {
                ForEach(Filter.allCases, id: \.self) { option in
                    Button {
                        filter = option
                    } label: {
                        Text(option.rawValue)
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 13)
                            .frame(minHeight: 38)
                            .foregroundStyle(option == filter ? Color.white : TidePaint.ink)
                            .background(option == filter ? TidePaint.cobalt : TidePaint.paper, in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(option == filter ? [.isSelected] : [])
                }
            }
        }
        VStack(spacing: 0) {
            ForEach(games) { game in
                gameRow(game)
                if game != games.last { Divider().overlay(TidePaint.line).padding(.leading, 78) }
            }
        }
        .background(TidePaint.paper, in: RoundedRectangle(cornerRadius: 23))
        .overlay { RoundedRectangle(cornerRadius: 23).strokeBorder(TidePaint.line).allowsHitTesting(false) }
    }

    @ViewBuilder private var logContent: some View {
        HStack(spacing: 10) {
            stat(journal.played, label: "Rounds", icon: "play.circle")
            stat(journal.wins, label: "Wins & solves", icon: "checkmark.seal")
        }
        Text("Recent rounds")
            .font(.system(.title2, design: .rounded).weight(.heavy))
            .accessibilityAddTraits(.isHeader)
        if journal.entries.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("A fresh page").font(.headline)
                Text("Finish a game to start your play log.")
                    .font(.subheadline)
                    .foregroundStyle(TidePaint.secondary)
                Button("Choose a game", systemImage: "arrow.right") { tab = .play }
                    .font(.subheadline.weight(.semibold))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(17)
            .background(TidePaint.paper, in: RoundedRectangle(cornerRadius: 18))
        } else {
            VStack(spacing: 9) {
                ForEach(journal.entries) { entry in
                    Button {
                        path.append(entry.game)
                    } label: {
                        HStack(spacing: 11) {
                            symbol(entry.game, size: 43)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(entry.game.title).font(.headline)
                                Text(entry.title + " · " + entry.date.formatted(date: .abbreviated, time: .omitted))
                                    .font(.caption).foregroundStyle(TidePaint.secondary)
                            }
                            Spacer(minLength: 6)
                            if let score = entry.score {
                                Text(entry.game.format(score))
                                    .font(.caption.weight(.semibold))
                                    .multilineTextAlignment(.trailing)
                                    .foregroundStyle(TidePaint.cobalt)
                            }
                        }
                        .padding(11)
                        .background(TidePaint.paper, in: RoundedRectangle(cornerRadius: 15))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var feature: TideGame {
        let day = Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 1
        let choices: [TideGame] = [.routes, .picross, .flood, .sudoku, .pegs]
        return choices[(day - 1) % choices.count]
    }

    private var games: [TideGame] {
        TideGame.allCases.filter { filter == .all || $0.group.rawValue == filter.rawValue }
    }

    private var featuredCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Puzzle of the day")
                .font(.caption.weight(.bold))
                .foregroundStyle(TidePaint.secondary)
            Text(feature.title)
                .font(.system(.title, design: .rounded).weight(.heavy))
                .fixedSize(horizontal: false, vertical: true)
            Text(feature.subtitle)
                .font(.subheadline)
                .foregroundStyle(TidePaint.secondary)
            TideAction(title: "Play", icon: "arrow.right") { path.append(feature) }
                .accessibilityIdentifier("tide.featured")
        }
        .padding(18)
        .frame(maxWidth: .infinity, minHeight: 177, alignment: .leading)
        .background {
            GeometryReader { geometry in
                ZStack {
                    Rectangle().fill(TidePaint.sea)
                    if let art = UIImage(named: "Tide Table") {
                        Image(uiImage: art)
                            .resizable()
                            .scaledToFill()
                            .frame(width: geometry.size.width, height: geometry.size.height, alignment: .trailing)
                    }
                    LinearGradient(stops: [
                        .init(color: TidePaint.sea, location: 0),
                        .init(color: TidePaint.sea.opacity(0.89), location: 0.41),
                        .init(color: TidePaint.sea.opacity(0.02), location: 1)
                    ], startPoint: .leading, endPoint: .trailing)
                }
                .clipped()
            }
            .accessibilityHidden(true)
        }
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .overlay { RoundedRectangle(cornerRadius: 24).strokeBorder(TidePaint.ink.opacity(0.07)).allowsHitTesting(false) }
    }

    private var navigationBar: some View {
        HStack(spacing: 0) {
            ForEach(TideTab.allCases, id: \.self) { item in
                Button { tab = item } label: {
                    VStack(spacing: 5) {
                        Image(systemName: item.icon)
                            .font(.system(size: 19, weight: .semibold))
                            .frame(width: 51, height: 27)
                            .background(tab == item ? TidePaint.cobalt.opacity(0.10) : .clear, in: Capsule())
                        Text(item.rawValue)
                            .font(.caption2.weight(tab == item ? .bold : .semibold))
                    }
                    .foregroundStyle(tab == item ? TidePaint.cobalt : TidePaint.secondary)
                    .frame(maxWidth: .infinity, minHeight: 48)
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(tab == item ? [.isSelected] : [])
                .accessibilityIdentifier("tide.tab.\(item.rawValue)")
            }
        }
        .padding(.vertical, 5)
        .background { TidePaint.paper.ignoresSafeArea(edges: .bottom) }
        .overlay(alignment: .top) {
            Rectangle().fill(TidePaint.line).frame(height: 1).allowsHitTesting(false)
        }
    }

    private func gameRow(_ game: TideGame) -> some View {
        Button {
            path.append(game)
        } label: {
            HStack(spacing: 12) {
                symbol(game, size: 51)
                VStack(alignment: .leading, spacing: 4) {
                    Text(game.title)
                        .font(.system(.headline, design: .rounded).weight(.bold))
                    Text(game.subtitle)
                        .font(.caption)
                        .foregroundStyle(TidePaint.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(TidePaint.cobalt)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("tide.game.\(game.rawValue)")
    }

    private func symbol(_ game: TideGame, size: CGFloat) -> some View {
        Image(systemName: game.symbol)
            .font(.system(size: size * 0.46, weight: .semibold))
            .foregroundStyle(TidePaint.ink)
            .frame(width: size, height: size)
            .background(TidePaint.swatch(game), in: RoundedRectangle(cornerRadius: 12))
            .accessibilityHidden(true)
    }

    private func stat(_ number: Int, label: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: icon).foregroundStyle(TidePaint.cobalt)
            Text(number.formatted())
                .font(.system(.title, design: .rounded).weight(.heavy))
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(TidePaint.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(15)
        .background(TidePaint.sea, in: RoundedRectangle(cornerRadius: 16))
    }
}

struct TideAction: View {
    let title: String
    var icon: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Text(title)
                if let icon { Image(systemName: icon).accessibilityHidden(true) }
            }
            .font(.subheadline.weight(.bold))
            .padding(.horizontal, 16)
            .frame(minHeight: 44)
            .foregroundStyle(.white)
            .background(TidePaint.cobalt, in: RoundedRectangle(cornerRadius: 13))
        }
        .buttonStyle(.plain)
    }
}
