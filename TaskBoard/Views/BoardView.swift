import SwiftUI

/// Where a dragged card would land: before a specific card, or at the end of a column.
struct DropTarget: Hashable {
    let status: TaskStatus
    let beforeID: String?
}

/// Stacks the columns vertically in portrait and side by side in landscape.
struct BoardView: View {
    let isLandscape: Bool
    /// Every drop zone currently under the finger. Card zones sit inside column zones, so several can be active at once.
    @State private var hovered: Set<DropTarget> = []

    private var activeTarget: DropTarget? {
        hovered.first { $0.beforeID != nil } ?? hovered.first
    }

    var body: some View {
        if isLandscape {
            HStack(alignment: .top, spacing: 10) {
                ForEach(TaskStatus.allCases) { status in
                    ColumnView(status: status, isLandscape: true, activeTarget: activeTarget, hovered: $hovered)
                }
            }
            .padding(.bottom, 16)
        } else {
            ScrollView {
                VStack(spacing: 18) {
                    ForEach(TaskStatus.allCases) { status in
                        ColumnView(status: status, isLandscape: false, activeTarget: activeTarget, hovered: $hovered)
                    }
                }
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
        }
    }
}

struct ColumnView: View {
    @Environment(TaskBoardStore.self) private var store
    let status: TaskStatus
    let isLandscape: Bool
    let activeTarget: DropTarget?
    @Binding var hovered: Set<DropTarget>

    private var endTarget: DropTarget { DropTarget(status: status, beforeID: nil) }
    private var isTargeted: Bool { activeTarget?.status == status }

    var body: some View {
        Group {
            if isLandscape {
                ScrollView { cards.padding(10) }
                    .scrollIndicators(.hidden)
            } else {
                cards.padding(.vertical, 6)
            }
        }
        .frame(maxWidth: .infinity)
        .background(background, in: .rect(cornerRadius: 16))
        .animation(.easeOut(duration: 0.15), value: isTargeted)
        .dropDestination(for: String.self) { ids, _ in
            drop(ids, before: nil)
        } isTargeted: { setHovered($0, endTarget) }
    }

    private var background: Color {
        if isTargeted { return Color.accentColor.opacity(0.08) }
        return isLandscape ? Color(.systemGray5) : .clear
    }

    private var cards: some View {
        let items = store.tasks(in: status)
        return VStack(spacing: 0) {
            HStack {
                Text(status.title.uppercased())
                Spacer()
                Text("\(items.count)")
                    .contentTransition(.numericText())
            }
            .font(.caption.weight(.semibold))
            .kerning(0.5)
            .foregroundStyle(.secondary)
            .padding([.horizontal, .top], 4)
            .padding(.bottom, 8)

            ForEach(items) { task in
                let target = DropTarget(status: status, beforeID: task.id)
                TaskCardView(task: task)
                    .overlay(alignment: .top) {
                        if activeTarget == target {
                            InsertionLine().offset(y: -5.5)
                        }
                    }
                    .padding(.bottom, 8)
                    .contentShape(.rect)
                    .dropDestination(for: String.self) { ids, _ in
                        drop(ids, before: task.id)
                    } isTargeted: { setHovered($0, target) }
            }

            if activeTarget == endTarget {
                InsertionLine()
            } else if items.isEmpty && !isTargeted {
                DropPlaceholder()
            }
        }
        .frame(maxWidth: .infinity, alignment: .top)
    }

    private func setHovered(_ isOver: Bool, _ target: DropTarget) {
        if isOver { hovered.insert(target) } else { hovered.remove(target) }
    }

    private func drop(_ ids: [String], before targetID: String?) -> Bool {
        hovered.removeAll()
        guard let id = ids.first, store.tasks.contains(where: { $0.id == id }) else { return false }
        withAnimation(.snappy) {
            store.move(id, to: status, before: targetID)
        }
        return true
    }
}

private struct InsertionLine: View {
    var body: some View {
        Capsule()
            .fill(Color.accentColor)
            .frame(height: 3)
            .padding(.horizontal, 4)
    }
}

private struct DropPlaceholder: View {
    var body: some View {
        Text("Drop tasks here")
            .font(.caption)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, minHeight: 46)
            .overlay {
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(Color(.systemGray3), style: StrokeStyle(lineWidth: 2, dash: [6, 4]))
            }
    }
}
