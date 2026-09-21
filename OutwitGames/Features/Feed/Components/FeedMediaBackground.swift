import AVFoundation
import AVKit
import SwiftUI

struct FeedMediaBackground: View {
  let challenge: FeedChallenge
  let isActive: Bool

  var body: some View {
    ZStack {
      fallback

      if let videoURL = challenge.backgroundVideoURL {
        LoopingVideo(url: videoURL, isPlaying: isActive)
          .transition(.opacity)
      }

      LinearGradient(
        colors: [.black.opacity(0.08), .black.opacity(0.16), .black.opacity(0.58)],
        startPoint: .top,
        endPoint: .bottom
      )

      if let audioURL = challenge.backgroundAudioURL {
        LoopingAudio(url: audioURL, isPlaying: isActive)
      }
    }
    .clipped()
  }

  @ViewBuilder
  private var fallback: some View {
    if let imageURL = challenge.heroImageURL {
      AsyncImage(url: imageURL, transaction: Transaction(animation: .easeInOut(duration: 0.25))) {
        phase in
        switch phase {
        case .success(let image):
          image.resizable().scaledToFill()
        default:
          fallbackGradient
        }
      }
    } else {
      fallbackGradient
    }
  }

  private var fallbackGradient: some View {
    LinearGradient(
      colors: [OutwitColors.graphite, OutwitColors.ink, OutwitColors.actionPressed.opacity(0.7)],
      startPoint: .topLeading,
      endPoint: .bottomTrailing
    )
  }
}

private struct LoopingVideo: View {
  let isPlaying: Bool
  @State private var controller: LoopingPlayerController

  init(url: URL, isPlaying: Bool) {
    self.isPlaying = isPlaying
    _controller = State(initialValue: LoopingPlayerController(url: url, isMuted: true))
  }

  var body: some View {
    VideoPlayer(player: controller.player)
      .scaledToFill()
      .allowsHitTesting(false)
      .onChange(of: isPlaying, initial: true) { _, playing in
        controller.setPlaying(playing)
      }
      .onDisappear { controller.setPlaying(false) }
  }
}

private struct LoopingAudio: View {
  let isPlaying: Bool
  @State private var controller: LoopingPlayerController

  init(url: URL, isPlaying: Bool) {
    self.isPlaying = isPlaying
    _controller = State(initialValue: LoopingPlayerController(url: url, isMuted: false))
  }

  var body: some View {
    Color.clear
      .frame(width: 0, height: 0)
      .accessibilityHidden(true)
      .onChange(of: isPlaying, initial: true) { _, playing in
        controller.setPlaying(playing)
      }
      .onDisappear { controller.setPlaying(false) }
  }
}

@MainActor
private final class LoopingPlayerController {
  let player: AVQueuePlayer
  private let looper: AVPlayerLooper

  init(url: URL, isMuted: Bool) {
    let player = AVQueuePlayer()
    let item = AVPlayerItem(url: url)
    self.player = player
    looper = AVPlayerLooper(player: player, templateItem: item)
    player.isMuted = isMuted
  }

  func setPlaying(_ shouldPlay: Bool) {
    if shouldPlay {
      player.play()
    } else {
      player.pause()
    }
  }

  deinit {
    player.pause()
  }
}
