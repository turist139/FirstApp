import SwiftUI

struct MotivationEditView: View {
    @ObservedObject var settings = MotivationSettings.shared
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            List {
                Section(header: Text("Порядок категорий (перетащите)").foregroundColor(.white.opacity(0.5))) {
                    ForEach($settings.categories) { $category in
                        NavigationLink(destination: CategoryEditView(category: $category)) {
                            HStack {
                                Image(systemName: category.icon)
                                    .foregroundColor(Color(hex: category.colorHex))
                                Text(category.title)
                                    .foregroundColor(.white)
                                Spacer()
                                Text("\(category.items.count) шт.")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.5))
                            }
                        }
                    }
                    .onMove { source, destination in
                        settings.categories.move(fromOffsets: source, toOffset: destination)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Редактирование")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Готово") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    EditButton()
                }
            }
            .preferredColorScheme(.dark)
        }
    }
}

struct CategoryEditView: View {
    @Binding var category: MotivationCategory
    @State private var newItemText: String = ""
    
    var body: some View {
        List {
            Section(header: Text("Существующие элементы")) {
                ForEach($category.items) { $item in
                    TextField("Элемент", text: $item.text, axis: .vertical)
                        .foregroundColor(.white)
                }
                .onDelete { indexSet in
                    category.items.remove(atOffsets: indexSet)
                }
                .onMove { source, destination in
                    category.items.move(fromOffsets: source, toOffset: destination)
                }
            }
            
            Section(header: Text("Добавить новый")) {
                HStack {
                    TextField("Новая мысль...", text: $newItemText, axis: .vertical)
                        .foregroundColor(.white)
                    
                    Button(action: {
                        let trimmed = newItemText.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !trimmed.isEmpty {
                            category.items.append(MotivationItem(text: trimmed))
                            newItemText = ""
                        }
                    }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                            .foregroundColor(.cyan)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(category.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                EditButton()
            }
        }
        .preferredColorScheme(.dark)
    }
}
