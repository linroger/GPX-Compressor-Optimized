import Foundation

public struct GPXProcessingJob: Sendable, Hashable, Identifiable {
    public let id: UUID
    public let inputURL: URL
    public let outputURL: URL
    public let configuration: GPXProcessingConfiguration

    public init(id: UUID = UUID(), inputURL: URL, outputURL: URL, configuration: GPXProcessingConfiguration) {
        self.id = id
        self.inputURL = inputURL
        self.outputURL = outputURL
        self.configuration = configuration
    }
}
