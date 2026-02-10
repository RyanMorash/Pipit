//
//  HTMLTextView.swift
//  Pipit
//
//  View for rendering HTML text content
//

import SwiftUI

struct HTMLTextView: View {
    let htmlString: String
    let font: Font
    
    @State private var attributedString: AttributedString?
    
    init(_ htmlString: String, font: Font = .body) {
        self.htmlString = htmlString
        self.font = font
    }
    
    var body: some View {
        Group {
            if let attributedString {
                Text(attributedString)
            } else {
                Text(htmlString)
                    .task {
                        attributedString = await convertHTMLToAttributedString(htmlString)
                    }
            }
        }
    }
    
    private func convertHTMLToAttributedString(_ html: String) async -> AttributedString? {
        // Add basic HTML structure if not present
        var fullHTML = html
        if !html.lowercased().contains("<html") {
            fullHTML = """
            <html>
            <head>
                <style>
                    body {
                        font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif;
                        font-size: \(getFontSize())px;
                        line-height: 1.5;
                        color: \(getTextColor());
                    }
                    a {
                        color: #007AFF;
                        text-decoration: none;
                    }
                    p {
                        margin: 0.5em 0;
                    }
                    strong, b {
                        font-weight: 600;
                    }
                </style>
            </head>
            <body>\(html)</body>
            </html>
            """
        }
        
        guard let data = fullHTML.data(using: .utf8) else {
            return nil
        }
        
        do {
            let nsAttributedString = try NSAttributedString(
                data: data,
                options: [
                    .documentType: NSAttributedString.DocumentType.html,
                    .characterEncoding: String.Encoding.utf8.rawValue
                ],
                documentAttributes: nil
            )
            
            var attributedString = AttributedString(nsAttributedString)
            
            // Apply the SwiftUI font style
            attributedString.font = convertToSwiftUIFont(font)
            
            return attributedString
        } catch {
            print("Error converting HTML: \(error)")
            return AttributedString(html)
        }
    }
    
    private func getFontSize() -> Int {
        // Return appropriate font size based on the font style
        switch font {
        case .largeTitle:
            return 34
        case .title:
            return 28
        case .title2:
            return 22
        case .title3:
            return 20
        case .headline:
            return 17
        case .body:
            return 17
        case .callout:
            return 16
        case .subheadline:
            return 15
        case .footnote:
            return 13
        case .caption:
            return 12
        case .caption2:
            return 11
        default:
            return 17
        }
    }
    
    private func getTextColor() -> String {
#if os(iOS)
        return UITraitCollection.current.userInterfaceStyle == .dark ? "#FFFFFF" : "#000000"
#else
        return NSApp.effectiveAppearance.name == .darkAqua ? "#FFFFFF" : "#000000"
#endif
    }
    
    private func convertToSwiftUIFont(_ font: Font) -> Font {
        // The font parameter is already a SwiftUI Font, return as-is
        return font
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 20) {
        HTMLTextView("<p>This is a <strong>bold</strong> text with <a href='https://example.com'>a link</a>.</p>")
        
        HTMLTextView("<p>Paragraph 1</p><p>Paragraph 2 with <em>italic</em> text.</p>")
        
        HTMLTextView("""
            <p>Check out this <a href="https://floatplane.com">Floatplane</a> content!</p>
            <p>Features include:</p>
            <ul>
                <li><strong>High quality</strong> videos</li>
                <li><em>Early access</em> to content</li>
            </ul>
            """)
    }
    .padding()
}
