import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var vm = SettingsViewModel()

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Profile")) {
                    TextField("Name", text: $vm.displayName)
                    TextField("City", text: $vm.city)
                    Button("Save") {
                        Task { await vm.save(); dismiss() }
                    }
                    .disabled(vm.displayName.isEmpty)
                }

                Section {
                    Button("Sign Out", role: .destructive) {
                        vm.signOut()
                        dismiss()
                    }
                }

                Section {
                    Button("Delete Account", role: .destructive) {
                        Task { await vm.deleteAccount(); dismiss() }
                    }
                }
            }
            .navigationTitle("Settings")
            .overlay {
                if vm.isBusy { ProgressView().scaleEffect(1.3) }
            }
            .alert("Error", isPresented: Binding<Bool>(
                get: { vm.error != nil },
                set: { _ in vm.error = nil })
            ) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(vm.error ?? "")
            }
        }
    }
}
