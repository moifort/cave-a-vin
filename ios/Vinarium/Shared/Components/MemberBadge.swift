import SwiftUI

/// The household member behind a bottle or a cellar move. It only shows up for the
/// others: what you did yourself needs no name.
struct MemberBadge: View {
    let name: String

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "person.fill")
            Text(name)
        }
        .font(.caption2)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(.quaternary, in: Capsule())
    }
}

#Preview {
    MemberBadge(name: "Marie")
        .padding()
}
