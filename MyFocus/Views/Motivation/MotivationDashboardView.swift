import SwiftUI

struct MotivationDashboardView: View {
    @ObservedObject var settings = MotivationSettings.shared
    var onEditRequested: () -> Void
    
    var body: some View {
        ZStack {
            ScrollView {
                VStack(spacing: 20) {
                    ForEach(settings.categories) { category in
                        if !category.items.isEmpty {
                            motivationCard(category: category)
                        }
                    }
                    
                    // If everything is empty (they skipped onboarding)
                    if settings.categories.allSatisfy({ $0.items.isEmpty }) {
                        VStack(spacing: 16) {
                            Image(systemName: "flame.fill")
                                .font(.system(size: 60))
                                .foregroundColor(.white.opacity(0.3))
                            Text("Ваши смыслы пока пусты")
                                .font(.headline)
                                .foregroundColor(.white.opacity(0.6))
                            Button("Настроить смыслы") {
                                onEditRequested()
                            }
                            .padding()
                            .background(Color.white.opacity(0.1))
                            .cornerRadius(12)
                        }
                        .padding(.top, 50)
                    } else {
                        // Edit button at the bottom of the page
                        Button(action: {
                            onEditRequested()
                        }) {
                            HStack(spacing: 8) {
                                Image(systemName: "pencil")
                                Text("Настроить смыслы")
                            }
                            .font(.subheadline.bold())
                            .foregroundColor(.white.opacity(0.6))
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                            .background(Color.white.opacity(0.05))
                            .cornerRadius(22)
                            .overlay(
                                RoundedRectangle(cornerRadius: 22)
                                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 15)
                    }
                }
                .padding()
                .padding(.bottom, 80) // Space for TabBar
            }
        }
        .withAmbientGlow()
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func motivationCard(category: MotivationCategory) -> some View {
        let baseColor = Color(hex: category.colorHex)
        
        return VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(LinearGradient(colors: [baseColor, baseColor.opacity(0.6)], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 44, height: 44)
                        .shadow(color: baseColor.opacity(0.5), radius: 8, x: 0, y: 4)
                    
                    Image(systemName: category.icon)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                }
                
                Text(category.title)
                    .font(.title3.bold())
                    .foregroundColor(.white)
                
                Spacer()
            }
            
            MotivationFlowLayout(spacing: 10) {
                ForEach(category.items) { item in
                    Text(item.text)
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 18)
                                .fill(baseColor.opacity(0.15))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 18)
                                .stroke(baseColor.opacity(0.35), lineWidth: 1)
                        )
                }
            }
            .padding(.top, 4)
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 28)
                .fill(LinearGradient(
                    colors: [baseColor.opacity(0.12), baseColor.opacity(0.02)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 28)
                .stroke(LinearGradient(colors: [baseColor.opacity(0.4), baseColor.opacity(0.05)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 5)
    }
}

#Preview {
    MotivationDashboardView {}
}

// MARK: - MotivationFlowLayout
struct MotivationFlowLayout: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(in: proposal.width ?? 0, subviews: subviews, spacing: spacing)
        return result.size
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(in: bounds.width, subviews: subviews, spacing: spacing)
        for (index, subview) in subviews.enumerated() {
            let point = result.points[index]
            subview.place(at: CGPoint(x: point.x + bounds.minX, y: point.y + bounds.minY), proposal: .unspecified)
        }
    }
    
    struct FlowResult {
        var size: CGSize = .zero
        var points: [CGPoint] = []
        
        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var currentX: CGFloat = 0
            var currentY: CGFloat = 0
            var lineHeight: CGFloat = 0
            
            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)
                
                if currentX + size.width > maxWidth && currentX > 0 {
                    // Move to next line
                    currentX = 0
                    currentY += lineHeight + spacing
                    lineHeight = 0
                }
                
                points.append(CGPoint(x: currentX, y: currentY))
                lineHeight = max(lineHeight, size.height)
                currentX += size.width + spacing
            }
            
            self.size = CGSize(width: maxWidth, height: currentY + lineHeight)
        }
    }
}
