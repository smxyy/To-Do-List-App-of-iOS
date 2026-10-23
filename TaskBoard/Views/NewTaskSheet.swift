import SwiftUI

struct NewTaskSheet: View {
    @Environment(TaskBoardStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var draft = ""
    @FocusState private var isFocused: Bool

    private var canAdd: Bool {
        !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ZStack {
                Text("New Task")
                    .font(.headline)
                HStack {
                    Button("Cancel") { dismiss() }
                    Spacer()
                    Button("Add", action: add)
                        .fontWeight(.semibold)
                        .disabled(!canAdd)
                }
            }

            TextField("What needs doing?", text: $draft)
                .focused($isFocused)
                .submitLabel(.done)
                .onSubmit(add)
                .padding(.horizontal, 14)
                .frame(height: 44)
                .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 12))

            Text("Added to To do · sends POST /todos")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.top, 24)
        .frame(maxHeight: .infinity, alignment: .top)
        .presentationDetents([.height(180)])
        .presentationDragIndicator(.visible)
        .presentationBackground(Color(.systemGroupedBackground))
        .onAppear { isFocused = true }
    }

    private func add() {
        guard canAdd else { return }
        withAnimation(.snappy) { store.add(title: draft) }
        dismiss()
    }
}
