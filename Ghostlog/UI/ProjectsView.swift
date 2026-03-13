import SwiftUI

// MARK: - ViewModel

@MainActor
final class ProjectsViewModel: ObservableObject {
    @Published var projects: [GhostlogProject] = []
    @Published var clients: [GhostlogClient] = []
    @Published var isLoading = false
    @Published var errorMessage: String? = nil

    private let service = ProjectsService()

    func load() {
        isLoading = true
        errorMessage = nil
        Task {
            do {
                async let p = service.fetchProjects()
                async let c = service.fetchClients()
                (projects, clients) = try await (p, c)
            } catch {
                errorMessage = "Ophalen mislukt"
            }
            isLoading = false
        }
    }

    func createProject(name: String, clientId: Int?, color: String, active: Bool) async throws {
        let p = try await service.createProject(name: name, clientId: clientId, color: color, active: active)
        projects.append(p)
    }

    func updateProject(_ project: GhostlogProject, name: String, clientId: Int?, color: String, active: Bool) async throws {
        let p = try await service.updateProject(id: project.id, name: name, clientId: clientId, color: color, active: active)
        if let idx = projects.firstIndex(where: { $0.id == p.id }) { projects[idx] = p }
    }

    func deleteProject(_ project: GhostlogProject) {
        Task {
            try? await service.deleteProject(id: project.id)
            projects.removeAll { $0.id == project.id }
        }
    }

    func createClient(name: String) async throws {
        let c = try await service.createClient(name: name)
        clients.append(c)
    }

    func updateClient(_ client: GhostlogClient, name: String) async throws {
        let c = try await service.updateClient(id: client.id, name: name)
        if let idx = clients.firstIndex(where: { $0.id == c.id }) { clients[idx] = c }
    }

    func deleteClient(_ client: GhostlogClient) {
        Task {
            try? await service.deleteClient(id: client.id)
            clients.removeAll { $0.id == client.id }
        }
    }

    func clientName(for id: Int?) -> String? {
        guard let id else { return nil }
        return clients.first(where: { $0.id == id })?.name
    }
}

// MARK: - Root view

enum ProjectsTab { case projects, clients }

struct ProjectsView: View {
    @StateObject private var vm = ProjectsViewModel()
    @ObservedObject private var userState = UserState.shared
    @State private var tab: ProjectsTab = .projects

    @State private var showProjectSheet = false
    @State private var editingProject: GhostlogProject? = nil

    @State private var showClientSheet = false
    @State private var editingClient: GhostlogClient? = nil

    var body: some View {
        VStack(spacing: 0) {
            // Sub-tab bar + add button
            HStack {
                Picker("", selection: $tab) {
                    Text("Projecten").tag(ProjectsTab.projects)
                    Text("Klanten").tag(ProjectsTab.clients)
                }
                .pickerStyle(.segmented)
                .frame(width: 200)

                Spacer()

                Button {
                    if tab == .projects { editingProject = nil; showProjectSheet = true }
                    else                { editingClient = nil;  showClientSheet = true }
                } label: {
                    Image(systemName: "plus")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .help(tab == .projects ? "Nieuw project" : "Nieuwe klant")
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 10)

            Divider()

            if vm.isLoading {
                VStack { Spacer(); ProgressView(); Spacer() }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let err = vm.errorMessage {
                VStack(spacing: 8) {
                    Spacer()
                    Text(err).foregroundStyle(.secondary)
                    Button("Opnieuw") { vm.load() }.buttonStyle(.borderedProminent)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if tab == .projects {
                ProjectList(vm: vm, onEdit: { editingProject = $0; showProjectSheet = true })
            } else {
                ClientList(vm: vm, onEdit: { editingClient = $0; showClientSheet = true })
            }
        }
        .frame(minHeight: 400)
        .onAppear { vm.load() }
        .onChange(of: userState.currentTeamId) { _ in vm.load() }
        .sheet(isPresented: $showProjectSheet) {
            ProjectFormSheet(vm: vm, editing: editingProject) { showProjectSheet = false }
        }
        .sheet(isPresented: $showClientSheet) {
            ClientFormSheet(vm: vm, editing: editingClient) { showClientSheet = false }
        }
    }
}

// MARK: - Project list

private struct ProjectList: View {
    @ObservedObject var vm: ProjectsViewModel
    let onEdit: (GhostlogProject) -> Void

    var body: some View {
        if vm.projects.isEmpty {
            VStack(spacing: 8) {
                Spacer()
                Image(systemName: "folder").font(.largeTitle).foregroundStyle(.secondary)
                Text("Nog geen projecten").foregroundStyle(.secondary)
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                LazyVStack(spacing: 1) {
                    ForEach(vm.projects) { project in
                        ProjectRow(project: project, clientName: vm.clientName(for: project.clientId),
                                   onEdit: { onEdit(project) },
                                   onDelete: { vm.deleteProject(project) })
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }
}

private struct ProjectRow: View {
    let project: GhostlogProject
    let clientName: String?
    let onEdit: () -> Void
    let onDelete: () -> Void
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color(hex: project.color) ?? .accentColor)
                .frame(width: 10, height: 10)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(project.name).fontWeight(.medium)
                    if !project.active {
                        Text("inactief")
                            .font(.caption2)
                            .padding(.horizontal, 5).padding(.vertical, 2)
                            .background(Color(nsColor: .separatorColor), in: Capsule())
                            .foregroundStyle(.secondary)
                    }
                }
                if let client = clientName {
                    Text(client).font(.caption).foregroundStyle(.secondary)
                }
            }

            Spacer()

            if isHovered {
                HStack(spacing: 4) {
                    Button(action: onEdit) {
                        Image(systemName: "pencil").foregroundStyle(.secondary)
                    }.buttonStyle(.plain).help("Bewerken")

                    Button(action: onDelete) {
                        Image(systemName: "trash").foregroundStyle(.red)
                    }.buttonStyle(.plain).help("Verwijderen")
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(isHovered ? Color(nsColor: .selectedContentBackgroundColor).opacity(0.06) : Color.clear)
        .onHover { isHovered = $0 }
    }
}

// MARK: - Client list

private struct ClientList: View {
    @ObservedObject var vm: ProjectsViewModel
    let onEdit: (GhostlogClient) -> Void

    var body: some View {
        if vm.clients.isEmpty {
            VStack(spacing: 8) {
                Spacer()
                Image(systemName: "building.2").font(.largeTitle).foregroundStyle(.secondary)
                Text("Nog geen klanten").foregroundStyle(.secondary)
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                LazyVStack(spacing: 1) {
                    ForEach(vm.clients) { client in
                        ClientRow(client: client,
                                  projectCount: vm.projects.filter { $0.clientId == client.id }.count,
                                  onEdit: { onEdit(client) },
                                  onDelete: { vm.deleteClient(client) })
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }
}

private struct ClientRow: View {
    let client: GhostlogClient
    let projectCount: Int
    let onEdit: () -> Void
    let onDelete: () -> Void
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "building.2").foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 2) {
                Text(client.name).fontWeight(.medium)
                Text("\(projectCount) project\(projectCount == 1 ? "" : "en")")
                    .font(.caption).foregroundStyle(.secondary)
            }

            Spacer()

            if isHovered {
                HStack(spacing: 4) {
                    Button(action: onEdit) {
                        Image(systemName: "pencil").foregroundStyle(.secondary)
                    }.buttonStyle(.plain).help("Bewerken")

                    Button(action: onDelete) {
                        Image(systemName: "trash").foregroundStyle(.red)
                    }.buttonStyle(.plain).help("Verwijderen")
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(isHovered ? Color(nsColor: .selectedContentBackgroundColor).opacity(0.06) : Color.clear)
        .onHover { isHovered = $0 }
    }
}

// MARK: - Project form sheet

private struct ProjectFormSheet: View {
    @ObservedObject var vm: ProjectsViewModel
    let editing: GhostlogProject?
    let onDone: () -> Void

    @State private var name: String = ""
    @State private var selectedClientId: Int? = nil
    @State private var color: String = "#3B82F6"
    @State private var active: Bool = true
    @State private var isSaving = false
    @State private var error: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(editing == nil ? "Nieuw project" : "Project bewerken")
                .font(.headline)

            Form {
                TextField("Naam", text: $name)

                Picker("Klant", selection: $selectedClientId) {
                    Text("Geen klant").tag(Optional<Int>.none)
                    ForEach(vm.clients) { c in
                        Text(c.name).tag(Optional(c.id))
                    }
                }

                ColorPickerRow(hex: $color)

                Toggle("Actief", isOn: $active)
            }
            .formStyle(.grouped)

            if let err = error {
                Text(err).foregroundStyle(.red).font(.caption)
            }

            HStack {
                Button("Annuleren") { onDone() }.keyboardShortcut(.escape)
                Spacer()
                Button(editing == nil ? "Aanmaken" : "Opslaan") { save() }
                    .buttonStyle(.borderedProminent)
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || isSaving)
                    .keyboardShortcut(.return)
            }
        }
        .padding(20)
        .frame(width: 360)
        .onAppear {
            if let p = editing {
                name = p.name
                selectedClientId = p.clientId
                color = p.color
                active = p.active
            }
        }
    }

    private func save() {
        isSaving = true
        error = nil
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        Task {
            do {
                if let p = editing {
                    try await vm.updateProject(p, name: trimmed, clientId: selectedClientId, color: color, active: active)
                } else {
                    try await vm.createProject(name: trimmed, clientId: selectedClientId, color: color, active: active)
                }
                onDone()
            } catch {
                self.error = "Opslaan mislukt"
            }
            isSaving = false
        }
    }
}

// MARK: - Client form sheet

private struct ClientFormSheet: View {
    @ObservedObject var vm: ProjectsViewModel
    let editing: GhostlogClient?
    let onDone: () -> Void

    @State private var name: String = ""
    @State private var isSaving = false
    @State private var error: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(editing == nil ? "Nieuwe klant" : "Klant bewerken")
                .font(.headline)

            TextField("Naam", text: $name)
                .textFieldStyle(.roundedBorder)

            if let err = error {
                Text(err).foregroundStyle(.red).font(.caption)
            }

            HStack {
                Button("Annuleren") { onDone() }.keyboardShortcut(.escape)
                Spacer()
                Button(editing == nil ? "Aanmaken" : "Opslaan") { save() }
                    .buttonStyle(.borderedProminent)
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || isSaving)
                    .keyboardShortcut(.return)
            }
        }
        .padding(20)
        .frame(width: 300)
        .onAppear { if let c = editing { name = c.name } }
    }

    private func save() {
        isSaving = true
        error = nil
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        Task {
            do {
                if let c = editing { try await vm.updateClient(c, name: trimmed) }
                else               { try await vm.createClient(name: trimmed) }
                onDone()
            } catch {
                self.error = "Opslaan mislukt"
            }
            isSaving = false
        }
    }
}

// MARK: - Helpers

private struct ColorPickerRow: View {
    @Binding var hex: String

    private var binding: Binding<Color> {
        Binding(
            get: { Color(hex: hex) ?? .blue },
            set: { hex = $0.toHex() ?? hex }
        )
    }

    var body: some View {
        ColorPicker("Kleur", selection: binding, supportsOpacity: false)
    }
}

private extension Color {
    init?(hex: String) {
        let h = hex.hasPrefix("#") ? String(hex.dropFirst()) : hex
        guard h.count == 6, let val = UInt64(h, radix: 16) else { return nil }
        self.init(
            red:   Double((val >> 16) & 0xFF) / 255,
            green: Double((val >>  8) & 0xFF) / 255,
            blue:  Double( val        & 0xFF) / 255
        )
    }

    func toHex() -> String? {
        guard let c = NSColor(self).usingColorSpace(.sRGB) else { return nil }
        return String(format: "#%02X%02X%02X",
                      Int(c.redComponent * 255),
                      Int(c.greenComponent * 255),
                      Int(c.blueComponent * 255))
    }
}
