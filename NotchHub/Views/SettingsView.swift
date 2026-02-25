import SwiftUI

/// Notch açık durumunda gösterilen ayarlar ekranı
struct SettingsView: View {
  @ObservedObject private var settings = AppSettings.shared
  var onClose: () -> Void

  var body: some View {
    VStack(spacing: 0) {
      // Başlık
      HStack {
        Image(systemName: "gearshape.fill")
          .font(.system(size: 12))
          .foregroundStyle(.white.opacity(0.6))
        Text("Ayarlar")
          .font(.system(size: 13, weight: .semibold))
          .foregroundStyle(.white)
        Spacer()
        Button(action: onClose) {
          Image(systemName: "xmark.circle.fill")
            .font(.system(size: 14))
            .foregroundStyle(.white.opacity(0.4))
        }
        .buttonStyle(.plain)
      }
      .padding(.horizontal, 16)
      .padding(.top, 8)
      .padding(.bottom, 6)

      Divider()
        .background(.white.opacity(0.1))

      ScrollView(.vertical, showsIndicators: false) {
        VStack(spacing: 14) {
          appearanceSection
          behaviorSection
          providerSection
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
      }
    }
  }

  // MARK: - Görünüm

  private var appearanceSection: some View {
    VStack(alignment: .leading, spacing: 8) {
      sectionHeader("Görünüm")

      // Çerçeve rengi
      VStack(alignment: .leading, spacing: 4) {
        Text("Çerçeve Rengi")
          .font(.system(size: 10))
          .foregroundStyle(.white.opacity(0.5))

        HStack(spacing: 6) {
          ForEach(AppSettings.presetColors, id: \.0) { name, color in
            Circle()
              .fill(color)
              .frame(width: 16, height: 16)
              .overlay(
                Circle()
                  .strokeBorder(
                    .white,
                    lineWidth: settings.borderColor.toHex() == color.toHex()
                      ? 2 : 0
                  )
              )
              .onTapGesture {
                settings.borderColor = color
              }
          }
        }
      }

      // Çerçeve kalınlığı
      settingsSlider(
        label: "Çerçeve Kalınlığı",
        value: $settings.borderWidth,
        range: 0.0...2.0,
        format: "%.1f"
      )

      // Çerçeve opaklığı
      settingsSlider(
        label: "Çerçeve Opaklığı",
        value: $settings.borderOpacity,
        range: 0.0...1.0,
        format: "%0.0f%%",
        multiplier: 100
      )

      // Genişlik
      settingsSlider(
        label: "Genişlik",
        value: $settings.expandedWidthRatio,
        range: 0.3...0.8,
        format: "%0.0f%%",
        multiplier: 100
      )
    }
  }

  // MARK: - Davranış

  private var behaviorSection: some View {
    VStack(alignment: .leading, spacing: 8) {
      sectionHeader("Davranış")

      // Tepki süresi
      settingsSlider(
        label: "Tepki Süresi",
        value: $settings.hoverDelay,
        range: 50...500,
        format: "%0.0f ms"
      )

      // Bildirim süresi
      settingsSlider(
        label: "Bildirim Süresi",
        value: $settings.peekDuration,
        range: 1...10,
        format: "%0.0f sn"
      )

      // Ses
      settingsToggle(
        label: "Sesler",
        isOn: $settings.soundEnabled
      )
    }
  }

  // MARK: - Provider'lar

  private var providerSection: some View {
    VStack(alignment: .leading, spacing: 8) {
      sectionHeader("Provider'lar")

      settingsToggle(
        label: "Claude Code",
        isOn: $settings.claudeEnabled
      )
    }
  }

  // MARK: - Yardımcılar

  private func sectionHeader(_ title: String) -> some View {
    Text(title)
      .font(.system(size: 11, weight: .semibold))
      .foregroundStyle(.white.opacity(0.7))
  }

  private func settingsSlider(
    label: String,
    value: Binding<Double>,
    range: ClosedRange<Double>,
    format: String,
    multiplier: Double = 1
  ) -> some View {
    VStack(alignment: .leading, spacing: 2) {
      HStack {
        Text(label)
          .font(.system(size: 10))
          .foregroundStyle(.white.opacity(0.5))
        Spacer()
        Text(String(format: format, value.wrappedValue * multiplier))
          .font(.system(size: 10, weight: .medium, design: .monospaced))
          .foregroundStyle(.white.opacity(0.6))
      }
      Slider(value: value, in: range)
        .controlSize(.mini)
        .tint(.white.opacity(0.5))
    }
  }

  private func settingsToggle(
    label: String,
    isOn: Binding<Bool>
  ) -> some View {
    HStack {
      Text(label)
        .font(.system(size: 10))
        .foregroundStyle(.white.opacity(0.5))
      Spacer()
      Toggle("", isOn: isOn)
        .toggleStyle(.switch)
        .controlSize(.mini)
        .labelsHidden()
    }
  }
}
