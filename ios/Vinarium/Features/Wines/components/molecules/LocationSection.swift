import MapKit
import SwiftUI

struct LocationSection: View {
    let placeName: String?
    let latitude: Double?
    let longitude: Double?
    let onTap: () -> Void

    private var coordinate: CLLocationCoordinate2D? {
        guard let latitude, let longitude else { return nil }
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    var body: some View {
        Section("Lieu de d\u{00E9}gustation") {
            if let coordinate {
                LocationCard(
                    coordinate: coordinate,
                    placeName: placeName,
                    onTap: onTap
                )
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            } else {
                Button(action: onTap) {
                    Label("Ajouter un lieu", systemImage: "mappin.and.ellipse")
                        .foregroundStyle(.tint)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

private struct LocationCard: View {
    let coordinate: CLLocationCoordinate2D
    let placeName: String?
    let onTap: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Map(initialPosition: .region(region)) {
                Marker("", coordinate: coordinate)
            }
            .frame(height: 200)
            .allowsHitTesting(false)

            Divider()

            HStack {
                Button(action: onTap) {
                    HStack(spacing: 4) {
                        Text(displayName)
                            .lineLimit(1)
                        Image(systemName: "chevron.forward")
                            .font(.caption.weight(.semibold))
                    }
                    .foregroundStyle(.tint)
                }
                .buttonStyle(.plain)

                Spacer()

                Button("Ajuster", action: onTap)
                    .foregroundStyle(.tint)
                    .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(.thinMaterial)
        }
        .clipShape(.rect(cornerRadius: 16))
    }

    private var displayName: String {
        if let placeName, !placeName.isEmpty { return placeName }
        return String(format: "%.4f, %.4f", coordinate.latitude, coordinate.longitude)
    }

    private var region: MKCoordinateRegion {
        MKCoordinateRegion(
            center: coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
        )
    }
}

#Preview("Card, place name") {
    LocationCard(
        coordinate: CLLocationCoordinate2D(latitude: 48.8769, longitude: 2.3370),
        placeName: "Paris - 9e Arr.",
        onTap: {}
    )
    .padding()
}

#Preview("Card, coordinates only") {
    LocationCard(
        coordinate: CLLocationCoordinate2D(latitude: 44.84, longitude: -0.58),
        placeName: nil,
        onTap: {}
    )
    .padding()
}

#Preview("With place name") {
    List {
        LocationSection(
            placeName: "Paris - 9e Arr.",
            latitude: 48.8769,
            longitude: 2.3370,
            onTap: {}
        )
    }
}

#Preview("Coordinates only") {
    List {
        LocationSection(
            placeName: nil,
            latitude: 44.84,
            longitude: -0.58,
            onTap: {}
        )
    }
}

#Preview("Empty") {
    List {
        LocationSection(placeName: nil, latitude: nil, longitude: nil, onTap: {})
    }
}
