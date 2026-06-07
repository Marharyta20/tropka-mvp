import Foundation
import Supabase

// Single shared Supabase client for the whole app.
// Add the package in Xcode:
//   File → Add Package Dependencies…
//   URL: https://github.com/supabase/supabase-swift
//   Product: Supabase

let supabase = SupabaseClient(
    supabaseURL: URL(string: "https://zhoaeejqsczwcldbonwj.supabase.co")!,
    supabaseKey: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inpob2FlZWpxc2N6d2NsZGJvbndqIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODAyODc0MzYsImV4cCI6MjA5NTg2MzQzNn0.uRrajc4dlLGGLyMFuImBvzS0kBUuDRWd1Bpran1xWe4",
    options: SupabaseClientOptions(
        auth: SupabaseClientOptions.AuthOptions(
            emitLocalSessionAsInitialSession: true
        )
    )
)
