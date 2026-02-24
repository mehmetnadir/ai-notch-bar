import SwiftUI

@main
struct NotchHubApp: App {
  @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

  var body: some Scene {
    MenuBarExtra("NotchHub", systemImage: "rectangle.topthird.inset.filled") {
      VStack(spacing: 8) {
        Text("NotchHub")
          .font(.headline)
        Divider()

        if let manager = appDelegate.manager {
          ForEach(manager.activeProviderNames, id: \.self) { name in
            HStack {
              Circle()
                .fill(.green)
                .frame(width: 8, height: 8)
              Text(name)
            }
          }
          if manager.activeProviderNames.isEmpty {
            Text("Aktif provider yok")
              .foregroundStyle(.secondary)
          }
        }

        Divider()
        Button("Çıkış") {
          NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q")
      }
      .padding(8)
    }
  }
}
