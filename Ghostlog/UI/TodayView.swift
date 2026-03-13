import SwiftUI

// MARK: - ViewModel

@MainActor
final class TodayViewModel: ObservableObject {
    @Published var entries: [TimeEntry] = []
    @Published var projects: [TodayProject] = []
    @Published var isLoading = false
    @Published var errorMessage: String? = nil
    @Published var busyIds: Set<Int> = []

    struct TodayProject: Identifiable {
        let id: Int
        let name: String
    }

    private let service = TodayService()

    func load() {
        isLoading = true
        errorMessage = nil
        Task {
            do {
                let fetched = try await service.fetchToday()
                entries  = fetched.entries
                projects = fetched.projects.map { TodayProject(id: $0.id, name: $0.name) }
            } catch {
                errorMessage = "Ophalen mislukt"
            }
            isLoading = false
        }
    }

    func approve(entry: TimeEntry) {
        guard !busyIds.contains(entry.id) else { return }
        busyIds.insert(entry.id)
        Task {
            try? await service.approve(id: entry.id)
            replace(entry, status: "approved")
            busyIds.remove(entry.id)
        }
    }

    func unapprove(entry: TimeEntry) {
        guard !busyIds.contains(entry.id) else { return }
        busyIds.insert(entry.id)
        Task {
            try? await service.unapprove(id: entry.id)
            replace(entry, status: "pending")
            busyIds.remove(entry.id)
        }
    }

    func update(entry: TimeEntry, projectId: Int?, startedAt: Date, endedAt: Date, description: String?) {
        busyIds.insert(entry.id)
        Task {
            if let updated = try? await service.update(
                id: entry.id, projectId: projectId,
                startedAt: startedAt, endedAt: endedAt, description: description
            ) {
                let name = projects.first(where: { $0.id == updated.projectId })?.name
                let resolved = TimeEntry(
                    id: updated.id, startedAt: updated.startedAt, endedAt: updated.endedAt,
                    duration: updated.duration, projectId: updated.projectId,
                    projectName: name, status: updated.status,
                    description: updated.description, issueIdentifier: updated.issueIdentifier
                )
                if let idx = entries.firstIndex(where: { $0.id == resolved.id }) {
                    entries[idx] = resolved
                }
            }
            busyIds.remove(entry.id)
        }
    }

    func delete(entry: TimeEntry) {
        Task {
            try? await service.delete(id: entry.id)
            entries.removeAll { $0.id == entry.id }
        }
    }

    var pendingEntries: [TimeEntry] { entries.filter { $0.status == "pending" } }

    var totalFormatted: String {
        let total = entries.reduce(0) { $0 + $1.duration }
        return formatDuration(total)
    }

    func formatDuration(_ seconds: Int) -> String {
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        return h > 0 ? "\(h)u \(String(format: "%02d", m))m" : "\(m)m"
    }

    private func replace(_ entry: TimeEntry, status: String) {
        if let idx = entries.firstIndex(where: { $0.id == entry.id }) {
            entries[idx] = TimeEntry(
                id: entry.id, startedAt: entry.startedAt, endedAt: entry.endedAt,
                duration: entry.duration, projectId: entry.projectId,
                projectName: entry.projectName, status: status,
                description: entry.description, issueIdentifier: entry.issueIdentifier
            )
        }
    }
}

// MARK: - Root view

struct TodayView: View {
    @StateObject private var vm = TodayViewModel()
    @ObservedObject private var userState = UserState.shared
    @State private var editingEntry: TimeEntry? = nil

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "nl_NL")
        f.dateFormat = "EEEE d MMMM"
        return f
    }()

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(Self.dateFormatter.string(from: Date()).capitalized)
                        .font(.headline)
                    if !vm.isLoading && !vm.entries.isEmpty {
                        Text("Totaal: \(vm.totalFormatted)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                if !vm.pendingEntries.isEmpty {
                    Button("Alles goedkeuren") {
                        vm.pendingEntries.forEach { vm.approve(entry: $0) }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                Button { vm.load() } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.plain)
                .help("Vernieuwen")
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 12)

            Divider()

            if vm.isLoading {
                VStack { Spacer(); ProgressView(); Spacer() }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let err = vm.errorMessage {
                VStack(spacing: 8) {
                    Spacer()
                    Image(systemName: "exclamationmark.triangle").font(.largeTitle).foregroundStyle(.secondary)
                    Text(err).foregroundStyle(.secondary)
                    Button("Opnieuw") { vm.load() }.buttonStyle(.borderedProminent)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if vm.entries.isEmpty {
                VStack(spacing: 8) {
                    Spacer()
                    Image(systemName: "clock").font(.largeTitle).foregroundStyle(.secondary)
                    Text("Nog geen tijdblokken vandaag").foregroundStyle(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 1) {
                        ForEach(vm.entries) { entry in
                            EntryRow(
                                entry: entry,
                                isBusy: vm.busyIds.contains(entry.id),
                                onApprove:   { vm.approve(entry: entry) },
                                onUnapprove: { vm.unapprove(entry: entry) },
                                onEdit:      { editingEntry = entry },
                                onDelete:    { vm.delete(entry: entry) }
                            )
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .frame(minHeight: 400)
        .onAppear { vm.load() }
        .onChange(of: userState.currentTeamId) { _ in vm.load() }
        .sheet(item: $editingEntry) { entry in
            EditEntrySheet(entry: entry, projects: vm.projects) { projectId, start, end, desc in
                vm.update(entry: entry, projectId: projectId, startedAt: start, endedAt: end, description: desc)
                editingEntry = nil
            } onCancel: {
                editingEntry = nil
            }
        }
    }
}

// MARK: - Entry row

private struct EntryRow: View {
    let entry: TimeEntry
    let isBusy: Bool
    let onApprove: () -> Void
    let onUnapprove: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    @State private var isHovered = false

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f
    }()

    var body: some View {
        HStack(spacing: 12) {
            Rectangle()
                .fill(statusColor)
                .frame(width: 3)
                .clipShape(Capsule())

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(entry.projectName ?? "Geen project")
                        .fontWeight(.medium)
                        .lineLimit(1)
                    if let issue = entry.issueIdentifier {
                        Text(issue)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 5).padding(.vertical, 2)
                            .background(Color(nsColor: .separatorColor), in: RoundedRectangle(cornerRadius: 4))
                    }
                }
                HStack(spacing: 4) {
                    Text("\(Self.timeFormatter.string(from: entry.startedAt)) – \(Self.timeFormatter.string(from: entry.endedAt))")
                        .font(.caption).foregroundStyle(.secondary)
                    if let desc = entry.description, !desc.isEmpty {
                        Text("·").font(.caption).foregroundStyle(.secondary)
                        Text(desc).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                    }
                }
            }

            Spacer()

            Text(formatDuration(entry.duration))
                .font(.system(.callout, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: 60, alignment: .trailing)

            // Action buttons (always visible on right)
            HStack(spacing: 2) {
                if isBusy {
                    ProgressView().scaleEffect(0.7).frame(width: 24, height: 24)
                } else {
                    // Edit
                    IconButton(icon: "pencil", help: "Bewerken", action: onEdit)

                    // Approve / Unapprove
                    if entry.status == "approved" {
                        IconButton(icon: "checkmark.circle.fill", help: "Afkeuren", color: .green) {
                            onUnapprove()
                        }
                    } else {
                        IconButton(icon: "checkmark.circle", help: "Goedkeuren", action: onApprove)
                    }

                    // Delete
                    IconButton(icon: "trash", help: "Verwijderen", color: .red, action: onDelete)
                }
            }
            .frame(width: 72)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(isHovered ? Color(nsColor: .selectedContentBackgroundColor).opacity(0.06) : Color.clear)
        .onHover { isHovered = $0 }
    }

    private var statusColor: Color {
        switch entry.status {
        case "approved": return .green
        case "rejected": return .red
        default:         return Color(nsColor: .separatorColor)
        }
    }

    private func formatDuration(_ seconds: Int) -> String {
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        return h > 0 ? "\(h)u \(String(format: "%02d", m))m" : "\(m)m"
    }
}

private struct IconButton: View {
    let icon: String
    let help: String
    var color: Color = Color(nsColor: .secondaryLabelColor)
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .foregroundStyle(isHovered ? color : Color(nsColor: .secondaryLabelColor))
                .frame(width: 24, height: 24)
        }
        .buttonStyle(.plain)
        .help(help)
        .onHover { isHovered = $0 }
    }
}

// MARK: - Edit sheet

private struct EditEntrySheet: View {
    let entry: TimeEntry
    let projects: [TodayViewModel.TodayProject]
    let onSave: (Int?, Date, Date, String?) -> Void
    let onCancel: () -> Void

    @State private var selectedProjectId: Int?
    @State private var startedAt: Date
    @State private var endedAt: Date
    @State private var description: String

    init(entry: TimeEntry, projects: [TodayViewModel.TodayProject],
         onSave: @escaping (Int?, Date, Date, String?) -> Void,
         onCancel: @escaping () -> Void) {
        self.entry = entry
        self.projects = projects
        self.onSave = onSave
        self.onCancel = onCancel
        _selectedProjectId = State(initialValue: entry.projectId)
        _startedAt = State(initialValue: entry.startedAt)
        _endedAt   = State(initialValue: entry.endedAt)
        _description = State(initialValue: entry.description ?? "")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Tijdblok bewerken").font(.headline)

            Form {
                Picker("Project", selection: $selectedProjectId) {
                    Text("Geen project").tag(Optional<Int>.none)
                    ForEach(projects) { p in
                        Text(p.name).tag(Optional(p.id))
                    }
                }

                DatePicker("Start", selection: $startedAt, displayedComponents: [.hourAndMinute])
                DatePicker("Eind",  selection: $endedAt,   displayedComponents: [.hourAndMinute])

                TextField("Omschrijving", text: $description)
            }
            .formStyle(.grouped)

            HStack {
                Button("Annuleren", action: onCancel).keyboardShortcut(.escape)
                Spacer()
                Button("Opslaan") {
                    onSave(selectedProjectId, startedAt, endedAt, description.isEmpty ? nil : description)
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.return)
                .disabled(endedAt <= startedAt)
            }
        }
        .padding(20)
        .frame(width: 360)
    }
}
