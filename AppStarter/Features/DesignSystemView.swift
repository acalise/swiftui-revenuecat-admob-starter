import SwiftUI

/// A live reference for the design system.
///
/// Useful for checking a component in both appearances without leaving the app,
/// and as a copy-paste source when building a new screen. Delete it once you
/// know the pieces, nothing depends on it.
struct DesignSystemView: View {
    @State private var toggleOn = false
    @State private var sliderValue = 0.6
    @State private var text = ""
    @State private var isLoading = false

    var body: some View {
        ScreenScrollView(title: "Design", subtitle: "Everything reads from Theme.swift") {
            buttonsSection
            fieldsSection
            surfacesSection
            statusSection
            typographySection

            // Collapses to nothing when ads are off or the user subscribes.
            BannerAdView().padding(.top, 20)
        }
    }

    @ViewBuilder
    private var buttonsSection: some View {
        SectionLabel("Buttons")
        Card {
            Button("Primary action") { Haptics.tap() }
                .buttonStyle(PrimaryButtonStyle())

            Button("Secondary action") { Haptics.tapLight() }
                .buttonStyle(SecondaryButtonStyle())

            Button(isLoading ? "Working…" : "Press to load") {
                Haptics.tap()
                isLoading = true
                Task {
                    try? await Task.sleep(for: .seconds(1.5))
                    isLoading = false
                    Haptics.success()
                }
            }
            .buttonStyle(PrimaryButtonStyle(isEnabled: !isLoading))
            .disabled(isLoading)

            HStack(spacing: 8) {
                Button("Bordered") {}.buttonStyle(.bordered)
                Button("Plain") {}.buttonStyle(.plain).foregroundStyle(Theme.accent)
                Button("Destructive", role: .destructive) {}.buttonStyle(.bordered)
            }
            .font(.system(size: 15))
        }
    }

    @ViewBuilder
    private var fieldsSection: some View {
        SectionLabel("Controls")
        Card {
            TextField("you@example.com", text: $text)
                .textFieldStyle(.plain)
                .keyboardType(.emailAddress)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .padding(12)
                .background(Theme.surfaceSecondary)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            Toggle("Enable notifications", isOn: $toggleOn)
                .tint(Theme.accent)
                .font(.system(size: 16))
                .foregroundStyle(Theme.label)

            VStack(alignment: .leading, spacing: 6) {
                Text("Slider, \(Int(sliderValue * 100))%")
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.secondaryLabel)
                Slider(value: $sliderValue).tint(Theme.accent)
            }
        }
    }

    @ViewBuilder
    private var surfacesSection: some View {
        SectionLabel("Surfaces")
        Card {
            Text("Card")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Theme.label)
            Text("Cards sit on `Theme.background` and group related content. Nest a `surfaceSecondary` block inside for a second elevation.")
                .font(.system(size: 14))
                .foregroundStyle(Theme.secondaryLabel)

            HStack(spacing: 12) {
                surfaceSwatch("surface", Theme.surface)
                surfaceSwatch("surfaceSecondary", Theme.surfaceSecondary)
            }
        }
    }

    private func surfaceSwatch(_ label: String, _ color: Color) -> some View {
        VStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(color)
                .frame(height: 44)
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(Theme.separator, lineWidth: 1)
                )
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(Theme.secondaryLabel)
        }
    }

    @ViewBuilder
    private var statusSection: some View {
        SectionLabel("Status colors")
        Card {
            statusRow("Success", Theme.success, "checkmark.circle.fill")
            statusRow("Warning", Theme.warning, "exclamationmark.triangle.fill")
            statusRow("Danger", Theme.danger, "xmark.octagon.fill")
        }
    }

    private func statusRow(_ label: String, _ color: Color, _ symbol: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: symbol).foregroundStyle(color)
            Text(label).foregroundStyle(Theme.label)
            Spacer()
        }
        .font(.system(size: 15))
    }

    @ViewBuilder
    private var typographySection: some View {
        SectionLabel("Type scale")
        Card {
            Group {
                Text("Large title, 32 bold").font(.system(size: 32, weight: .bold))
                Text("Title, 22 semibold").font(.system(size: 22, weight: .semibold))
                Text("Body, 16 regular").font(.system(size: 16))
                Text("Caption, 13 regular").font(.system(size: 13))
            }
            .foregroundStyle(Theme.label)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

#Preview {
    DesignSystemView()
}
