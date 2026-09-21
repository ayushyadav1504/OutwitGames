import SwiftUI
import WebKit

struct HostedGameView: UIViewRepresentable {
  let launch: ChallengeLaunch
  let hostOrigin: URL
  let isPaused: Bool
  let onPageLoaded: () -> Void
  let onPageLoadFailed: (String) -> Void
  let onHUDEvent: (GameHUDEvent) -> Void

  func makeCoordinator() -> Coordinator {
    Coordinator(parent: self)
  }

  func makeUIView(context: Context) -> WKWebView {
    let contentController = WKUserContentController()
    do {
      let script = try GameBridge.documentStartScript(
        configuration: launch.hostConfiguration,
        lifecycle: isPaused ? .paused : .active
      )
      contentController.addUserScript(
        WKUserScript(
          source: script,
          injectionTime: .atDocumentStart,
          forMainFrameOnly: true
        )
      )
    } catch {
      onPageLoadFailed(AppError.parsing.messageKey)
    }
    contentController.addScriptMessageHandler(
      context.coordinator,
      contentWorld: .page,
      name: GameBridge.hostHandler
    )
    contentController.addScriptMessageHandler(
      context.coordinator,
      contentWorld: .page,
      name: GameBridge.lifecycleHandler
    )

    let configuration = WKWebViewConfiguration()
    configuration.userContentController = contentController
    configuration.websiteDataStore = .nonPersistent()
    configuration.allowsInlineMediaPlayback = true
    configuration.mediaTypesRequiringUserActionForPlayback = []
    configuration.preferences.javaScriptCanOpenWindowsAutomatically = false
    configuration.defaultWebpagePreferences.allowsContentJavaScript = true

    let webView = WKWebView(frame: .zero, configuration: configuration)
    webView.navigationDelegate = context.coordinator
    webView.uiDelegate = context.coordinator
    webView.isOpaque = true
    webView.backgroundColor = .black
    webView.scrollView.backgroundColor = .black
    webView.scrollView.bounces = false
    webView.scrollView.showsHorizontalScrollIndicator = false
    webView.scrollView.showsVerticalScrollIndicator = false
    #if DEBUG
      if #available(iOS 16.4, *) { webView.isInspectable = true }
    #endif
    context.coordinator.webView = webView
    webView.load(URLRequest(url: launch.entryURL, cachePolicy: .reloadIgnoringLocalCacheData))
    return webView
  }

  func updateUIView(_ webView: WKWebView, context: Context) {
    context.coordinator.parent = self
    context.coordinator.updateLifecycle(isPaused ? .paused : .active)
  }

  static func dismantleUIView(_ webView: WKWebView, coordinator: Coordinator) {
    webView.stopLoading()
    webView.navigationDelegate = nil
    webView.uiDelegate = nil
    webView.configuration.userContentController.removeScriptMessageHandler(
      forName: GameBridge.hostHandler,
      contentWorld: .page
    )
    webView.configuration.userContentController.removeScriptMessageHandler(
      forName: GameBridge.lifecycleHandler,
      contentWorld: .page
    )
    coordinator.webView = nil
  }

  @MainActor
  final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate,
    WKScriptMessageHandlerWithReply
  {
    var parent: HostedGameView
    weak var webView: WKWebView?

    private let navigationPolicy: GameNavigationPolicy
    private var lifecycle: GameLifecycleState
    private var requestSequence = 0

    init(parent: HostedGameView) {
      self.parent = parent
      navigationPolicy = GameNavigationPolicy(entryURL: parent.launch.entryURL)
      lifecycle = parent.isPaused ? .paused : .active
    }

    func updateLifecycle(_ lifecycle: GameLifecycleState) {
      guard self.lifecycle != lifecycle else { return }
      self.lifecycle = lifecycle
      guard let webView,
        let script = try? GameBridge.lifecycleScript(lifecycle, hostOrigin: parent.hostOrigin)
      else {
        return
      }
      webView.evaluateJavaScript(script)
    }

    func webView(
      _ webView: WKWebView,
      decidePolicyFor navigationAction: WKNavigationAction,
      decisionHandler: @escaping @MainActor @Sendable (WKNavigationActionPolicy) -> Void
    ) {
      let allowed = navigationPolicy.allows(navigationAction.request.url)
      decisionHandler(allowed ? .allow : .cancel)
    }

    func webView(
      _ webView: WKWebView,
      decidePolicyFor navigationResponse: WKNavigationResponse,
      decisionHandler: @escaping @MainActor @Sendable (WKNavigationResponsePolicy) -> Void
    ) {
      guard navigationResponse.isForMainFrame else {
        decisionHandler(.allow)
        return
      }
      if let response = navigationResponse.response as? HTTPURLResponse,
        !(200..<400).contains(response.statusCode)
      {
        parent.onPageLoadFailed(AppError.server().messageKey)
        decisionHandler(.cancel)
      } else {
        decisionHandler(.allow)
      }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
      parent.onPageLoaded()
      requestHUDState()
    }

    func webView(
      _ webView: WKWebView,
      didFailProvisionalNavigation navigation: WKNavigation!,
      withError error: any Error
    ) {
      guard (error as NSError).code != NSURLErrorCancelled else { return }
      parent.onPageLoadFailed(AppError.server(messageKey: "game_load_failed").messageKey)
    }

    func webView(
      _ webView: WKWebView,
      createWebViewWith configuration: WKWebViewConfiguration,
      for navigationAction: WKNavigationAction,
      windowFeatures: WKWindowFeatures
    ) -> WKWebView? {
      if navigationPolicy.allows(navigationAction.request.url) {
        webView.load(navigationAction.request)
      }
      return nil
    }

    func userContentController(
      _ userContentController: WKUserContentController,
      didReceive message: WKScriptMessage,
      replyHandler: @escaping @MainActor @Sendable (Any?, String?) -> Void
    ) {
      guard message.frameInfo.isMainFrame else {
        replyHandler(nil, "Subframe messages are not accepted")
        return
      }

      switch message.name {
      case GameBridge.lifecycleHandler:
        replyHandler(["version": 1, "state": lifecycle.rawValue], nil)
      case GameBridge.hostHandler:
        if let event = GameHUDMessageParser.parse(message.body) {
          parent.onHUDEvent(event)
          if event == .ready { requestHUDState() }
        }
        replyHandler(nil, nil)
      default:
        replyHandler(nil, "Unknown handler")
      }
    }

    private func requestHUDState() {
      guard let webView else { return }
      let requestID = "native-\(requestSequence)"
      requestSequence += 1
      guard
        let script = try? GameBridge.stateRequestScript(
          requestID: requestID, hostOrigin: parent.hostOrigin)
      else {
        return
      }
      webView.evaluateJavaScript(script)
    }
  }
}
