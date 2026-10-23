import SwiftUI
import UIKit

@main struct MyApp: App {
    init() {
        let appearance = UINavigationBarAppearance()
        appearance.configureWithTransparentBackground()
        let descriptor = UIFont.systemFont(ofSize: 33, weight: .regular).fontDescriptor.withDesign(.serif) ?? UIFont.systemFont(ofSize: 33).fontDescriptor
        appearance.largeTitleTextAttributes = [.font: UIFont(descriptor: descriptor, size: 33)]
        let tabs = UITabBarAppearance()
        tabs.configureWithOpaqueBackground()
        tabs.backgroundColor = UIColor { $0.userInterfaceStyle == .dark ? UIColor(red: 0.07, green: 0.10, blue: 0.09, alpha: 1) : UIColor(red: 0.99, green: 0.98, blue: 0.96, alpha: 1) }
        tabs.shadowColor = UIColor { $0.userInterfaceStyle == .dark ? UIColor.white.withAlphaComponent(0.07) : UIColor.black.withAlphaComponent(0.06) }
        UITabBar.appearance().standardAppearance = tabs
        UITabBar.appearance().scrollEdgeAppearance = tabs
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
    }
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
