import SwiftUI

/// The Editor / Split / Reading segmented switch in the toolbar.
struct ModeSwitch: View {
    @Binding var mode: EditorMode
    let colors: RasterColors

    var body: some View {
        HStack(spacing: 0) {
            ForEach(EditorMode.allCases) { candidate in
                Button {
                    mode = candidate
                } label: {
                    Text(candidate.label)
                        .font(.system(size: 12, weight: mode == candidate ? .semibold : .regular))
                        .foregroundStyle(mode == candidate ? colors.inkStrong : colors.dim)
                        .padding(.horizontal, 13)
                        .padding(.vertical, 3)
                        .background(
                            RoundedRectangle(cornerRadius: 5)
                                .fill(mode == candidate ? colors.panel : .clear)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(2)
        .background(RoundedRectangle(cornerRadius: 7).fill(colors.bg))
        .overlay(RoundedRectangle(cornerRadius: 7).stroke(colors.border, lineWidth: 1))
    }
}

private extension EditorMode {
    var label: LocalizedStringKey {
        switch self {
        case .editor: return "Editor"
        case .split: return "Split"
        case .reading: return "Reading"
        }
    }
}
