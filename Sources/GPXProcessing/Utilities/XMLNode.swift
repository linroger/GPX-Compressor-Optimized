import Foundation

/// Lightweight XML representation used to preserve metadata while streaming GPX data.
public struct GPXXMLNode: Sendable, Hashable {
    public let name: String
    public let attributes: [String: String]
    public let text: String?
    public let children: [GPXXMLNode]

    public init(name: String, attributes: [String: String] = [:], text: String? = nil, children: [GPXXMLNode] = []) {
        self.name = name
        self.attributes = attributes
        self.text = text
        self.children = children
    }

    /// Render the node as GPX/XML markup.
    public func render(indentation: Int = 0) -> String {
        let indent = String(repeating: "\t", count: indentation)
        let attributeString = attributes.sorted { $0.key < $1.key }
            .map { " \($0.key)=\"\($0.value.xmlEscaped())\"" }
            .joined()

        if children.isEmpty && (text == nil || text?.isEmpty == true) {
            return "\(indent)<\(name)\(attributeString)/>\n"
        }

        var output = "\(indent)<\(name)\(attributeString)>"
        if !children.isEmpty {
            output.append("\n")
            for child in children {
                output.append(child.render(indentation: indentation + 1))
            }
            output.append("\(indent)</\(name)>\n")
        } else if let text {
            output.append(text.xmlEscaped())
            output.append("</\(name)>\n")
        } else {
            output.append("</\(name)>\n")
        }
        return output
    }

    /// Builder that makes it easy to construct tree structures while parsing.
    public final class Builder {
        public let name: String
        public var attributes: [String: String]
        public var textFragments: [String] = []
        public var children: [GPXXMLNode] = []

        public init(name: String, attributes: [String: String] = [:]) {
            self.name = name
            self.attributes = attributes
        }

        public func append(text: String) {
            if !text.isEmpty {
                textFragments.append(text)
            }
        }

        public func append(child: GPXXMLNode) {
            children.append(child)
        }

        public func build() -> GPXXMLNode {
            let combined = textFragments.joined()
            return GPXXMLNode(name: name, attributes: attributes, text: combined.isEmpty ? nil : combined, children: children)
        }
    }
}

private extension String {
    func xmlEscaped() -> String {
        var output = self
        output = output.replacingOccurrences(of: "&", with: "&amp;")
        output = output.replacingOccurrences(of: "\"", with: "&quot;")
        output = output.replacingOccurrences(of: "'", with: "&apos;")
        output = output.replacingOccurrences(of: "<", with: "&lt;")
        output = output.replacingOccurrences(of: ">", with: "&gt;")
        return output
    }
}
