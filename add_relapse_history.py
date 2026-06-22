with open("MyFocus/Views/Statistics/StatisticsView.swift", "r") as f:
    content = f.read()

# Add State
content = content.replace("@State private var showImpulsesHistory: Bool = false", 
"@State private var showImpulsesHistory: Bool = false\n    @State private var showRelapseHistory: Bool = false")

# Add .sheet
sheet_anchor = """            .sheet(isPresented: $showImpulsesHistory) {
                impulsesHistorySheet
            }"""
sheet_replacement = sheet_anchor + """
            .sheet(isPresented: $showRelapseHistory) {
                relapseHistorySheet
            }"""
content = content.replace(sheet_anchor, sheet_replacement)

# Add button to relapseAnalysisCard
card_end = """                }
            }
        }
        .padding()"""
card_replacement = """                }
            }
            
            if !failLogs.isEmpty {
                Button(action: {
                    showRelapseHistory = true
                }) {
                    Text("Посмотреть историю срывов")
                        .font(.subheadline.bold())
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(10)
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
            }
        }
        .padding()"""
content = content.replace(card_end, card_replacement)

# Add relapseHistorySheet at the end of the file
relapse_sheet = """    
    private var relapseHistorySheet: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    let logs = failLogs.sorted { $0.date > $1.date }
                    
                    ForEach(logs) { log in
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                if let endDate = log.endDate, !Calendar.current.isDate(log.date, inSameDayAs: endDate) {
                                    Text("\\(formatShortDateAndTime(log.date)) — \\(formatShortDateAndTime(endDate))")
                                        .font(.headline)
                                        .foregroundColor(.white)
                                } else if let endDate = log.endDate, log.date != endDate {
                                    Text("\\(formatShortDateAndTime(log.date)) — \\(formatTime(endDate))")
                                        .font(.headline)
                                        .foregroundColor(.white)
                                } else {
                                    Text(formatShortDateAndTime(log.date))
                                        .font(.headline)
                                        .foregroundColor(.white)
                                }
                                
                                Spacer()
                                
                                if let duration = log.relapseDuration {
                                    Text(duration)
                                        .font(.caption.bold())
                                        .foregroundColor(.orange)
                                        .padding(.vertical, 4)
                                        .padding(.horizontal, 10)
                                        .background(Color.orange.opacity(0.15))
                                        .cornerRadius(8)
                                }
                            }
                            
                            Divider()
                                .background(Color.white.opacity(0.1))
                            
                            if let reason = log.failReason {
                                HStack(alignment: .top) {
                                    Text("Триггер:")
                                        .font(.caption)
                                        .foregroundColor(.white.opacity(0.5))
                                        .frame(width: 80, alignment: .leading)
                                    
                                    Text(reason)
                                        .font(.caption.bold())
                                        .foregroundColor(.red.opacity(0.8))
                                }
                            }
                            
                            if let notes = log.failNotes, !notes.isEmpty {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Заметки:")
                                        .font(.caption)
                                        .foregroundColor(.white.opacity(0.5))
                                    
                                    Text(notes)
                                        .font(.footnote)
                                        .foregroundColor(.white.opacity(0.8))
                                        .padding(10)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .background(Color.white.opacity(0.04))
                                        .cornerRadius(8)
                                }
                            }
                        }
                        .padding()
                        .background(Color.white.opacity(0.04))
                        .cornerRadius(16)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.white.opacity(0.06), lineWidth: 1)
                        )
                    }
                }
                .padding()
            }
            .navigationTitle("История срывов")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Закрыть") {
                        showRelapseHistory = false
                    }
                    .foregroundColor(.white)
                }
            }
            .withAmbientGlow()
        }
    }
}"""
content = content.replace("\n}", relapse_sheet)

with open("MyFocus/Views/Statistics/StatisticsView.swift", "w") as f:
    f.write(content)
