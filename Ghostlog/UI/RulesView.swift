import SwiftUI

// MARK: - ViewModel

@MainActor
final class RulesViewModel: ObservableObject {
    @Published var rules: [TrackingRule] = []
    @Published var projects: [GhostlogProject] = []
    @Published var isLoading = false
    @Published var error: String? = nil

    private let service = RulesService()
    private let projSvc = ProjectsService()

    func load() {
        isLoading = true
        Task {
            do {
                async let r = service.fetchRules()
                async let p = projSvc.fetchProjects()
                (rules, projects) = try await (r, p)
            } catch { self.error = "Ophalen mislukt" }
            isLoading = false
        }
    }

    func delete(_ rule: TrackingRule) {
        Task {
            try? await service.delete(id: rule.id)
            rules.removeAll { $0.id == rule.id }
        }
    }

    func projectName(for id: Int) -> String {
        projects.first(where: { $0.id == id })?.name ?? "Project \(id)"
    }

    var grouped: [(projectName: String, rules: [TrackingRule])] {
        let sorted = rules.sorted { $0.priority > $1.priority }
        var map: [(String, [TrackingRule])] = []
        var seen: [String: Int] = [:]
        for rule in sorted {
            let name = projectName(for: rule.projectId)
            if let idx = seen[name] { map[idx].1.append(rule) }
            else { seen[name] = map.count; map.append((name, [rule])) }
        }
        return map.map { (projectName: $0.0, rules: $0.1) }
    }
}

// MARK: - View

struct RulesView: View {
    @StateObject private var vm = RulesViewModel()
    @ObservedObject private var userState = UserState.shared
    @State private var editing: TrackingRule? = nil
    @State private var showSheet = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Tracking regels")
                    .font(.headline)
                Spacer()
                Button { editing = nil; showSheet = true } label: {
                    Image(systemName: "plus")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .help("Nieuwe regel")
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 10)

            Divider()

            if vm.isLoading {
                VStack { Spacer(); ProgressView(); Spacer() }.frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if vm.rules.isEmpty {
                VStack(spacing: 8) {
                    Spacer()
                    Image(systemName: "wand.and.rays").font(.largeTitle).foregroundStyle(.secondary)
                    Text("Nog geen regels").foregroundStyle(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        ForEach(vm.grouped, id: \.projectName) { group in
                            VStack(alignment: .leading, spacing: 1) {
                                Text(group.projectName)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal, 16)
                                    .padding(.bottom, 2)
                                ForEach(group.rules) { rule in
                                    RuleRow(rule: rule,
                                            onEdit:   { editing = rule; showSheet = true },
                                            onDelete: { vm.delete(rule) })
                                }
                            }
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
        }
        .frame(minHeight: 400)
        .onAppear { vm.load() }
        .onChange(of: userState.currentTeamId) { _ in vm.load() }
        .sheet(isPresented: $showSheet) {
            RuleFormSheet(projects: vm.projects, editing: editing, service: RulesService()) { rule, isNew in
                if isNew { vm.rules.append(rule) }
                else if let idx = vm.rules.firstIndex(where: { $0.id == rule.id }) { vm.rules[idx] = rule }
                showSheet = false
            } onCancel: { showSheet = false }
        }
    }
}

// MARK: - Rule row

private struct RuleRow: View {
    let rule: TrackingRule
    let onEdit: () -> Void
    let onDelete: () -> Void
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(rule.type.replacingOccurrences(of: "_", with: " "))
                        .font(.caption2).foregroundStyle(.secondary)
                        .padding(.horizontal, 5).padding(.vertical, 2)
                        .background(Color(nsColor: .separatorColor), in: RoundedRectangle(cornerRadius: 4))
                    Text(rule.pattern).fontWeight(.medium).lineLimit(1)
                    if rule.isRegex {
                        Text("regex").font(.caption2).foregroundStyle(.orange)
                            .padding(.horizontal, 4).padding(.vertical, 2)
                            .background(Color.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 4))
                    }
                    if rule.isPersonal {
                        Text("persoonlijk").font(.caption2).foregroundStyle(.blue)
                            .padding(.horizontal, 4).padding(.vertical, 2)
                            .background(Color.blue.opacity(0.1), in: RoundedRectangle(cornerRadius: 4))
                    }
                }
                HStack(spacing: 4) {
                    Text("Prioriteit \(rule.priority)").font(.caption).foregroundStyle(.secondary)
                    if let desc = rule.description, !desc.isEmpty {
                        Text("·").font(.caption).foregroundStyle(.secondary)
                        Text(desc).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                    }
                }
            }
            Spacer()
            if isHovered {
                HStack(spacing: 4) {
                    Button(action: onEdit)   { Image(systemName: "pencil").foregroundStyle(.secondary) }.buttonStyle(.plain).help("Bewerken")
                    Button(action: onDelete) { Image(systemName: "trash").foregroundStyle(.red) }.buttonStyle(.plain).help("Verwijderen")
                }
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
        .background(isHovered ? Color(nsColor: .selectedContentBackgroundColor).opacity(0.06) : Color.clear)
        .onHover { isHovered = $0 }
    }
}

// MARK: - Rule form sheet

private struct RuleFormSheet: View {
    let projects: [GhostlogProject]
    let editing: TrackingRule?
    let service: RulesService
    let onSave: (TrackingRule, Bool) -> Void
    let onCancel: () -> Void

    @State private var projectId: Int = 0
    @State private var type: String = "window_title"
    @State private var pattern: String = ""
    @State private var isRegex: Bool = false
    @State private var priority: Int = 10
    @State private var description: String = ""
    @State private var isPersonal: Bool = false
    @State private var isSaving = false
    @State private var saveError: String? = nil

    // Rule tester
    @State private var testInput: String = ""
    @State private var testResult: RuleTestResult? = nil
    @State private var isTesting = false

    private let ruleTypes = ["window_title", "git_remote", "ide_project", "app_name", "browser_url", "git_branch"]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(editing == nil ? "Nieuwe regel" : "Regel bewerken").font(.headline)

            Form {
                Picker("Project", selection: $projectId) {
                    ForEach(projects) { p in Text(p.name).tag(p.id) }
                }
                Picker("Type", selection: $type) {
                    ForEach(ruleTypes, id: \.self) { t in
                        Text(t.replacingOccurrences(of: "_", with: " ")).tag(t)
                    }
                }
                HStack {
                    TextField("Patroon", text: $pattern)
                    Toggle("Regex", isOn: $isRegex).labelsHidden()
                    Text("regex").font(.caption).foregroundStyle(.secondary)
                }
                TextField("Beschrijving (optioneel)", text: $description)
                Stepper("Prioriteit: \(priority)", value: $priority, in: 1...100)
                if editing == nil {
                    Toggle("Persoonlijke regel", isOn: $isPersonal)
                }
            }
            .formStyle(.grouped)

            // Inline tester
            GroupBox("Tester") {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        TextField("Voer testwaarde in…", text: $testInput)
                            .textFieldStyle(.roundedBorder)
                        Button("Test") { runTest() }
                            .buttonStyle(.bordered)
                            .disabled(pattern.isEmpty || testInput.isEmpty || isTesting)
                    }
                    if let result = testResult {
                        HStack(spacing: 6) {
                            Image(systemName: result.matched ? "checkmark.circle.fill" : "xmark.circle")
                                .foregroundStyle(result.matched ? .green : .red)
                            Text(result.matched
                                 ? "Match\(result.matchedPortion.map { ": \"\($0)\"" } ?? "")"
                                 : "Geen match")
                                .font(.caption)
                        }
                    }
                }
                .padding(.vertical, 4)
            }

            if let err = saveError { Text(err).foregroundStyle(.red).font(.caption) }

            HStack {
                Button("Annuleren", action: onCancel).keyboardShortcut(.escape)
                Spacer()
                Button(editing == nil ? "Aanmaken" : "Opslaan") { save() }
                    .buttonStyle(.borderedProminent)
                    .disabled(pattern.isEmpty || projectId == 0 || isSaving)
                    .keyboardShortcut(.return)
            }
        }
        .padding(20)
        .frame(width: 420)
        .onAppear {
            if let e = editing {
                projectId = e.projectId; type = e.type; pattern = e.pattern
                isRegex = e.isRegex; priority = e.priority; description = e.description ?? ""
            } else if let first = projects.first {
                projectId = first.id
            }
        }
    }

    private func runTest() {
        isTesting = true; testResult = nil
        Task {
            testResult = try? await service.test(type: type, pattern: pattern, isRegex: isRegex, input: testInput)
            isTesting = false
        }
    }

    private func save() {
        isSaving = true; saveError = nil
        let body = RulesService.RuleBody(
            project_id: projectId, type: type, pattern: pattern,
            is_regex: isRegex, priority: priority,
            description: description.isEmpty ? nil : description,
            is_personal: isPersonal
        )
        Task {
            do {
                let rule: TrackingRule
                let isNew: Bool
                if let e = editing { rule = try await service.update(id: e.id, body); isNew = false }
                else               { rule = try await service.create(body); isNew = true }
                onSave(rule, isNew)
            } catch { saveError = "Opslaan mislukt" }
            isSaving = false
        }
    }
}
