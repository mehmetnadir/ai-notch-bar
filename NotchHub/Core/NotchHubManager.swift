import SwiftUI
import Combine

/// Tüm provider'ları yöneten merkezi orkestratör
final class NotchHubManager: ObservableObject {
  /// Kayıtlı provider'lar (AnyObject olarak tutulur, NotchProvider protokolü)
  @Published var providers: [AnyNotchProvider] = []
  /// Şu an öncelikli provider
  @Published var activeProvider: AnyNotchProvider?
  /// Genişletilmiş mod aktif mi
  @Published var isExpanded: Bool = false

  private var cancellables = Set<AnyCancellable>()

  /// Aktif provider isimlerini döndür (menü bar için)
  var activeProviderNames: [String] {
    providers
      .filter { $0.state != .inactive }
      .map { $0.name }
  }

  /// Provider ekle
  func register(_ provider: AnyNotchProvider) {
    providers.append(provider)
  }

  /// En yüksek öncelikli aktif provider'ı seç
  func resolveActiveProvider() {
    let sorted = providers
      .filter { $0.state != .inactive }
      .sorted { $0.priority.rawValue > $1.priority.rawValue }

    let newActive = sorted.first
    if activeProvider?.id != newActive?.id {
      activeProvider = newActive
    }
  }

  /// Tüm provider'ları başlat
  func start() {
    for provider in providers {
      provider.start()
    }
    // Her 1 saniyede aktif provider'ı yeniden değerlendir
    Timer.publish(every: 1.0, on: .main, in: .common)
      .autoconnect()
      .sink { [weak self] _ in
        self?.resolveActiveProvider()
      }
      .store(in: &cancellables)
  }

  /// Tüm provider'ları durdur
  func stop() {
    cancellables.removeAll()
    for provider in providers {
      provider.stop()
    }
  }
}

/// Type-erased NotchProvider wrapper
final class AnyNotchProvider: ObservableObject, Identifiable {
  let id: String
  let name: String
  private let _priority: () -> ProviderPriority
  private let _state: () -> ProviderState
  private let _compactView: () -> AnyView
  private let _expandedView: () -> AnyView
  private let _onActivate: () -> Void
  private let _start: () -> Void
  private let _stop: () -> Void

  var priority: ProviderPriority { _priority() }
  var state: ProviderState { _state() }

  init<P: NotchProvider>(_ provider: P) {
    self.id = provider.id
    self.name = provider.name
    self._priority = { provider.priority }
    self._state = { provider.state }
    self._compactView = { provider.compactView() }
    self._expandedView = { provider.expandedView() }
    self._onActivate = { provider.onActivate() }
    self._start = { provider.start() }
    self._stop = { provider.stop() }
  }

  func compactView() -> AnyView { _compactView() }
  func expandedView() -> AnyView { _expandedView() }
  func onActivate() { _onActivate() }
  func start() { _start() }
  func stop() { _stop() }
}
