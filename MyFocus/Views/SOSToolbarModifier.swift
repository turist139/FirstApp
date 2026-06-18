import SwiftUI

struct SOSToolbarModifier: ViewModifier {
    @State private var showSOS = false
    
    func body(content: Content) -> some View {
        content
            .overlay(alignment: .topTrailing) {
                Button(action: {
                    showSOS = true
                }) {
                    ZStack {
                        Circle()
                            .fill(LinearGradient(colors: [.red, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 60, height: 60)
                        
                        Circle()
                            .fill(Color.red.opacity(0.4))
                            .frame(width: 60, height: 60)
                            .blur(radius: 8)
                        
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.white)
                    }
                    .frame(width: 60, height: 60)
                    .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .padding(.trailing, 16)
                .padding(.top, 54) // Lowered by 2 pixels based on user feedback
                .ignoresSafeArea(.all, edges: .top)
            }
            .sheet(isPresented: $showSOS) {
                SOSBreathingView()
            }
    }
}

extension View {
    func withSOSToolbar() -> some View {
        self.modifier(SOSToolbarModifier())
    }
}
