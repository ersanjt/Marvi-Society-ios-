import MapKit
import SwiftUI
import UIKit

struct MapDiscoverView: View {
    @EnvironmentObject private var appState: AppState
    var onClose: (() -> Void)?

    @State private var cameraPosition: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 41.0082, longitude: 28.9784),
            span: MKCoordinateSpan(latitudeDelta: 0.12, longitudeDelta: 0.12)
        )
    )
    @State private var mapSelectedOffer: Offer?
    @State private var navigationOffer: Offer?

    private var mappableOffers: [Offer] {
        appState.offers.filter { $0.coordinate != nil }
    }

    private var nearbyOffers: [Offer] {
        appState.nearbyOffers()
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                Map(position: $cameraPosition, selection: $mapSelectedOffer) {
                    if let user = appState.userCoordinate {
                        Annotation("You", coordinate: CLLocationCoordinate2D(latitude: user.lat, longitude: user.lng)) {
                            ZStack {
                                Circle()
                                    .fill(MarviColor.blue.opacity(0.2))
                                    .frame(width: 44, height: 44)
                                Circle()
                                    .fill(MarviColor.blue)
                                    .frame(width: 14, height: 14)
                            }
                        }
                    }

                    ForEach(mappableOffers) { offer in
                        if let coordinate = offer.coordinate {
                            Annotation(offer.venue, coordinate: CLLocationCoordinate2D(latitude: coordinate.lat, longitude: coordinate.lng)) {
                                MapOfferPin(offer: offer, isSelected: mapSelectedOffer?.id == offer.id)
                            }
                            .tag(offer)
                        }
                    }
                }
                .mapStyle(.standard(elevation: .realistic))
                .ignoresSafeArea()

                VStack(spacing: 14) {
                    MapHeader(
                        title: appState.t(.nearYou),
                        subtitle: "\(mappableOffers.count) \(appState.t(.featuredEvents).lowercased())",
                        onClose: onClose,
                        onLocate: {
                            appState.refreshLocation()
                            centerOnUserOrIstanbul()
                        }
                    )
                    .padding(.horizontal, 16)
                    .padding(.top, 10)

                    Spacer()

                    VStack(spacing: 12) {
                        if appState.locationService.authorizationStatus == .denied {
                            LocationBanner(
                                message: appState.t(.mapLocationNeeded),
                                actionTitle: appState.t(.enableLocation)
                            ) {
                                if let url = URL(string: UIApplication.openSettingsURLString) {
                                    UIApplication.shared.open(url)
                                }
                            }
                        }

                        if let selected = mapSelectedOffer {
                            MapOfferSheet(
                                offer: selected,
                                distanceLabel: appState.distanceLabel(for: selected),
                                isAccepted: appState.isAccepted(selected),
                                open: { navigationOffer = selected },
                                accept: { appState.accept(selected) }
                            )
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                        } else if !nearbyOffers.isEmpty {
                            NearbyOffersStrip(
                                offers: nearbyOffers,
                                distanceLabel: { appState.distanceLabel(for: $0) },
                                select: { mapSelectedOffer = $0 }
                            )
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(item: $navigationOffer) { offer in
                OfferDetailView(offer: offer)
            }
            .onAppear {
                appState.refreshLocation()
                centerOnUserOrIstanbul()
            }
            .onChange(of: appState.userCoordinate?.lat) { _, _ in
                centerOnUserOrIstanbul()
            }
        }
    }

    private func centerOnUserOrIstanbul() {
        if let user = appState.userCoordinate {
            cameraPosition = .region(
                MKCoordinateRegion(
                    center: CLLocationCoordinate2D(latitude: user.lat, longitude: user.lng),
                    span: MKCoordinateSpan(latitudeDelta: 0.06, longitudeDelta: 0.06)
                )
            )
        }
    }
}

private struct MapHeader: View {
    let title: String
    let subtitle: String
    let onClose: (() -> Void)?
    let onLocate: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            if let onClose {
                Button(action: onClose) {
                    Image(systemName: "chevron.left")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(MarviColor.inkOnLight)
                        .frame(width: 40, height: 40)
                        .background(.white)
                        .clipShape(Circle())
                        .shadow(color: .black.opacity(0.14), radius: 12, y: 5)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Back to list")
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(MarviColor.inkOnLight)
                Text(subtitle)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(MarviColor.muted)
            }
            .lineLimit(1)

            Spacer()

            Button(action: onLocate) {
                Image(systemName: "location.fill")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(MarviGradient.brand)
                    .clipShape(Circle())
                    .shadow(color: MarviColor.rose.opacity(0.28), radius: 12, y: 5)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Refresh location")
        }
        .padding(12)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(.white.opacity(0.75), lineWidth: 1)
        )
    }
}

private struct MapOfferPin: View {
    @EnvironmentObject private var appState: AppState
    let offer: Offer
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: offer.collaborationModel == .instant ? "bolt.fill" : offer.category.icon)
                .font(.caption.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: isSelected ? 42 : 34, height: isSelected ? 42 : 34)
                .background(isSelected ? MarviGradient.brand : LinearGradient(colors: [offer.category.tint, offer.category.tint], startPoint: .top, endPoint: .bottom))
                .clipShape(Circle())
                .overlay(Circle().stroke(.white, lineWidth: 2))
                .shadow(color: .black.opacity(0.22), radius: 8, y: 4)

            if offer.collaborationModel == .instant {
                Text(appState.t(.now))
                    .font(.system(size: 9, weight: .bold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(MarviColor.gold)
                    .foregroundStyle(MarviColor.ink)
                    .clipShape(Capsule())
                        .shadow(color: .black.opacity(0.12), radius: 4, y: 2)
            }
        }
    }
}

private struct NearbyOffersStrip: View {
    @EnvironmentObject private var appState: AppState
    let offers: [Offer]
    let distanceLabel: (Offer) -> String?
    let select: (Offer) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(appState.t(.nearYou))
                .font(.caption.weight(.bold))
                .textCase(.uppercase)
                .foregroundStyle(MarviColor.muted)
                .padding(.leading, 4)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(offers) { offer in
                        Button {
                            select(offer)
                        } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Image(systemName: offer.collaborationModel.icon)
                                    Text(offer.collaborationModel.label(for: appState.preferredLanguage))
                                        .font(.caption2.weight(.bold))
                                }
                                .foregroundStyle(offer.category.tint)

                                Text(offer.title)
                                    .font(.subheadline.weight(.bold))
                                    .foregroundStyle(MarviColor.inkOnLight)
                                    .lineLimit(2)

                                if let distance = distanceLabel(offer) {
                                    Label(distance, systemImage: "location")
                                        .font(.caption)
                                        .foregroundStyle(MarviColor.graphite)
                                }
                            }
                            .frame(width: 180, alignment: .leading)
                            .padding(12)
                            .background(Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(14)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(.white.opacity(0.72), lineWidth: 1)
        )
    }
}

private struct MapOfferSheet: View {
    @EnvironmentObject private var appState: AppState
    let offer: Offer
    let distanceLabel: String?
    let isAccepted: Bool
    let open: () -> Void
    let accept: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(offer.title)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(MarviColor.inkOnLight)
                        .lineLimit(2)
                    Text("\(offer.venue) · \(offer.area)")
                        .font(.subheadline)
                        .foregroundStyle(MarviColor.graphite)
                }
                Spacer()
                if let distanceLabel {
                    Text(distanceLabel)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(MarviColor.emerald)
                }
            }

            HStack(spacing: 8) {
                StatusPill(text: offer.collaborationModel.label(for: appState.preferredLanguage), tint: MarviColor.gold, systemImage: offer.collaborationModel.icon)
                StatusPill(text: offer.valueLabel, tint: offer.category.tint, systemImage: "gift")
            }

            HStack(spacing: 10) {
                Button(action: open) {
                    Text(appState.t(.details))
                        .font(.subheadline.weight(.bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.plain)
                .foregroundStyle(MarviColor.inkOnLight)
                .background(Color.white.opacity(0.92))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                if !isAccepted {
                    Button(action: accept) {
                        Text(offer.collaborationModel == .instant ? appState.t(.useNow) : appState.t(.accept))
                            .font(.subheadline.weight(.bold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.white)
                    .background(MarviGradient.brand)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
            }
        }
        .padding(16)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(.white.opacity(0.75), lineWidth: 1)
        )
    }
}

private struct LocationBanner: View {
    let message: String
    let actionTitle: String
    let action: () -> Void

    var body: some View {
        HStack {
            Text(message)
                .font(.caption.weight(.semibold))
            Spacer()
            Button(actionTitle, action: action)
                .font(.caption.weight(.bold))
        }
        .foregroundStyle(MarviColor.ink)
        .padding(12)
        .background(MarviColor.gold.opacity(0.25))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}
