import SwiftUI

#if os(macOS)
import AppKit
#endif

/// Full-screen launch overlay with an animated brand gradient and app mark.
struct SplashScreenView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var logoOpacity = 0.0
    @State private var logoScale = 0.88
    @State private var titleOpacity = 0.0

    var body: some View {
        ZStack {
            AnimatedSplashBackground(reduceMotion: reduceMotion)

            VStack(spacing: 18) {
                appMark
                    .frame(width: 96, height: 96)
                    .shadow(color: Color.themeHex(0x007ACC).opacity(0.35), radius: 24, y: 8)
                    .scaleEffect(logoScale)
                    .opacity(logoOpacity)

                Text("TabGT")
                    .font(.system(size: 28, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.92))
                    .opacity(titleOpacity)
            }
        }
        .ignoresSafeArea()
        .onAppear(perform: startEntranceAnimation)
    }

    @ViewBuilder
    private var appMark: some View {
        #if os(macOS)
        if let icon = NSApplication.shared.applicationIconImage {
            Image(nsImage: icon)
                .resizable()
                .aspectRatio(contentMode: .fit)
        } else {
            Image("AppLogo")
                .resizable()
                .aspectRatio(contentMode: .fit)
        }
        #else
        Image("AppLogo")
            .resizable()
            .aspectRatio(contentMode: .fit)
        #endif
    }

    private func startEntranceAnimation() {
        let entrance = reduceMotion
            ? Animation.linear(duration: 0.2)
            : Animation.spring(response: 0.7, dampingFraction: 0.82)

        withAnimation(entrance) {
            logoOpacity = 1
            logoScale = 1
        }

        withAnimation(entrance.delay(0.12)) {
            titleOpacity = 1
        }
    }
}

private struct AnimatedSplashBackground: View {
    let reduceMotion: Bool

    private let accentBlue = Color.themeHex(0x007ACC)
    private let accentCyan = Color.themeHex(0x00A3FF)
    private let deepBlack = Color.themeHex(0x050508)

    var body: some View {
        TimelineView(.animation(minimumInterval: reduceMotion ? nil : 1.0 / 30.0)) { timeline in
            let phase = reduceMotion ? 0 : timeline.date.timeIntervalSinceReferenceDate

            ZStack {
                deepBlack

                LinearGradient(
                    colors: [
                        Color.themeHex(0x101014),
                        Color.themeHex(0x0A0A0E),
                        deepBlack
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                AngularGradient(
                    gradient: Gradient(colors: [
                        accentBlue.opacity(0.55),
                        accentCyan.opacity(0.18),
                        deepBlack.opacity(0.05),
                        accentBlue.opacity(0.42)
                    ]),
                    center: .center,
                    angle: .degrees(phase * 28)
                )
                .blur(radius: 90)
                .opacity(0.85)

                splashOrb(
                    color: accentBlue,
                    size: 420,
                    blur: 110,
                    x: cos(phase * 0.55) * 120,
                    y: sin(phase * 0.45) * 80 - 40
                )

                splashOrb(
                    color: accentCyan,
                    size: 320,
                    blur: 90,
                    x: sin(phase * 0.4) * 100 + 60,
                    y: cos(phase * 0.35) * 70 + 100
                )

                RadialGradient(
                    colors: [
                        Color.clear,
                        deepBlack.opacity(0.35),
                        deepBlack.opacity(0.92)
                    ],
                    center: .center,
                    startRadius: 80,
                    endRadius: 520
                )
            }
        }
    }

    private func splashOrb(
        color: Color,
        size: CGFloat,
        blur: CGFloat,
        x: CGFloat,
        y: CGFloat
    ) -> some View {
        Circle()
            .fill(color.opacity(0.38))
            .frame(width: size, height: size)
            .blur(radius: blur)
            .offset(x: x, y: y)
    }
}

private enum SplashScreenTiming {
    static let minimumVisible: Duration = .milliseconds(1_400)
    static let dismissAnimation: TimeInterval = 0.45
}

extension View {
    /// Presents the animated launch splash until the minimum duration elapses, then fades it out.
    func launchSplash(isPresented: Binding<Bool>) -> some View {
        modifier(LaunchSplashModifier(isPresented: isPresented))
    }
}

private struct LaunchSplashModifier: ViewModifier {
    @Binding var isPresented: Bool

    func body(content: Content) -> some View {
        ZStack {
            content

            if isPresented {
                SplashScreenView()
                    .transition(.opacity)
                    .zIndex(1)
            }
        }
        .task {
            guard isPresented else { return }
            try? await Task.sleep(for: SplashScreenTiming.minimumVisible)
            withAnimation(.easeOut(duration: SplashScreenTiming.dismissAnimation)) {
                isPresented = false
            }
        }
    }
}
