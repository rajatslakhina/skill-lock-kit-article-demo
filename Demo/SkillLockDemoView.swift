import SwiftUI
import SkillLockKit

struct SkillLockDemoView: View {
    @ObservedObject var viewModel: SkillLockDemoViewModel

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        Image(systemName: viewModel.failingCount > 0 ? "xmark.octagon.fill" : "checkmark.seal.fill")
                            .foregroundStyle(viewModel.failingCount > 0 ? .red : .green)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(viewModel.failingCount > 0 ? "CI gate: FAIL" : "CI gate: PASS")
                                .font(.headline)
                            Text("\(viewModel.failingCount) unacknowledged drift(s) out of \(viewModel.rows.count) tracked skills")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section("Vendored skills") {
                    ForEach(viewModel.rows) { row in
                        Button {
                            viewModel.selectedRowID = row.id
                        } label: {
                            SkillRowView(row: row)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .navigationTitle("SkillLockKit")
            .sheet(item: Binding(
                get: { viewModel.selectedRowID.map { SelectedID(id: $0) } },
                set: { viewModel.selectedRowID = $0?.id }
            )) { selected in
                if let row = viewModel.rows.first(where: { $0.id == selected.id }) {
                    SkillDriftDetailView(row: row)
                }
            }
        }
    }
}

/// Sheet(item:) needs Identifiable; String alone won't conform, so this
/// small wrapper avoids force-unwrapping an Optional binding.
private struct SelectedID: Identifiable {
    let id: String
}

private struct SkillRowView: View {
    let row: SkillRow

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: iconName)
                .foregroundStyle(iconColor)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(row.name)
                    .font(.body.monospaced())
                Text(row.statusLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if row.isFailing {
                Text("FAILS GATE")
                    .font(.caption2.bold())
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.red.opacity(0.15), in: Capsule())
                    .foregroundStyle(.red)
            }
        }
        .padding(.vertical, 4)
    }

    private var iconName: String {
        guard let drift = row.drift else { return "lock.fill" }
        switch drift {
        case .added: return "plus.circle.fill"
        case .removed: return "minus.circle.fill"
        case .changed: return "arrow.triangle.2.circlepath.circle.fill"
        }
    }

    private var iconColor: Color {
        guard row.drift != nil else { return .green }
        return row.isFailing ? .red : .orange
    }
}

private struct SkillDriftDetailView: View {
    let row: SkillRow

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(row.name)
                        .font(.title2.bold().monospaced())
                    Text(row.statusLabel)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    if let drift = row.drift {
                        Divider()
                        switch drift {
                        case .changed(_, let locked, let live):
                            comparisonBlock(title: "Locked (\(locked.sourceToolchain))", hash: locked.contentHash)
                            comparisonBlock(title: "Live (\(live.sourceToolchain))", hash: live.contentHash)
                        case .added(let definition):
                            comparisonBlock(title: "Live only (\(definition.sourceToolchain))", hash: definition.contentHash)
                        case .removed(let definition):
                            comparisonBlock(title: "Locked only (\(definition.sourceToolchain))", hash: definition.contentHash)
                        }
                    } else {
                        Divider()
                        Text("No drift — locked and live content hashes match.")
                            .font(.callout)
                    }
                }
                .padding()
            }
            .navigationTitle("Drift detail")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func comparisonBlock(title: String, hash: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.headline)
            Text("content hash: \(hash)")
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(.gray.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
    }
}

#Preview {
    SkillLockDemoView(viewModel: .sampleFleetScenario())
}
