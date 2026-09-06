import SwiftUI

struct MetricCard: View {
    let title: String
    let value: String
    let footnote: String?
    let systemImage: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: systemImage)
                    .foregroundStyle(.appBlue)
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            Text(value)
                .font(.title2.bold())
                .monospacedDigit()
            if let footnote {
                Text(footnote)
                    .font(.caption2)
                    .foregroundStyle(.appTeal)
            }
        }
        .padding(14)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}
