import SwiftUI

@MainActor
final class ReportsViewModel: ObservableObject {
    @Published var items: [ReportSummaryItem] = []
    @Published var isLoading = false
    @Published var error: String? = nil
    @Published var from: Date = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
    @Published var to: Date = Date()

    private let service = ReportsService()

    func load() {
        isLoading = true; error = nil
        Task {
            do {
                items = try await service.summary(
                    from: ReportsService.dateString(from),
                    to:   ReportsService.dateString(to)
                )
            } catch { self.error = "Ophalen mislukt" }
            isLoading = false
        }
    }

    func exportCSV() {
        Task {
            guard let data = try? await service.exportData(
                from: ReportsService.dateString(from),
                to:   ReportsService.dateString(to)
            ) else { return }
            let panel = NSSavePanel()
            panel.allowedContentTypes = [.commaSeparatedText]
            panel.nameFieldStringValue = "ghostlog-export.csv"
            if panel.runModal() == .OK, let url = panel.url {
                try? data.write(to: url)
            }
        }
    }

    var total: Int { items.reduce(0) { $0 + $1.totalDuration } }

    func formatDuration(_ s: Int) -> String {
        let h = s / 3600; let m = (s % 3600) / 60
        return h > 0 ? "\(h)u \(String(format: "%02d", m))m" : "\(m)m"
    }
}

struct ReportsView: View {
    @StateObject private var vm = ReportsViewModel()
    @ObservedObject private var userState = UserState.shared

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 12) {
                Text("Rapportage").font(.headline)
                Spacer()
                DatePicker("", selection: $vm.from, displayedComponents: .date)
                    .labelsHidden().frame(width: 120)
                Text("t/m").foregroundStyle(.secondary)
                DatePicker("", selection: $vm.to, displayedComponents: .date)
                    .labelsHidden().frame(width: 120)
                Button { vm.load() } label: { Image(systemName: "arrow.clockwise") }
                    .buttonStyle(.plain)
                Button("CSV") { vm.exportCSV() }
                    .buttonStyle(.bordered).controlSize(.small)
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
            } else if vm.items.isEmpty {
                VStack(spacing: 8) {
                    Spacer()
                    Image(systemName: "chart.bar").font(.largeTitle).foregroundStyle(.secondary)
                    Text("Geen data voor deze periode").foregroundStyle(.secondary)
                    Spacer()
                }.frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        // Totaal
                        HStack {
                            Text("Totaal").fontWeight(.semibold)
                            Spacer()
                            Text(vm.formatDuration(vm.total))
                                .fontWeight(.semibold).monospacedDigit()
                        }
                        .padding(.horizontal, 16).padding(.vertical, 12)

                        Divider().padding(.horizontal, 8)

                        LazyVStack(spacing: 1) {
                            ForEach(vm.items) { item in
                                ReportRow(item: item, total: vm.total, formatFn: vm.formatDuration)
                            }
                        }
                        .padding(.vertical, 4)
                    }
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

private struct ReportRow: View {
    let item: ReportSummaryItem
    let total: Int
    let formatFn: (Int) -> String

    private var fraction: Double { total > 0 ? Double(item.totalDuration) / Double(total) : 0 }

    var body: some View {
        VStack(spacing: 6) {
            HStack {
                Text(item.projectName ?? "Geen project").lineLimit(1)
                Spacer()
                Text("\(item.entryCount) blokken").font(.caption).foregroundStyle(.secondary)
                Text(formatFn(item.totalDuration)).monospacedDigit().frame(width: 70, alignment: .trailing)
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
}
