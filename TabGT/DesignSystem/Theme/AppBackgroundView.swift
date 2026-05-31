import SwiftUI

struct AppBackgroundView: View {
    @EnvironmentObject private var themeStore: ThemeStore

    var body: some View {
        let theme = themeStore.theme

        ZStack {
            AppTheme.background

            if theme.blueWashOpacity > 0.01 {
                VStack(spacing: 0) {
                    Rectangle()
                        .fill(theme.blueWash.opacity(theme.blueWashOpacity))
                        .frame(height: 190)
                        .blur(radius: 70)
                        .offset(y: -86)

                    Spacer()
                }
            }

            LinearGradient(
                colors: [
                    AppTheme.backgroundHighlight,
                    Color.clear,
                    AppTheme.backgroundShadow
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .ignoresSafeArea()
    }
}
