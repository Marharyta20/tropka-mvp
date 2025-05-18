//  ExploreCard.swift
import SwiftUI
import SDWebImageSwiftUI

struct ExploreCard: View {
    let route: Route
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            
            // MARK: Cover + author badge
            ZStack(alignment: .topLeading) {
                WebImage(url: route.thumbnailURL)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 200)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                
                Text(route.authorUID)   // пока UID → потом имя
                    .font(.footnote.bold())
                    .padding(.vertical, 4)
                    .padding(.horizontal, 10)
                    .background(Color.blue.opacity(0.9))
                    .foregroundColor(.white)
                    .clipShape(Capsule())
                    .padding(12)
            }
            
            // MARK: title
            Text(route.title)
                .font(.headline)
            
            // MARK: meta (rating • duration)
            HStack(spacing: 8) {
                Label(String(format: "%.1f", route.rating),
                      systemImage: "star.fill")
                Label(String(format: "%.1f h", route.duration),
                      systemImage: "clock")
            }
            .font(.caption)
            .foregroundColor(.secondary)
            
            // MARK: tags (первые 3)
            HStack {
                ForEach(route.tags.prefix(3), id: \.self) { tag in
                    Text(tag.capitalized)
                        .font(.caption2)
                        .padding(.vertical, 4)
                        .padding(.horizontal, 8)
                        .background(Color(.systemGray6))
                        .clipShape(Capsule())
                }
            }
            
            // MARK: buy / favourite
            HStack(spacing: 12) {
                Button( route.isFree ? "Get for €0.00"
                                     : String(format: "Buy for €%.2f",
                                              route.price ?? 0) ) {
                    // 👉 TODO: покупка / сохранение
                }
                .frame(maxWidth: .infinity)
                .font(.subheadline.bold())
                .padding(.vertical, 12)
                .background(Color.blue)
                .foregroundColor(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                
                Button { /* TODO: favourite */ } label: {
                    Image(systemName: "heart")
                        .font(.title3)
                        .padding(12)
                }
                .foregroundColor(.blue)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 6, y: 3)
        )
    }
}
