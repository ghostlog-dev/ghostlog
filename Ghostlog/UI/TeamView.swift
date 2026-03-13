import SwiftUI

@MainActor
final class TeamViewModel: ObservableObject {
    @Published var members: [TeamMemberReport] = []
    @Published var isLoading = false
    @Published var error: String? = nil
    @Published var from: Date = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
    @Published var to: Date = Date()

    private let service = ReportsService()

    func load() {
        isLoading = true; error = nil
        Task {
            do {
                members = try await service.team(
                    from: ReportsService.dateString(from),
                    to:   ReportsService.dateString(to)
                )
            } catch { self.error = "Ophalen mislukt" }
            isLoading = false
        }
    }

    var total: Int { members.reduce(0) { $0 + $1.totalDuration } }

    func formatDuration(_ s: Int) -> String {
        let h = s / 3600; let m = (s % 3600) / 60
        return h > 0 ? "\(h)u \(String(format: "%02d", m))m" : "\(m)m"
    }
}

struct TeamView: View {
    @StateObject private var vm = TeamViewModel()
    @ObservedObject private var userState = UserState.shared

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Text("Team").font(.headline)
                Spacer()
                DatePicker("", selection: $vm.from, displayedComponents: .date)
                    .labelsHidden().frame(width: 120)
                Text("t/m").foregroundStyle(.secondary)
                DatePicker("", selection: $vm.to, displayedComponents: .date)
                    .labelsHidden().frame(width: 120)
                Button { vm.load() } label: { Image(systemName: "arrow.clockwise") }
                    .buttonStyle(.plain)
            }
            .padding(.horizontal, 16).padding(.top, 14).padding(.bottom, 10)

            Divider()

            if vm.isLoading {
                VStack { Spacer(); ProgressView(); Spacer() }.frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let err = vm.error {
                VStack(spacing: 8) {
                    Spacer(); Text(err).foregroundStyle(.secondary)
                    Button("Opnieuw") { vm.load() }.buttonStyle(.borderedProminent); Spacer()
                }.frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if vm.members.isEmpty {
                VStack(spacing: 8) {
                    Spacer()
                    Image(systemName: "person.3").font(.largeTitle).foregroundStyle(.secondary)
                    Text("Geen data voor deze periode").foregroundStyle(.secondary)
                    Spacer()
                }.frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 1) {
                        ForEach(vm.members.sorted { $0.totalDuration > $1.totalDuration }) { member in
                            MemberRow(member: member, teamTotal: vm.total, formatFn: vm.formatDuration)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .frame(minHeight: 400)
        .onAppear { vm.load() }
        .onChange(of: vm.from) { _ in vm.load() }
        .onChange(of: vm.to)   { _ in vm.load() }
        .onChange(of: userState.currentTeamId) { _ in vm.load() }
    }
}

private struct MemberRow: View {
    let member: TeamMemberReport
    let teamTotal: Int
    let formatFn: (Int) -> String

    @State private var expanded = false
    private var fraction: Double { teamTotal > 0 ? Double(member.totalDuration) / Double(teamTotal) : 0 }

    var body: some View {
        VStack(spacing: 0) {
            Button { withAnimation(.easeInOut(duration: 0.15)) { expanded.toggle() } } label: {
                VStack(spacing: 6) {
                    HStack {
                        Image(systemName: "person.circle").foregroundStyle(.secondary)
                        Text(member.userName).fontWeight(.medium)
                        Spacer()
                        Text(formatFn(member.totalDuration)).monospacedDigit().foregroundStyle(.secondary)
                        Image(systemName: expanded ? "chevron.up" : "chevron.down")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 3).fill(Color(nsColor: .separatorColor)).frame(height: 5)
                            RoundedRectangle(cornerRadius: 3).fill(Color.accentColor)
                                .frame(width: geo.size.width * fraction, height: 5)
                        }
                    }
                    .frame(height: 5)
                }
                .padding(.horizontal, 16).padding(.vertical, 10)
            }
            .buttonStyle(.plain)

            if expanded {
                VStack(spacing: 1) {
                    ForEach(member.byProject.sorted { $0.totalDuration > $1.totalDuration }) { slice in
                        HStack {
                            Text(slice.projectName ?? "Geen project")
                                .font(.callout).foregroundStyle(.secondary)
                            Spacer()
                            Text(formatFn(slice.totalDuration))
                                .font(.callout).monospacedDigit().foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 28).padding(.vertical, 6)
                        .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
                    }
                }
            }

            Divider().padding(.horizontal, 8)
        }
    }
}
