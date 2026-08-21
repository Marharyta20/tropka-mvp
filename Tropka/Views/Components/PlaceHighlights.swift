import SwiftUI

// MARK: - PlaceHighlight

/// One thing worth knowing about a place before walking to it.
struct PlaceHighlight: Identifiable, Hashable {
    let label: String
    let icon: String
    var id: String { label }
}

// MARK: - Parsing

/// Turns `places.google_maps_attributes` into a short, ordered list.
///
/// That column holds roughly thirty thousand facts across the catalogue — under
/// eighteen keys covering atmosphere, amenities, who goes there, whether dogs
/// are allowed — and until now the app displayed none of it. It is also the only
/// large field that says something a category chip and an address do not.
///
/// Two things are deliberately not passed through:
///
/// **The choice.** Most of what Google records is irrelevant to someone walking
/// across a city — payment methods, drive-throughs, white glove service. Only
/// the entries below are shown, in the order below, which is a priority order:
/// what a place feels like first, then what you can do there, then who it suits.
///
/// **The wording.** Google's own values are inconsistent — "Cosy" and "Cozy",
/// "Takeaway" and "Takeout", "Restroom" and "Public toilet" and "Toilet" all
/// occur in this one catalogue — so every variant maps to one label here.
enum PlaceHighlights {

    private static let table: [(match: Set<String>, label: String, icon: String)] = [
        // What it feels like
        (["cosy", "cozy"],                          "Cosy",               "flame"),
        (["historic"],                              "Historic",           "building.columns"),
        (["quiet"],                                 "Quiet",              "speaker.slash"),
        (["romantic"],                              "Romantic",           "heart"),
        (["trendy", "trending"],                    "Trendy",             "sparkles"),
        (["upscale"],                               "Upscale",            "crown"),
        // What you can do there
        (["outdoor seating"],                       "Outdoor seating",    "sun.max"),
        (["rooftop seating"],                       "Rooftop",            "building.2"),
        (["fireplace"],                             "Fireplace",          "flame.fill"),
        (["live music", "live performances"],       "Live music",         "music.note"),
        (["great coffee"],                          "Great coffee",       "cup.and.saucer"),
        (["great wine list"],                       "Great wine",         "wineglass"),
        (["great cocktails"],                       "Great cocktails",    "wineglass.fill"),
        (["great beer selection"],                  "Great beer",         "mug.fill"),
        (["great dessert"],                         "Great dessert",      "birthday.cake"),
        // Who it suits
        (["locals"],                                "Popular with locals", "person.2"),
        (["good for working on laptop"],            "Good for laptops",   "laptopcomputer"),
        (["solo dining"],                           "Fine on your own",   "person"),
        (["vegan options"],                         "Vegan options",      "leaf"),
        (["vegetarian options"],                    "Vegetarian options", "leaf.fill"),
        (["dogs allowed", "dogs allowed inside", "dog park"], "Dogs allowed", "pawprint"),
        (["good for kids", "family friendly", "family-friendly"], "Good for kids",
         "figure.2.and.child.holdinghands"),
        // Practicalities a walker actually needs
        (["free wi-fi", "wi-fi"],                   "Wi-Fi",              "wifi"),
        (["public toilet", "public restroom", "toilet", "restroom"], "Toilet", "toilet"),
        (["wheelchair accessible entrance", "wheelchair-accessible entrance"],
         "Step-free entrance", "figure.roll")
    ]

    /// Six is the point where a row of chips stops being scannable and starts
    /// being a wall — and the table is ordered, so the six that survive are the
    /// six worth keeping.
    static let limit = 6

    static func from(json: String?) -> [PlaceHighlight] {
        guard let json,
              let data = json.data(using: .utf8),
              let parsed = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return [] }

        // Flatten every key's values into one lowercased set; which key a fact
        // arrived under does not matter once it is on screen.
        var present = Set<String>()
        for value in parsed.values {
            guard let list = value as? [String] else { continue }
            for entry in list {
                present.insert(entry.trimmingCharacters(in: .whitespaces).lowercased())
            }
        }
        guard !present.isEmpty else { return [] }

        return table
            .filter { !$0.match.isDisjoint(with: present) }
            .prefix(limit)
            .map { PlaceHighlight(label: $0.label, icon: $0.icon) }
    }
}

// MARK: - View

struct PlaceHighlightsRow: View {
    let highlights: [PlaceHighlight]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Good to know")
                .font(.caption.bold())
                .foregroundColor(.secondary)

            // Wraps rather than scrolls: a horizontal strip hides whatever does
            // not fit, and the point of these is to be read at a glance.
            FlowLayout(spacing: 8) {
                ForEach(highlights) { highlight in
                    Label(highlight.label, systemImage: highlight.icon)
                        .font(.caption)
                        .foregroundColor(.primary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color(.systemGray6), in: Capsule())
                }
            }
        }
    }
}

// MARK: - Flow layout

/// Lays chips out left to right and wraps to the next line, which is what an
/// `HStack` cannot do and a `ScrollView` should not have to.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var origin = CGPoint.zero
        var lineHeight: CGFloat = 0
        var totalHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if origin.x > 0, origin.x + size.width > maxWidth {
                origin.x = 0
                origin.y += lineHeight + spacing
                lineHeight = 0
            }
            origin.x += size.width + spacing
            lineHeight = max(lineHeight, size.height)
            totalHeight = origin.y + lineHeight
        }

        return CGSize(width: maxWidth == .infinity ? origin.x : maxWidth, height: totalHeight)
    }

    func placeSubviews(in bounds: CGRect,
                       proposal: ProposedViewSize,
                       subviews: Subviews,
                       cache: inout ()) {
        var origin = bounds.origin
        var lineHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if origin.x > bounds.minX, origin.x + size.width > bounds.maxX {
                origin.x = bounds.minX
                origin.y += lineHeight + spacing
                lineHeight = 0
            }
            subview.place(at: origin, proposal: ProposedViewSize(size))
            origin.x += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
    }
}

#Preview {
    PlaceHighlightsRow(highlights: [
        PlaceHighlight(label: "Cosy", icon: "flame"),
        PlaceHighlight(label: "Great coffee", icon: "cup.and.saucer"),
        PlaceHighlight(label: "Popular with locals", icon: "person.2"),
        PlaceHighlight(label: "Good for laptops", icon: "laptopcomputer"),
        PlaceHighlight(label: "Dogs allowed", icon: "pawprint"),
        PlaceHighlight(label: "Toilet", icon: "toilet")
    ])
    .padding()
}
