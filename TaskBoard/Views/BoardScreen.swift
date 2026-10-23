import SwiftUI

struct BoardScreen: View {
    @Environment(TaskBoardStore.self) private var store
    @State private var showingNewTask = false

    var body: some View {
        GeometryReader { proxy in
            let isLandscape = proxy.size.width > proxy.size.height
            VStack(alignment: .leading, spacing: 0) {
                header(isLandscape: isLandscape)
                content(isLandscape: isLandscape)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
            .padding(.horizontal, isLandscape ? 20 : 16)
            .padding(.top, isLandscape ? 8 : 0)
        }
        .background(Color(.systemGroupedBackground))
        .task { await store.load() }
        .sheet(isPresented: $showingNewTask) {
            NewTaskSheet()
        }
    }

    private func header(isLandscape: Bool) -> some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Tasks")
                    .font(.system(size: isLandscape ? 24 : 32, weight: .bold))
                    .kerning(-0.5)
                Text(subtitle)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .contentTransition(.numericText())
            }
            Spacer()
            HStack(spacing: 10) {
                CircleButton(systemImage: "arrow.clockwise", label: "Reload", isProminent: false) {
                    Task { await store.load() }
                }
                CircleButton(systemImage: "plus", label: "New task", isProminent: true) {
                    showingNewTask = true
                }
            }
        }
        .padding(.top, isLandscape ? 0 : 8)
        .padding(.horizontal, isLandscape ? 0 : 4)
        .padding(.bottom, isLandscape ? 12 : 14)
    }

    private var subtitle: String {
        store.phase == .loading
            ? "Loading…"
            : "User \(store.userID) · \(store.doneCount)/\(store.tasks.count) done"
    }

    @ViewBuilder
    private func content(isLandscape: Bool) -> some View {
        switch store.phase {
        case .loading:
            LoadingPlaceholder()
        case .failed(let message):
            ErrorStateView(message: message) {
                Task { await store.load() }
            }
        case .ready:
            BoardView(isLandscape: isLandscape)
        }
    }
}

private struct CircleButton: View {
    let systemImage: String
    let label: String
    let isProminent: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: isProminent ? 17 : 15, weight: .semibold))
                .foregroundStyle(isProminent ? Color.white : Color.accentColor)
                .frame(width: 32, height: 32)
                .background(isProminent ? Color.accentColor : Color(.systemGray5), in: .circle)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

#Preview {
    BoardScreen()
        .environment(TaskBoardStore())
}
