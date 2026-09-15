import SwiftUI

/// Shared "liquid glass" styling helpers: frosted translucent material,
/// fully rounded shapes, and a soft white edge highlight, used throughout
/// the app instead of flat solid-color panels.
extension View {
    func glassCapsule() -> some View {
        self
            .background(.ultraThinMaterial, in: Capsule())
            .overlay(Capsule().stroke(Color.white.opacity(0.35), lineWidth: 1))
    }

    func glassCard(cornerRadius: CGFloat = 18) -> some View {
        self
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.white.opacity(0.22), lineWidth: 1)
            )
    }

    func glassPill(cornerRadius: CGFloat = 10) -> some View {
        self
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.white.opacity(0.3), lineWidth: 0.75)
            )
    }

    /// A gentle fade + rise-in, staggered by `delay`. Use on metadata rows
    /// so the detail screen fills in with a bit of life instead of popping
    /// in all at once.
    func revealOnAppear(_ appeared: Bool, delay: Double = 0) -> some View {
        self
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 10)
            .animation(.easeOut(duration: 0.45).delay(delay), value: appeared)
    }
}

/// The app's dark-but-not-flat backdrop: a soft charcoal gradient with a
/// hint of the accent color bleeding in from the top, rather than pure
/// black, so glass panels have something to actually refract.
struct AppBackground: View {
    var body: some View {
        LinearGradient(
            colors: [
                Color(red: 0.16, green: 0.10, blue: 0.16),
                Color(red: 0.07, green: 0.07, blue: 0.09),
                Color.black
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }
}
