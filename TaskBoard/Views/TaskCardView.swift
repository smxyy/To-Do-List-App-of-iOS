import SwiftUI

struct TaskCardView: View {
    @Environment(TaskBoardStore.self) private var store
    let task: TaskItem

    private var isDone: Bool { task.status == .done }

    var body: some View {
        HStack(spacing: 10) {
            Button {
                withAnimation(.snappy) { store.toggle(task.id) }
            } label: {
                CompletionCircle(isDone: isDone)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isDone ? "Mark as not done" : "Mark as done")

            Text(task.title)
                .font(.subheadline)
                .foregroundStyle(isDone ? .secondary : .primary)
                .strikethrough(isDone)
                .frame(maxWidth: .infinity, alignment: .leading)

            GripIcon()
        }
        .padding(12)
        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 14))
        .shadow(color: .black.opacity(0.04), radius: 0, y: 1)
        .contentShape(.dragPreview, .rect(cornerRadius: 14))
        .draggable(task.id)
    }
}

private struct CompletionCircle: View {
    let isDone: Bool

    var body: some View {
        ZStack {
            if isDone {
                Circle().fill(Color(.systemGreen))
                Image(systemName: "checkmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white)
            } else {
                Circle().strokeBorder(Color(.systemGray3), lineWidth: 1.5)
            }
        }
        .frame(width: 20, height: 20)
        .padding(4)
        .contentShape(.circle)
    }
}

private struct GripIcon: View {
    var body: some View {
        VStack(spacing: 3) {
            ForEach(0..<3, id: \.self) { _ in
                Rectangle()
                    .fill(Color(.systemGray3))
                    .frame(width: 14, height: 2)
            }
        }
        .accessibilityHidden(true)
    }
}
