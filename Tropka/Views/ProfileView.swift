import SwiftUI
import FirebaseAuth

struct ProfileView: View {
    @StateObject private var vm = ProfileViewModel()
    
    // MARK: - Tabs
    enum Tab: String, CaseIterable {
        case yourRoutes = "Your Routes"
        case reviews    = "Reviews"
        case following  = "Following"
    }

    @State private var selectedTab: Tab = .yourRoutes

    // Sample placeholders
    private var sampleRoutes: [String] = [
        "Hidden Cafés in Warsaw",
        "City Street Art Tour"
    ]
    private var sampleReviews: [(title: String, text: String)] = [
        ("Hidden Cafés in Warsaw", "Coffee here is top-notch!"),
        ("City Street Art Tour",    "Loved the colorful murals.")
    ]
    private var sampleFollowing: [String] = ["Anna G.", "Mia C.", "Noah A."]

    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                // MARK: — Header
                HStack(spacing: 12) {
   
                    // ← this pulls “profile-placeholder” from Assets.xcassets
                    Image("profile-placeholder")
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 64, height: 64)
                        .clipShape(Circle())

                    VStack(alignment: .leading, spacing: 4) {
//                        Text("Catherin Collins")
//                            .font(.title2).bold()
//                        Text("Berlin")
//                            .font(.subheadline)
//                            .foregroundColor(.secondary)
                        Text(vm.displayName).font(.title2).bold()
                        Text(vm.city).font(.subheadline).foregroundColor(.secondary)
                    }

                    Spacer()

                    Button(action: {
                        // TODO: settings action
                    }) {
                        Image(systemName: "gearshape")
                            .font(.title3)
                            .foregroundColor(.primary)
                    }
                }
                .padding(.horizontal)

                // MARK: — Segmented Control
                Picker("Tab", selection: $selectedTab) {
                    ForEach(Tab.allCases, id: \.self) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)

                // MARK: — Content
                ScrollView {
                    VStack(spacing: 12) {
                        switch selectedTab {
                        case .yourRoutes:
                            ForEach(sampleRoutes, id: \.self) { route in
                                ProfileRouteCell(title: route)
                            }

                        case .reviews:
                            ForEach(sampleReviews, id: \.title) { review in
                                ProfileReviewCell(title: review.title, text: review.text)
                            }

                        case .following:
                            ForEach(sampleFollowing, id: \.self) { name in
                                ProfileFollowingCell(name: name)
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                .navigationBarHidden(true)
            }
            .padding(.top)
        }
    }
}

// MARK: — Cells

private struct ProfileRouteCell: View {
    let title: String
    var body: some View {
        HStack {
            Image(systemName: "map")
                .frame(width: 40, height: 40)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(8)

            Text(title)
                .font(.headline)
                .lineLimit(1)

            Spacer()

            Button("Start") { }
                .buttonStyle(.borderedProminent)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
}

private struct ProfileReviewCell: View {
    let title: String
    let text: String
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title).font(.headline)
                Spacer()
                Image(systemName: "star.fill").foregroundColor(.yellow)
                Text("5")
            }
            Text(text)
                .font(.body)
                .foregroundColor(.secondary)
            HStack {
                Button("Edit") { }
                Spacer()
                Button("Delete") { }
                    .foregroundColor(.red)
            }
            .font(.caption)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.03), radius: 2, x: 0, y: 1)
    }
}

private struct ProfileFollowingCell: View {
    let name: String
    var body: some View {
        HStack {
            Image(systemName: "person.circle.fill")
                .resizable()
                .frame(width: 40, height: 40)
                .foregroundColor(.blue)

            Text(name)
                .font(.body)

            Spacer()

            Button("See Routes") { }
                .buttonStyle(.bordered)
            Button("Unfollow") { }
                .buttonStyle(.bordered)
                .tint(.red)
        }
        .padding(.vertical, 8)
    }
}

// MARK: — Preview

struct ProfileView_Previews: PreviewProvider {
    static var previews: some View {
        ProfileView()
    }
}
