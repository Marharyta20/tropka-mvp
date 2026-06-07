import SwiftUI

// TestView — quick smoke test using Supabase instead of Firestore
struct TestView: View {
    @State private var result = "Fetching…"

    var body: some View {
        Text(result)
            .onAppear {
                Task {
                    do {
                        struct IDRow: Decodable { let id: String }
                        let rows: [IDRow] = try await supabase
                            .from("routes")
                            .select("id")
                            .limit(5)
                            .execute()
                            .value
                        result = "routes → \(rows.map(\.id))"
                    } catch {
                        result = "Error: \(error)"
                    }
                }
            }
    }
}
