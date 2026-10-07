import SwiftUI

/// Palette-aware visual shell for dropdown panels in the main template.
struct MainTemplateDropdownPanel<Content: View>: View {
    let title: String
    let palette: GridlineTemplate.Palette
    let width: CGFloat
    let content: Content

    init(
        title: String,
        palette: GridlineTemplate.Palette,
        width: CGFloat = 285,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.palette = palette
        self.width = width
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .tracking(0.8)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.top, 5)
            content
        }
        .padding(10)
        .frame(width: width, alignment: .leading)
        .background(palette.surface, in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(palette.border, lineWidth: 1))
        .shadow(color: .black.opacity(0.38), radius: 14, x: 0, y: 8)
    }
}
