import SwiftUI
import AVKit
import WebKit

// MARK: - Watch source

/// How a given service is watched in-app. Facebook / unknown platforms are
/// handled by ServiceDetailView as a link-out (openURL), not here.
enum WatchSource: Identifiable, Hashable {
    case youtube(videoId: String)     // embed the SPECIFIC live video (reliable)
    case hls(url: URL)                // direct .m3u8 via AVPlayer

    var id: String {
        switch self {
        case .youtube(let v): return "yt:\(v)"
        case .hls(let u): return "hls:\(u.absoluteString)"
        }
    }
}

// MARK: - Full-screen watch view

struct WatchView: View {
    let source: WatchSource
    let churchName: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.black.ignoresSafeArea()

            switch source {
            case .youtube(let videoId):
                YouTubeLiveEmbedView(videoId: videoId)
                    .ignoresSafeArea(edges: .horizontal)
            case .hls(let url):
                HLSPlayerView(url: url)
                    .ignoresSafeArea(edges: .horizontal)
            }

            HStack(spacing: 10) {
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 40, height: 40)
                        .background(Color.black.opacity(0.45))
                        .clipShape(Circle())
                }
                Text(churchName)
                    .font(.coUI(13, weight: .medium))
                    .foregroundColor(.white.opacity(0.9))
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
        }
    }
}

// MARK: - YouTube live embed (official iframe — never raw HLS extraction)

struct YouTubeLiveEmbedView: UIViewRepresentable {
    let videoId: String

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.isOpaque = false
        webView.backgroundColor = .black
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.backgroundColor = .black
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        let html = """
        <!DOCTYPE html><html><head>
        <meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1">
        <style>html,body{margin:0;height:100%;background:#000;overflow:hidden;}
        .wrap{position:relative;width:100%;height:100%;}
        iframe{position:absolute;top:0;left:0;width:100%;height:100%;border:0;}</style>
        </head><body><div class="wrap">
        <iframe src="https://www.youtube.com/embed/\(videoId)?autoplay=1&playsinline=1&rel=0&modestbranding=1"
          allow="autoplay; encrypted-media; picture-in-picture" allowfullscreen></iframe>
        </div></body></html>
        """
        webView.loadHTMLString(html, baseURL: URL(string: "https://www.youtube.com"))
    }
}

// MARK: - Direct HLS player

struct HLSPlayerView: View {
    let url: URL
    @State private var player: AVPlayer?

    var body: some View {
        VideoPlayer(player: player)
            .onAppear {
                if player == nil { player = AVPlayer(url: url) }
                player?.play()
            }
            .onDisappear { player?.pause() }
    }
}
