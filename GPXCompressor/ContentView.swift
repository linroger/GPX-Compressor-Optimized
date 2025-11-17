import SwiftUI
import GPXProcessing

struct ContentView: View {
    @EnvironmentObject private var viewModel: ProcessingViewModel
    @State private var showImporter = false
    @State private var selectedStrategy: StrategyOption = .rdp
    @State private var rdpTolerance: Double = 5.0
    @State private var stripRadius: Double = 2.0
    @State private var enableDeduplication = true

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                header
                strategyControls
                actionBar
                jobsList
            }
            .padding()
            .frame(minWidth: 720, minHeight: 520)
            .background(Color(nsColor: .windowBackgroundColor))
        }
        .fileImporter(isPresented: $showImporter, allowedContentTypes: [.init(filenameExtension: "gpx")!], allowsMultipleSelection: true) { result in
            switch result {
            case .success(let urls):
                viewModel.enqueue(urls: urls)
            case .failure(let error):
                print("Importer error: \(error)")
            }
        }
        .onAppear(perform: syncConfiguration)
        .dropDestination(for: URL.self) { urls, _ in
            viewModel.enqueue(urls: urls)
            return true
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("GPX Compressor")
                .font(.largeTitle)
                .bold()
            Text("Optimised for Apple Silicon. Queue multiple GPX files, process them in parallel, and monitor progress in real time.")
                .foregroundStyle(.secondary)
        }
    }

    private var strategyControls: some View {
        GroupBox("Compression Settings") {
            VStack(alignment: .leading, spacing: 12) {
                Picker("Strategy", selection: $selectedStrategy) {
                    Text("Ramer–Douglas–Peucker").tag(StrategyOption.rdp)
                    Text("Strip Nearby").tag(StrategyOption.stripNearby)
                    Text("Strip Duplicates").tag(StrategyOption.stripDuplicates)
                }
                .onChange(of: selectedStrategy) { _, _ in applyConfiguration() }
                .pickerStyle(.segmented)

                if selectedStrategy == .rdp {
                    HStack {
                        Text("Tolerance: \(String(format: "%.1f m", rdpTolerance))")
                        Slider(value: $rdpTolerance, in: 1...50, step: 0.5) { _ in applyConfiguration() }
                            .frame(maxWidth: 260)
                    }
                }

                if selectedStrategy == .stripNearby {
                    HStack {
                        Text("Radius: \(String(format: "%.1f m", stripRadius))")
                        Slider(value: $stripRadius, in: 0.5...20, step: 0.5) { _ in applyConfiguration() }
                            .frame(maxWidth: 260)
                    }
                }

                Toggle("Post-process deduplication", isOn: $enableDeduplication)
                    .onChange(of: enableDeduplication) { _, _ in applyConfiguration() }
            }
            .padding(.top, 6)
        }
    }

    private var actionBar: some View {
        HStack {
            Button {
                showImporter.toggle()
            } label: {
                Label("Select GPX Files", systemImage: "tray.and.arrow.down")
            }
            .buttonStyle(.borderedProminent)

            Spacer()
            Text("Drag & drop GPX files anywhere in this window")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var jobsList: some View {
        GroupBox("Processing Queue") {
            if viewModel.sortedJobs.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 34))
                        .foregroundStyle(.secondary)
                    Text("No jobs queued yet")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding()
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        ForEach(viewModel.sortedJobs) { job in
                            JobRowView(job: job) {
                                viewModel.cancel(jobID: job.id)
                            }
                            Divider()
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
        }
    }

    private func syncConfiguration() {
        let config = viewModel.configuration
        enableDeduplication = config.deduplicationRadius != nil
        switch config.compressionStrategy {
        case .ramerDouglasPeucker(let tolerance):
            rdpTolerance = tolerance
            selectedStrategy = .rdp
        case .stripNearby(let distance):
            stripRadius = distance
            selectedStrategy = .stripNearby
        case .random:
            selectedStrategy = .rdp
        case .stripDuplicates:
            selectedStrategy = .stripDuplicates
        }
    }

    private func applyConfiguration() {
        var config = viewModel.configuration
        switch selectedStrategy {
        case .rdp:
            config.compressionStrategy = .ramerDouglasPeucker(tolerance: rdpTolerance)
        case .stripNearby:
            config.compressionStrategy = .stripNearby(distance: stripRadius)
        case .stripDuplicates:
            config.compressionStrategy = .stripDuplicates
        }
        config.deduplicationRadius = enableDeduplication ? (config.deduplicationRadius ?? 1.5) : nil
        viewModel.configuration = config
    }
}

private enum StrategyOption: Hashable {
    case rdp
    case stripNearby
    case stripDuplicates
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(ProcessingViewModel())
    }
}
