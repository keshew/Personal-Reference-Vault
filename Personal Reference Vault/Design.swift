import SwiftUI
import UIKit

enum VaultStyle {
    static let accent = Color(light: 0x365D54, dark: 0xCFB78E)
    static let background = Color(light: 0xF3F0E9, dark: 0x101817)
    static let surface = Color(light: 0xFFFDFA, dark: 0x1B2522)
    static let ink = Color(light: 0x24332D, dark: 0xF1EDE3)
    static let secondary = Color(light: 0x7D8276, dark: 0xA5ADA2)
    static let line = Color(light: 0xDFDFD3, dark: 0x344039)
    static let gold = Color(red: 0.78, green: 0.66, blue: 0.46)
    static let midnight = Color(red: 0.08, green: 0.14, blue: 0.12)
    static let ivory = Color(red: 0.96, green: 0.93, blue: 0.86)
}

struct VaultPanel: ViewModifier {
    var radius: CGFloat = 20
    func body(content: Content) -> some View {
        content.background(VaultStyle.surface, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay { RoundedRectangle(cornerRadius: radius, style: .continuous).strokeBorder(VaultStyle.line.opacity(0.7), lineWidth: 0.7) }
            .shadow(color: .black.opacity(0.025), radius: 16, x: 0, y: 7)
    }
}

struct VaultEyebrow: View {
    let text: String
    var color: Color = VaultStyle.secondary
    var body: some View { Text(text.uppercased()).font(.system(size: 9, weight: .semibold, design: .monospaced)).tracking(2).foregroundStyle(color) }
}

struct VaultArtwork: View {
    var size: CGFloat = 150
    var body: some View {
        ZStack {
            Circle().stroke(VaultStyle.gold.opacity(0.13), lineWidth: 0.6).frame(width: size * 1.14, height: size * 1.14)
            Circle().stroke(VaultStyle.gold.opacity(0.09), lineWidth: 0.6).frame(width: size * 1.5, height: size * 1.5)
            archiveCard(opacity: 0.32).rotationEffect(.degrees(-18)).offset(x: -size * 0.10, y: size * 0.04)
            archiveCard(opacity: 0.60).rotationEffect(.degrees(-7)).offset(x: -size * 0.03, y: -size * 0.025)
            archiveCard(opacity: 1).rotationEffect(.degrees(7))
        }.frame(width: size, height: size * 1.13).accessibilityHidden(true)
    }
    private func archiveCard(opacity: Double) -> some View {
        VStack(alignment: .leading, spacing: size * 0.10) {
            HStack(alignment: .top) {
                Image(systemName: "square.stack.3d.up").font(.system(size: size * 0.14, weight: .ultraLight))
                Spacer()
                Image(systemName: "bookmark.fill").font(.system(size: size * 0.20, weight: .light)).foregroundStyle(VaultStyle.gold)
            }
            Spacer(minLength: 0)
            Rectangle().fill(VaultStyle.ivory.opacity(0.65)).frame(width: size * 0.38, height: 1)
            Rectangle().fill(VaultStyle.ivory.opacity(0.22)).frame(height: 1)
            HStack { Rectangle().fill(VaultStyle.gold.opacity(0.8)).frame(width: size * 0.18, height: 3); Spacer(); Text("RV").font(.system(size: size * 0.08, weight: .light, design: .serif)).tracking(2) }
        }.padding(size * 0.13).frame(width: size * 0.82, height: size * 0.98)
            .foregroundStyle(VaultStyle.ivory)
            .background(LinearGradient(colors: [Color(red: 0.24, green: 0.36, blue: 0.30), Color(red: 0.12, green: 0.22, blue: 0.18)], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: size * 0.09))
            .overlay { RoundedRectangle(cornerRadius: size * 0.09).strokeBorder(LinearGradient(colors: [VaultStyle.gold.opacity(0.7), .white.opacity(0.04), VaultStyle.gold.opacity(0.22)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 0.8) }
            .shadow(color: .black.opacity(0.28), radius: 12, x: 3, y: 9).opacity(opacity)
    }
}

extension Color {
    init(light: UInt32, dark: UInt32) {
        self.init(uiColor: UIColor { traits in
            let value = traits.userInterfaceStyle == .dark ? dark : light
            return UIColor(red: CGFloat((value >> 16) & 255) / 255, green: CGFloat((value >> 8) & 255) / 255, blue: CGFloat(value & 255) / 255, alpha: 1)
        })
    }
}

extension VaultColor {
    var color: Color {
        switch self {
        case .teal: return VaultStyle.accent
        case .blue: return Color(light: 0x527A9B, dark: 0x9CBDD8)
        case .amber: return Color(light: 0x9E773E, dark: 0xD8B77D)
        case .green: return Color(light: 0x6E8564, dark: 0xABC19F)
        case .rose: return Color(light: 0xA16F68, dark: 0xD7A59D)
        case .slate: return Color(light: 0x737E89, dark: 0xAAB7C2)
        }
    }
}

struct IconTile: View {
    let icon: String
    var color: Color = VaultStyle.accent
    var size: CGFloat = 44
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.29, style: .continuous)
                .fill(LinearGradient(colors: [color.opacity(0.13), color.opacity(0.04)], startPoint: .topLeading, endPoint: .bottomTrailing))
            RoundedRectangle(cornerRadius: size * 0.29, style: .continuous).strokeBorder(color.opacity(0.19), lineWidth: 0.6)
            Image(systemName: icon).font(.system(size: size * 0.40, weight: .light)).foregroundStyle(color)
        }.frame(width: size, height: size).accessibilityHidden(true)
    }
}

struct BrandMark: View {
    var size: CGFloat = 64
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.28).fill(VaultStyle.midnight)
            RoundedRectangle(cornerRadius: size * 0.20).stroke(VaultStyle.gold.opacity(0.45), lineWidth: 0.7).padding(size * 0.10)
            Image(systemName: "rectangle.stack").font(.system(size: size * 0.40, weight: .ultraLight)).foregroundStyle(VaultStyle.ivory)
            Image(systemName: "bookmark.fill").font(.system(size: size * 0.15)).foregroundStyle(VaultStyle.gold).offset(x: size * 0.20, y: -size * 0.17)
        }.frame(width: size, height: size).accessibilityHidden(true)
    }
}

struct VaultEmptyState: View {
    let icon: String
    let title: String
    let message: String
    var actionTitle: String?
    var action: (() -> Void)?
    var body: some View {
        VStack(spacing: 15) {
            ZStack {
                Circle().stroke(VaultStyle.gold.opacity(0.16), lineWidth: 1).frame(width: 114, height: 114)
                Circle().stroke(VaultStyle.gold.opacity(0.10), lineWidth: 1).frame(width: 88, height: 88)
                IconTile(icon: icon, size: 60)
            }.padding(.bottom, 8)
            Text(title).font(.system(.title2, design: .serif).weight(.medium)).foregroundStyle(VaultStyle.ink)
            Text(message).font(.subheadline).foregroundStyle(VaultStyle.secondary).multilineTextAlignment(.center).frame(maxWidth: 290)
            if let title = actionTitle, let action {
                Button(title, action: action).buttonStyle(VaultPrimaryButton()).padding(.top, 7)
            }
        }.frame(maxWidth: .infinity).padding(.vertical, 38).padding(.horizontal, 20)
    }
}

struct VaultPrimaryButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.subheadline.weight(.semibold)).foregroundStyle(VaultStyle.ivory)
            .padding(.horizontal, 22).padding(.vertical, 17)
            .background(LinearGradient(colors: [Color(red: 0.23, green: 0.36, blue: 0.29), VaultStyle.midnight], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 15))
            .overlay { RoundedRectangle(cornerRadius: 15).strokeBorder(VaultStyle.gold.opacity(0.40), lineWidth: 0.7) }
            .shadow(color: .black.opacity(0.12), radius: 10, y: 5)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

struct SectionHeading<Destination: View>: View {
    let title: String
    let destination: Destination
    var body: some View {
        HStack {
            Text(title).font(.system(.title2, design: .serif).weight(.medium)).foregroundStyle(VaultStyle.ink)
            Spacer()
            NavigationLink(destination: destination) {
                Image(systemName: "arrow.up.right").font(.system(size: 11, weight: .medium)).foregroundStyle(VaultStyle.accent).frame(width: 29, height: 29).overlay(Circle().stroke(VaultStyle.line, lineWidth: 1)).accessibilityLabel("View all \(title)")
            }
        }
    }
}

struct TagPill: View {
    let tag: VaultTag
    var body: some View {
        Text(tag.name).font(.caption.weight(.medium)).foregroundStyle(tag.color.color)
            .padding(.horizontal, 11).padding(.vertical, 6).background(tag.color.color.opacity(0.10), in: Capsule())
    }
}

struct ReferenceRow: View {
    @EnvironmentObject var store: VaultStore
    let item: ReferenceItem
    var card = false
    var body: some View {
        HStack(alignment: .center, spacing: 13) {
            if let data = item.photos.first?.imageData, let image = UIImage(data: data) {
                Image(uiImage: image).resizable().scaledToFill().frame(width: 46, height: 50).clipShape(RoundedRectangle(cornerRadius: 12)).accessibilityHidden(true)
            } else { IconTile(icon: item.type == .general ? (store.category(item.categoryID)?.icon ?? item.type.icon) : item.type.icon, color: store.category(item.categoryID)?.color.color ?? VaultStyle.accent, size: 46) }
            VStack(alignment: .leading, spacing: 6) {
                if card { VaultEyebrow(text: store.categoryName(item.categoryID)).lineLimit(1) }
                Text(item.title).font(.system(.body, design: .serif).weight(.medium)).foregroundStyle(VaultStyle.ink).lineLimit(2)
                Text(item.displayValue).font(.system(.caption, design: .monospaced)).foregroundStyle(VaultStyle.secondary).lineLimit(2)

            }
            Spacer(minLength: 3)
            if item.isPinned { Image(systemName: "pin.fill").font(.caption2).foregroundStyle(VaultStyle.accent).accessibilityLabel("Pinned") }
            if item.isFavorite { Image(systemName: "star.fill").font(.caption2).foregroundStyle(VaultStyle.gold).accessibilityLabel("Favorite") }
            if card { Image(systemName: "chevron.right").font(.system(size: 9, weight: .medium)).foregroundStyle(VaultStyle.secondary.opacity(0.7)) }
        }.padding(.vertical, store.settings.density == "Compact" ? 7 : 16)
            .padding(.horizontal, card ? 15 : 0).frame(maxWidth: .infinity, alignment: .leading)
            .background(card ? VaultStyle.surface : .clear, in: RoundedRectangle(cornerRadius: 18))
            .overlay { if card { RoundedRectangle(cornerRadius: 18).strokeBorder(VaultStyle.line.opacity(0.7), lineWidth: 0.7) } }
            .contentShape(Rectangle())
    }
}

struct ActivitySheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController { UIActivityViewController(activityItems: items, applicationActivities: nil) }
    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}

struct SharePayload: Identifiable {
    let id = UUID()
    let items: [Any]
}

struct LibraryNoticePresenter: UIViewControllerRepresentable {
    @Binding var message: String?
    func makeUIViewController(context: Context) -> NoticeController { NoticeController() }
    func updateUIViewController(_ controller: NoticeController, context: Context) {
        controller.message = message
        controller.clear = { message = nil }
        DispatchQueue.main.async { [weak controller] in controller?.showNotice() }
    }
    final class NoticeController: UIViewController {
        var message: String?
        var clear: (() -> Void)?
        private var showing = false
        override func viewDidAppear(_ animated: Bool) { super.viewDidAppear(animated); showNotice() }
        func showNotice() {
            guard let message, !showing, var top = view.window?.rootViewController else { return }
            while let presented = top.presentedViewController { top = presented }
            guard !(top is UIAlertController), !top.isBeingDismissed, !top.isBeingPresented else {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in self?.showNotice() }
                return
            }
            showing = true
            let alert = UIAlertController(title: "Library notice", message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default) { [weak self] _ in
                self?.showing = false; self?.message = nil; self?.clear?()
            })
            top.present(alert, animated: true)
        }
    }
}

extension View {
    func vaultPanel(radius: CGFloat = 20) -> some View { modifier(VaultPanel(radius: radius)) }
    func vaultBackground() -> some View { scrollContentBackground(.hidden).background(VaultStyle.background).environment(\.defaultMinListRowHeight, 54) }
    func dismissKeyboardOnScroll() -> some View { scrollDismissesKeyboard(.interactively) }
}
