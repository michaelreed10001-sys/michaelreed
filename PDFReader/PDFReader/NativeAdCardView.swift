import SwiftUI

struct NativeAdCardView: View {
    var body: some View {
        HStack(spacing: 16) {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.blue.opacity(0.2))
                .frame(width: 60, height: 80)
                .overlay(Text("Ad").font(.caption).bold())
            VStack(alignment: .leading, spacing: 4) {
                Text("Sponsored PDF Tool")
                    .font(.headline)
                    .foregroundColor(.blue)
                Text("Create professional PDFs fast")
                    .font(.caption)
                Text("ad · via AdMob")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.blue.opacity(0.3), lineWidth: 1)
        )
    }
}
