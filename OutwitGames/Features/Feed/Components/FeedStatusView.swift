import SwiftUI

struct FeedLoadingView: View {
  var body: some View {
    FeedStatusSurface {
      ProgressView()
        .tint(.white)
        .controlSize(.large)
      Text("feed.loading")
        .font(OutwitTypography.body)
        .foregroundStyle(.white.opacity(0.72))
    }
    .accessibilityIdentifier("feed-loading")
  }
}

struct FeedErrorView: View {
  let messageKey: String
  let onRetry: () -> Void

  var body: some View {
    FeedStatusSurface {
      Image(systemName: "wifi.exclamationmark")
        .font(.system(size: 38, weight: .semibold))
        .foregroundStyle(.white.opacity(0.72))
        .accessibilityHidden(true)
      Text(LocalizedStringKey(messageKey))
        .font(OutwitTypography.body)
        .foregroundStyle(.white)
        .multilineTextAlignment(.center)
      Button("common.retry", action: onRetry)
        .buttonStyle(.outwitPrimary)
        .frame(maxWidth: 220)
    }
    .accessibilityIdentifier("feed-error")
  }
}

struct FeedEndView: View {
  let onRefresh: () -> Void

  var body: some View {
    FeedStatusSurface {
      Image("OutwitMarkWhite")
        .resizable()
        .scaledToFit()
        .frame(width: 64, height: 64)
        .accessibilityHidden(true)
      Text("feed.end.title")
        .font(OutwitTypography.headlineSmall)
        .foregroundStyle(.white)
      Text("feed.end.message")
        .font(OutwitTypography.bodySmall)
        .foregroundStyle(.white.opacity(0.72))
        .multilineTextAlignment(.center)
      Button("feed.refresh", action: onRefresh)
        .buttonStyle(.outwitPrimary)
        .frame(maxWidth: 220)
    }
    .accessibilityIdentifier("feed-end")
  }
}

struct FeedContinuationView: View {
  let isLoading: Bool
  let errorKey: String?
  let hasMore: Bool
  let onRetry: () -> Void
  let onRefresh: () -> Void

  var body: some View {
    if isLoading || (hasMore && errorKey == nil) {
      FeedLoadingView()
    } else if let errorKey {
      FeedErrorView(messageKey: errorKey, onRetry: onRetry)
    } else {
      FeedEndView(onRefresh: onRefresh)
    }
  }
}

private struct FeedStatusSurface<Content: View>: View {
  @ViewBuilder let content: () -> Content

  var body: some View {
    ZStack {
      LinearGradient(
        colors: [OutwitColors.graphite, OutwitColors.ink],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
      )
      VStack(spacing: OutwitSpacing.x4) {
        content()
      }
      .padding(OutwitSpacing.x8)
      .frame(maxWidth: 560)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }
}
