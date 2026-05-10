import SwiftUI
import UIKit

struct GlassCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(16)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(Theme.cardBorder, lineWidth: 1)
            )
    }
}

struct GlassButtonStyle: ButtonStyle {
    var tint: Color = Theme.accent

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.bodyFont(14))
            .foregroundStyle(.white)
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            .background(
                LinearGradient(
                    colors: [tint.opacity(0.6), tint.opacity(0.25)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: Capsule()
            )
            .overlay(
                Capsule().strokeBorder(Color.white.opacity(0.25), lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.18), value: configuration.isPressed)
    }
}

struct SectionHeader: View {
    let title: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil
    var destination: AnyView? = nil

    var body: some View {
        HStack {
            Text(title)
                .font(Theme.titleFont(22))
                .foregroundStyle(.white)

            Spacer()

            if let destination, let actionTitle {
                NavigationLink(actionTitle) {
                    destination
                }
                .font(Theme.bodyFont(14))
                .foregroundStyle(Theme.accent)
            } else if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .font(Theme.bodyFont(14))
                    .foregroundStyle(Theme.accent)
            }
        }
    }
}

struct PosterCard: View {
    let item: MediaItem

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            AsyncImage(url: item.imageURL) { phase in
                if let image = phase.image {
                    image
                        .resizable()
                        .scaledToFill()
                } else {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color.white.opacity(0.15), Color.white.opacity(0.04)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .overlay(
                            Image(systemName: "film")
                                .font(.system(size: 28, weight: .semibold))
                                .foregroundStyle(Color.white.opacity(0.5))
                        )
                }
            }
            .frame(width: 130, height: 195)
            .clipped()

            VStack(alignment: .leading, spacing: 6) {
                Text(item.title)
                    .font(Theme.bodyFont(12))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text(item.subtitle)
                    .font(Theme.bodyFont(10))
                    .foregroundStyle(Theme.muted)
            }
            .padding(10)
            .background(
                LinearGradient(
                    colors: [Color.black.opacity(0.75), Color.black.opacity(0.05)],
                    startPoint: .bottom,
                    endPoint: .top
                )
            )

            if let progress = item.progress {
                ProgressBar(value: progress)
                    .frame(height: 4)
                    .padding([.horizontal, .bottom], 10)
                    .offset(y: -4)
            }
        }
        .frame(width: 130, height: 195)
        .background(Color.black.opacity(0.2))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
        )
    }
}

struct ProgressBar: View {
    let value: Double

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let clamped = min(max(value, 0), 1)

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.2))
                Capsule()
                    .fill(Theme.accent)
                    .frame(width: width * clamped)
            }
        }
    }
}

struct LabeledTextField: View {
    let title: String
    @Binding var text: String
    var keyboard: UIKeyboardType = .default

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(Theme.bodyFont(12))
                .foregroundStyle(Theme.muted)
            TextField(title, text: $text)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .keyboardType(keyboard)
                .padding(12)
                .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
                )
        }
    }
}

struct LabeledSecureField: View {
    let title: String
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(Theme.bodyFont(12))
                .foregroundStyle(Theme.muted)
            SecureField(title, text: $text)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .padding(12)
                .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
                )
        }
    }
}

struct MediaRow: View {
    let title: String
    let items: [MediaItem]
    let seeAllDestination: AnyView?

    init(title: String, items: [MediaItem], seeAllDestination: AnyView? = nil) {
        self.title = title
        self.items = items
        self.seeAllDestination = seeAllDestination
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(
                title: title,
                actionTitle: (seeAllDestination == nil || items.isEmpty) ? nil : "See all",
                action: nil,
                destination: seeAllDestination
            )

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(items) { item in
                        NavigationLink {
                            MediaDetailView(item: item)
                        } label: {
                            PosterCard(item: item)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}

struct HeroCarousel: View {
    let items: [MediaItem]
    let primaryActionTitle: String
    let secondaryActionTitle: String?

    var body: some View {
        TabView {
            ForEach(items) { item in
                NavigationLink {
                    MediaDetailView(item: item)
                } label: {
                    HeroCard(
                        item: item,
                        primaryActionTitle: primaryActionTitle,
                        secondaryActionTitle: secondaryActionTitle
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .automatic))
        .frame(height: 360)
    }
}

private struct HeroCard: View {
    let item: MediaItem
    let primaryActionTitle: String
    let secondaryActionTitle: String?

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            AsyncImage(url: item.imageURL) { phase in
                if let image = phase.image {
                    image
                        .resizable()
                        .scaledToFill()
                } else {
                    LinearGradient(
                        colors: [Color.white.opacity(0.15), Color.black.opacity(0.6)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()

            LinearGradient(
                colors: [Color.black.opacity(0.75), Color.black.opacity(0.05)],
                startPoint: .bottom,
                endPoint: .top
            )

            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)

            VStack(alignment: .leading, spacing: 12) {
                Text(item.title)
                    .font(Theme.titleFont(30))
                    .foregroundStyle(.white)
                Text(item.subtitle)
                    .font(Theme.bodyFont(14))
                    .foregroundStyle(Theme.muted)

                HStack(spacing: 12) {
                    Button(primaryActionTitle) {}
                        .buttonStyle(GlassButtonStyle(tint: Theme.accent))

                    if let secondaryActionTitle {
                        Button(secondaryActionTitle) {}
                            .buttonStyle(GlassButtonStyle(tint: Color.white.opacity(0.22)))
                    }
                }
            }
            .padding(24)
        }
        .padding(.horizontal, 4)
        .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
    }
}
