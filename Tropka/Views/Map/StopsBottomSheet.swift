import SwiftUI
import SDWebImageSwiftUI
import FirebaseFirestore   // for GeoPoint → if you ever need

// MARK: – Public entry
struct StopsBottomSheet: View {
    let stops: [Stop]

    // collapsible state
    @State private var offsetY: CGFloat = 0           // current drag offset
    @State private var fullyExpanded = false          // snap flag

    // some constants
    private let minHeight: CGFloat = 90               // collapsed height
    private let maxHeightRatio: CGFloat = 0.55        // % of screen

    var body: some View {
        GeometryReader { geo in
            // total height available
            let maxHeight = geo.size.height * maxHeightRatio
            let finalOffset = fullyExpanded ? 0 : (maxHeight - minHeight)

            VStack(spacing: 0) {

                // drag handle
                Capsule()
                    .fill(Color.secondary)
                    .frame(width: 36, height: 4)
                    .padding(.top, 8)
                    .padding(.bottom, 4)

                // title
                HStack {
                    Text("Stops (\(stops.count))")
                        .font(.headline)
                    Spacer()
                }
                .padding(.horizontal)

                Divider()

                // list of stops
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(stops) { stop in
                            StopRow(stop: stop)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                }
            }
            .frame(width: geo.size.width,
                   height: maxHeight,
                   alignment: .top)
            .background(.ultraThinMaterial)               // iOS 15+ blur
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .offset(y: finalOffset + offsetY)             // drag position
            .gesture(
                DragGesture()
                    .onChanged { value in
                        // allow drag only in vertical bounds
                        offsetY = max(0, min(value.translation.height,
                                             maxHeight - minHeight))
                    }
                    .onEnded { value in
                        // snap logic
                        let threshold = (maxHeight - minHeight) * 0.3
                        if fullyExpanded {
                            // decide collapse
                            if value.translation.height > threshold {
                                fullyExpanded = false
                            }
                        } else {
                            // decide expand
                            if value.translation.height < -threshold {
                                fullyExpanded = true
                            }
                        }
                        // animate to snap
                        withAnimation(.spring()) {
                            offsetY = 0
                        }
                    }
            )
        }
        .ignoresSafeArea(.all, edges: .bottom)            // sheet over map
    }
}

// MARK: – Stop row (reuse the one from TourDetails or keep inline)
private struct StopRow: View {
    let stop: Stop

    var body: some View {
        HStack(spacing: 14) {
            WebImage(url: stop.photoURL)
                .resizable()
                .scaledToFill()
                .frame(width: 56, height: 56)
                .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 4) {
                Text("\(stop.orderIndex). \(stop.name)")
                    .font(.body).bold()

                Text("≈ \(stop.timeSpent) min"
                     + (stop.notes?.isEmpty == false ? " · \(stop.notes!)" : ""))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            Spacer()
        }
    }
}
