import SwiftUI

struct ExploreView: View {
    @StateObject private var vm = ExploreViewModel()
    
    @State private var searchText = ""
    @State private var showOnlyFree = false
    @State private var selectedTag: String?
    @State private var sortBy: SortOption = .rating
    
    enum SortOption: String, CaseIterable, Identifiable {
        case rating = "Rating"
        case price = "Price"
        var id: String { self.rawValue }
    }
    
    // — Фильтрованный массив
    var filteredRoutes: [TourRoute] {
        var result = vm.routes
        
        // Фильтр: поиск
        if !searchText.isEmpty {
            result = result.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
        }
        // Фильтр: бесплатные
        if showOnlyFree {
            // ИСПРАВЛЕНИЕ: Проверяем цену напрямую, если свойства isActuallyFree нет
            result = result.filter { ($0.price ?? 0) < 0.01 }
        }
        // Фильтр: по тегу
        if let tag = selectedTag {
            result = result.filter { $0.tags.contains(tag) }
        }
        // Сортировка
        switch sortBy {
        case .rating:
            result = result.sorted { $0.rating > $1.rating }
        case .price:
            result = result.sorted { ($0.price ?? 0) < ($1.price ?? 0) }
        }
        return result
    }
    
    // — Все доступные теги из списка маршрутов
    var allTags: [String] {
        Set(vm.routes.flatMap { $0.tags }).sorted()
    }
    
    var body: some View {
        // ИСПРАВЛЕНИЕ: NavigationStack вместо NavigationView
        NavigationStack {
            VStack(spacing: 10) {
                // ——— Search bar
                TextField("Search by route name", text: $searchText)
                    .padding(10)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                    .padding(.horizontal, 16)
                
                // ——— Filters row
                HStack(spacing: 8) {
                    Toggle("Free only", isOn: $showOnlyFree)
                        .font(.subheadline)
                    
                    Picker("Sort by", selection: $sortBy) {
                        ForEach(SortOption.allCases) { sort in
                            Text(sort.rawValue)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 170)
                    
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 4)
                
                // ——— Tag filter row
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        Button("All") {
                            selectedTag = nil
                        }
                        .font(.caption)
                        .foregroundColor(selectedTag == nil ? .white : .blue)
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .background(selectedTag == nil ? Color.blue : Color(.systemGray5))
                        .clipShape(Capsule())
                        
                        ForEach(allTags, id: \.self) { tag in
                            Button(tag.capitalized) {
                                selectedTag = tag
                            }
                            .font(.caption)
                            .foregroundColor(selectedTag == tag ? .white : .blue)
                            .padding(.horizontal, 12).padding(.vertical, 6)
                            .background(selectedTag == tag ? Color.blue : Color(.systemGray5))
                            .clipShape(Capsule())
                        }
                    }
                    .padding(.horizontal, 16)
                }
                
                // ——— Main list
                Group {
                    if vm.isLoading {
                        ProgressView("Loading…")
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                    // ИСПРАВЛЕНИЕ: vm.errorMessage вместо vm.errorMsg
                    else if let msg = vm.errorMessage {
                        ErrorBlock(message: msg) { vm.loadRoutes() }
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 24) {
                                ForEach(filteredRoutes) { r in
                                    // NavigationLink для NavigationStack
                                    NavigationLink(destination: TourDetailsView(route: r)) {
                                        ExploreCard(route: r)
                                    }
                                    .buttonStyle(.plain)
                                }
                                
                                if filteredRoutes.isEmpty {
                                    Text("No routes found.")
                                        .foregroundColor(.secondary)
                                        .padding(.top, 50)
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 12)
                            .padding(.bottom, 32)
                        }
                        .refreshable { vm.loadRoutes() }
                    }
                }
                .animation(.default, value: filteredRoutes)
            }
            .navigationTitle("Explore")
        }
        .onAppear {
            if vm.routes.isEmpty { vm.loadRoutes() }
        }
    }
}

private struct ErrorBlock: View {
    let message: String
    let retry: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.largeTitle)
                .foregroundColor(.orange)
            
            Text(message)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button("Retry", action: retry)
                .buttonStyle(.borderedProminent)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
