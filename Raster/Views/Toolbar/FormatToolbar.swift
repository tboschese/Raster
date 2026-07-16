import SwiftUI

/// The Bold/Italic/Strikethrough/Heading/Link/List/Task/Quote/Code/Table
/// button row. Disabled while editing isn't meaningful (no document open).
struct FormatToolbar: View {
    let colors: RasterColors
    let isEnabled: Bool
    let onCommand: (FormatCommand) -> Void

    var body: some View {
        HStack(spacing: 1) {
            ForEach(FormatCommand.allCases) { command in
                Button {
                    onCommand(command)
                } label: {
                    Text(command.icon)
                        .font(.system(size: 12.5, design: .monospaced))
                        .foregroundStyle(colors.dim)
                        .frame(minWidth: 26, minHeight: 26)
                }
                .buttonStyle(.plain)
                .help(command.tooltip)
                .contentShape(Rectangle())
                .background(RoundedRectangle(cornerRadius: 6).fill(Color.clear))
            }
        }
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.4)
    }
}

private extension FormatCommand {
    var icon: String {
        switch self {
        case .bold: return "B"
        case .italic: return "I"
        case .strikethrough: return "S"
        case .heading: return "H"
        case .link: return "↗"
        case .list: return "≡"
        case .task: return "☑"
        case .quote: return "❝"
        case .codeBlock: return "</>"
        case .table: return "⊞"
        }
    }

    var tooltip: LocalizedStringKey {
        switch self {
        case .bold: return "Bold ⌘B"
        case .italic: return "Italic ⌘I"
        case .strikethrough: return "Strikethrough"
        case .heading: return "Heading"
        case .link: return "Link ⌘K"
        case .list: return "List"
        case .task: return "Task list"
        case .quote: return "Quote"
        case .codeBlock: return "Code block"
        case .table: return "Table"
        }
    }
}
