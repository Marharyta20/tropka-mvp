import SwiftUI
import SDWebImageSwiftUI
import MapboxMaps

// MARK: – Public entry
struct StopsBottomSheet: View {
    let stops: [Stop]
    @Binding var selectedIndex: Int
    var navButtonAction: (() -> Void)? = nil

    @State private var selectedStop: Stop?           // for detail card

    private let sheetHeight: CGFloat = 130

    var body: some View {
        guard !stops.isEmpty else { return AnyView(EmptyView()) }
        let stop = stops[selectedIndex]

        return AnyView(
            VStack(spacing: 0) {
                // Current stop card — tappable for detail
                Button { selectedStop = stop } label: {
                    HStack(spacing: 14) {
                        // Number badge
                        ZStack {
                            Circle().fill(selectedIndex == 0 ? Color.green
                                          : selectedIndex == stops.count - 1 ? Color.red
                                          : Color.blue)
                            Text("\(stop.orderIndex)")
                                .font(.headline.bold())
                                .foregroundColor(.white)
                        }
                        .frame(width: 40, height: 40)

                        VStack(alignment: .leading, spacing: 3) {
                            Text(stop.name)
                                .font(.headline)
                                .foregroundColor(.primary)
                            Text("≈ \(stop.timeSpent) min"
                                 + (stop.notes?.isEmpty == false ? " · \(stop.notes!)" : ""))
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                }
                .buttonStyle(.plain)

                Divider()

                // Prev / counter / Next + nav button
                HStack(spacing: 0) {
                    // Prev
                    Button {
                        withAnimation { selectedIndex = max(0, selectedIndex - 1) }
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.subheadline.bold())
                            .frame(width: 44, height: 44)
                    }
                    .disabled(selectedIndex == 0)

                    // Counter
                    Text("\(selectedIndex + 1) / \(stops.count)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)

                    // Next
                    Button {
                        withAnimation { selectedIndex = min(stops.count - 1, selectedIndex + 1) }
                    } label: {
                        Image(systemName: "chevron.right")
                            .font(.subheadline.bold())
                            .frame(width: 44, height: 44)
                    }
                    .disabled(selectedIndex == stops.count - 1)

                    // Start Navigation
                    if let action = navButtonAction {
                        Button(action: action) {
                            HStack(spacing: 5) {
                                Image(systemName: "arrow.triangle.turn.up.right.circle.fill")
                                Text("Navigate")
                                    .font(.subheadline.bold())
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(Color.blue)
                            .clipShape(Capsule())
                        }
                        .padding(.trailing, 12)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .sheet(item: $selectedStop) { s in
                StopDetailSheet(stop: s)
            }
        )
    }
}

// MARK: – Stop row
private struct StopRow: View {
    let stop: Stop
    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                if let url = stop.photoURL {
                    WebImage(url: url) { img in img.resizable().scaledToFill() }
                        placeholder: { Color(.systemGray5) }
                } else {
                    Color(.systemGray5)
                }
            }
            .frame(width: 56, height: 56)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 4) {
                Text("\(stop.orderIndex). \(stop.name)")
                    .font(.body).bold()
                    .foregroundColor(.primary)
                Text("≈ \(stop.timeSpent) min"
                     + (stop.notes?.isEmpty == false ? " · \(stop.notes!)" : ""))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: – Stop detail sheet
struct StopDetailSheet: View {
    let stop: Stop
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {

                    // Photo
                    if let url = stop.photoURL {
                        WebImage(url: url) { img in img.resizable().scaledToFill() }
                            placeholder: {
                                Rectangle().fill(Color(.systemGray5))
                                    .overlay(Image(systemName: "photo").foregroundColor(.secondary))
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 220)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    // Name + order badge
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(stop.name)
                                .font(.title2.bold())
                            if let notes = stop.notes, !notes.isEmpty {
                                Text(notes)
                                    .font(.body)
                                    .foregroundColor(.secondary)
                            }
                        }
                        Spacer()
                        Text("Stop \(stop.orderIndex)")
                            .font(.caption.bold())
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color.blue.opacity(0.12))
                            .foregroundColor(.blue)
                            .clipShape(Capsule())
                    }

                    Divider()

                    // Time
                    Label("Spend ≈ \(stop.timeSpent) min here", systemImage: "clock")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    // Mini map button
                    Button {
                        openInMaps(stop: stop)
                    } label: {
                        Label("Open in Maps", systemImage: "map")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                    .buttonStyle(.bordered)
                }
                .padding(20)
            }
            .navigationTitle(stop.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func openInMaps(stop: Stop) {
        let coords = stop.location
        if let url = URL(string: "maps://?q=\(stop.name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")&ll=\(coords.latitude),\(coords.longitude)") {
            UIApplication.shared.open(url)
        }
    }
}
