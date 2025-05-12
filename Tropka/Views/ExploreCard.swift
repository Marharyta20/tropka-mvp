import SwiftUI

struct ExploreCard: View {
  let route: Route

  var body: some View {
    ZStack(alignment: .leading) {
      RoundedRectangle(cornerRadius: 16)
        .fill(Color(white: 0.95))
      HStack(spacing: 12) {
        AsyncImage(url: route.thumbnailURL) { phase in
          switch phase {
          case .empty:
            ProgressView().frame(width: 80, height: 80)
          case .failure:
            Image(systemName: "photo")
              .resizable()
              .scaledToFill()
              .frame(width: 80, height: 80)
          case .success(let img):
            img.resizable()
               .scaledToFill()
               .frame(width: 80, height: 80)
               .clipped()
          @unknown default:
            EmptyView()
          }
        }

        VStack(alignment: .leading, spacing: 4) {
          Text(route.title)
            .font(.headline)

          Text("by \(route.author)")
            .font(.subheadline)
            .foregroundColor(.secondary)

          HStack(spacing: 4) {
            Image(systemName: "star.fill")
              .font(.caption)
            Text(String(format: "%.1f", route.rating))
              .font(.caption)

            Text("·")

            Text(route.isFree
                 ? "Free"
                 : String(format: "€%.2f", route.price ?? 0))
              .font(.caption)

            Text("·")

            Text("\(route.stops.count) stops")  // считаем здесь
              .font(.caption)
          }
          .foregroundColor(.secondary)
        }

        Spacer()
      }
      .padding(12)
    }
    .frame(height: 100)
  }
}
