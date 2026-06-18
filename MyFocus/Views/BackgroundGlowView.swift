import SwiftUI

struct AmbientGlowModifier: ViewModifier {
    @AppStorage("activePalette", store: .shared) private var activePalette: String = "default"
    var isBreathing: Bool
    var isInhaling: Bool
    
    func body(content: Content) -> some View {
        content
            .background(
                GeometryReader { geo in
                    ZStack {
                        Color.black // Base background color
                        
                        LinearGradient(
                            colors: PaletteManager.shared.getGradientColors(for: activePalette),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .frame(height: geo.size.height)
                        // Offset by 0.90 * height to create an even lower ambient glow under the tab bar
                        .offset(y: isBreathing ? (isInhaling ? 0 : geo.size.height * 0.90) : geo.size.height * 0.90)
                        .blur(radius: 50)
                    }
                }
                .ignoresSafeArea()
            )
    }
}

extension View {
    func withAmbientGlow(isBreathing: Bool = false, isInhaling: Bool = false) -> some View {
        self.modifier(AmbientGlowModifier(isBreathing: isBreathing, isInhaling: isInhaling))
    }
}
