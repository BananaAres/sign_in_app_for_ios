import SwiftUI
import WebKit

/// 内置 WebView，用于在应用内打开网页（如隐私政策）
struct InAppWebView: UIViewControllerRepresentable {
    let url: URL
    var title: String?

    func makeUIViewController(context: Context) -> InAppWebViewController {
        InAppWebViewController(url: url)
    }

    func updateUIViewController(_ uiViewController: InAppWebViewController, context: Context) {}
}

final class InAppWebViewController: UIViewController {
    private let url: URL
    private var webView: WKWebView!

    init(url: URL) {
        self.url = url
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        let config = WKWebViewConfiguration()
        let wv = WKWebView(frame: .zero, configuration: config)
        wv.navigationDelegate = self
        webView = wv
        view = wv
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        webView.load(URLRequest(url: url))
    }
}

extension InAppWebViewController: WKNavigationDelegate {}
