import re

with open("MyFocus/Views/Statistics/StatisticsView.swift", "r") as f:
    content = f.read()

# Append relapseHistoryCard definition
new_methods = """
    private var relapseHistoryCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("ИСТОРИЯ СРЫВОВ")
                .font(.caption.bold())
                .foregroundColor(.white.opacity(0.6))
                .tracking(1)
            
            if pastRelapses.isEmpty {
                Text("У вас еще нет ни одного срыва.")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.5))
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity, alignment: .center)
            } else {
                VStack(spacing: 12) {
                    ForEach(pastRelapses) { relapse in
                        HStack(alignment: .center, spacing: 12) {
                            Circle()
                                .fill(Color.orange)
                                .frame(width: 8, height: 8)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                let startStr = formatTargetDate(relapse.startDate)
                                let endStr = relapse.endDate != nil ? formatTargetDate(relapse.endDate!) : ""
                                
                                if let end = relapse.endDate, !Calendar.current.isDate(relapse.startDate, inSameDayAs: end) {
                                    Text("\(startStr) – \(endStr)")
                                        .font(.subheadline.bold())
                                        .foregroundColor(.white)
                                } else {
                                    Text(startStr)
                                        .font(.subheadline.bold())
                                        .foregroundColor(.white)
                                }
                                
                                if let notes = relapse.notes, !notes.isEmpty {
                                    Text(notes)
                                        .font(.caption)
                                        .foregroundColor(.white.opacity(0.6))
                                        .lineLimit(2)
                                }
                            }
                            
                            Spacer()
                            
                            VStack(alignment: .trailing, spacing: 4) {
                                Text(relapse.reason)
                                    .font(.subheadline.bold())
                                    .foregroundColor(.orange)
                                
                                Text(formatRelapseDurationValue(for: relapse))
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.5))
                            }
                        }
                        .padding()
                        .background(Color.white.opacity(0.04))
                        .cornerRadius(12)
                    }
                }
            }
        }
        .padding()
        .background(Color.white.opacity(0.04))
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
    }

    private func formatRelapseDurationValue(for relapse: RelapseHistoryItem) -> String {
        let duration = relapse.duration
        if duration < 60 {
            return "мгновенно"
        }
        let days = Int(duration) / 86400
        if days > 0 {
            let hours = (Int(duration) % 86400) / 3600
            if hours > 0 {
                return "\(days)д \(hours)ч"
            }
            return "\(days)д"
        }
        let hours = Int(duration) / 3600
        if hours > 0 {
            return "\(hours)ч"
        }
        let minutes = (Int(duration) % 3600) / 60
        return "\(minutes)м"
    }
}
"""

content = content.replace("\n}", new_methods)

# Insert the call in the View
target = """                    // Relapse Analysis Card
                    relapseAnalysisCard"""
replacement = """                    // Relapse Analysis Card
                    relapseAnalysisCard
                    
                    // Relapse History Card
                    relapseHistoryCard"""

content = content.replace(target, replacement)

with open("MyFocus/Views/Statistics/StatisticsView.swift", "w") as f:
    f.write(content)
