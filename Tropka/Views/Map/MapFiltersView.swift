import SwiftUI

/// Simple list of category filters for the map.
struct MapFiltersView: View {
    @Binding var selectedCategories: Set<PlaceCategory>
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("Categories") {
                    ForEach(PlaceCategory.allCases, id: \.self) { category in
                        HStack {
                            Label(category.rawValue.capitalized,
                                  systemImage: category.icon)
                                .foregroundColor(Color(category.color))

                            Spacer()

                            if selectedCategories.contains(category) {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if selectedCategories.contains(category) {
                                selectedCategories.remove(category)
                            } else {
                                selectedCategories.insert(category)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Filter Map")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .navigationBarTrailing) { Button("Done") { dismiss() } } }
        }
    }
}
