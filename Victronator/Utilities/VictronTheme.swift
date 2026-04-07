import SwiftUI

/// Victron GUI V2 color palette and design constants.
enum VTheme {
    // Core colors from Victron GUI V2
    static let blue = Color(red: 0.22, green: 0.49, blue: 0.77)       // #387DC5
    static let darkBlue = Color(red: 0.067, green: 0.15, blue: 0.23)  // #11263B
    static let orange = Color(red: 0.94, green: 0.59, blue: 0.18)     // #F0962E
    static let green = Color(red: 0.45, green: 0.72, blue: 0.30)      // #72B84C
    static let red = Color(red: 0.95, green: 0.36, blue: 0.35)        // #F35C58
    static let gray5 = Color(red: 0.59, green: 0.58, blue: 0.58)      // #969591

    // Widget dimensions
    static let cornerRadius: CGFloat = 8
    static let borderWidth: CGFloat = 2
    static let pageBG = Color.black
    static let widgetBG = darkBlue

    // Source-specific accent colors
    static let solarColor = orange
    static let batteryColor = blue
    static let generatorColor = green
    static let loadsColor = Color(red: 0.65, green: 0.45, blue: 0.78) // Purple-ish for loads
}
