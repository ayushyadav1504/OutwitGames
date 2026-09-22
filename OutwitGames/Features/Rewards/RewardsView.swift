import SwiftUI

struct RewardsView: View {
  @State private var viewModel: RewardsViewModel
  private let coordinator: AppCoordinator
  private let route: AppRoute

  init(
    rewardsRepository: any RewardsRepository,
    referralsRepository: any ReferralsRepository,
    homeRepository: any HomeRepository,
    tokenStore: any TokenStore,
    analytics: any AnalyticsTracking,
    coordinator: AppCoordinator,
    entrySource: RewardsEntrySource
  ) {
    self.coordinator = coordinator
    route = .rewards(entrySource)
    _viewModel = State(
      initialValue: RewardsViewModel(
        rewardsRepository: rewardsRepository,
        referralsRepository: referralsRepository,
        homeRepository: homeRepository,
        tokenStore: tokenStore,
        analytics: analytics,
        coordinator: coordinator,
        entrySource: entrySource
      )
    )
  }

  var body: some View {
    Group {
      if let opened = viewModel.openedRedemption {
        RewardOutcomeView(
          redemption: opened.redemption,
          onDone: viewModel.closeOutcome,
          onCopy: viewModel.copyCode,
          onAppear: viewModel.outcomeAppeared
        )
      } else {
        store
      }
    }
    .navigationTitle("screen.rewards.title")
    .navigationBarTitleDisplayMode(.inline)
    .navigationBarBackButtonHidden(viewModel.isRedeeming)
    .toolbar { toolbarContent }
    .task { await viewModel.loadIfNeeded() }
    .onDisappear(perform: handleDisappearance)
    .sheet(item: confirmationBinding) { reward in
      RewardConfirmationView(
        reward: reward,
        balanceAfter: viewModel.confirmationBalance,
        onConfirm: viewModel.confirmRedemption
      )
    }
    .alert(
      "rewards.error.title",
      isPresented: alertBinding,
      actions: { Button("common.ok", role: .cancel, action: viewModel.dismissAlert) },
      message: {
        if let key = viewModel.alertMessageKey { Text(LocalizedStringKey(key)) }
      }
    )
    .background(OutwitColors.softWhite.ignoresSafeArea())
  }

  @ViewBuilder
  private var store: some View {
    switch viewModel.phase {
    case .idle, .loading:
      ProgressView().controlSize(.large)
    case .failed(let messageKey):
      ContentUnavailableView {
        Label("rewards.error.title", systemImage: "wifi.exclamationmark")
      } description: {
        Text(LocalizedStringKey(messageKey))
      } actions: {
        Button("common.retry") { Task { await viewModel.load() } }
          .buttonStyle(.borderedProminent)
          .tint(OutwitColors.action)
      }
    case .loaded:
      RewardsStoreContent(viewModel: viewModel)
    }
  }

  @ToolbarContentBuilder
  private var toolbarContent: some ToolbarContent {
    ToolbarItemGroup(placement: .topBarTrailing) {
      HStack(spacing: OutwitSpacing.x1) {
        Image("OutwitCoin3D")
          .resizable()
          .scaledToFit()
          .frame(width: 25, height: 25)
        Text(viewModel.walletCoins, format: .number)
          .font(OutwitTypography.label)
      }
      .accessibilityElement(children: .combine)

      Button(action: viewModel.openProfile) {
        Text(verbatim: viewModel.playerInitials)
          .font(OutwitTypography.bodySmall.weight(.bold))
          .frame(width: 34, height: 34)
          .background(OutwitColors.redTint, in: Circle())
      }
      .accessibilityLabel("feed.profile")
    }
  }

  private var confirmationBinding: Binding<RewardItem?> {
    Binding(
      get: { viewModel.confirmationReward },
      set: { if $0 == nil { viewModel.dismissConfirmation() } }
    )
  }

  private var alertBinding: Binding<Bool> {
    Binding(
      get: { viewModel.alertMessageKey != nil },
      set: { if !$0 { viewModel.dismissAlert() } }
    )
  }

  private func handleDisappearance() {
    Task { @MainActor in
      await Task.yield()
      let current = coordinator.path.last ?? coordinator.root
      if current != route { viewModel.cancel() }
    }
  }
}

private struct RewardsStoreContent: View {
  @Bindable var viewModel: RewardsViewModel

  var body: some View {
    ScrollView {
      LazyVStack(spacing: OutwitSpacing.x4) {
        heading

        Picker("screen.rewards.title", selection: $viewModel.selectedTab) {
          Text("rewards.tab.available").tag(RewardsTab.available)
          Text("rewards.tab.redeemed").tag(RewardsTab.redeemed)
        }
        .pickerStyle(.segmented)

        if viewModel.selectedTab == .available {
          available
        } else {
          redeemed
        }
      }
      .padding(OutwitSpacing.pageGutter)
      .padding(.bottom, OutwitSpacing.x6)
    }
    .refreshable {
      if viewModel.selectedTab == .available {
        await viewModel.load()
      } else {
        await viewModel.refreshHistory()
      }
    }
  }

  private var heading: some View {
    VStack(alignment: .leading, spacing: OutwitSpacing.x1) {
      Text("screen.rewards.title")
        .font(OutwitTypography.headlineLarge)
        .foregroundStyle(OutwitColors.ink)
      Text(subtitleKey)
      .font(OutwitTypography.bodySmall)
      .foregroundStyle(OutwitColors.mutedInk)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  private var subtitleKey: LocalizedStringKey {
    viewModel.selectedTab == .available
      ? "rewards.available.subtitle"
      : "rewards.redeemed.subtitle"
  }

  @ViewBuilder
  private var available: some View {
    if !viewModel.isRegistered {
      registrationCard
    } else if viewModel.catalog?.cashOut.unlocked == false {
      ReferralGateView(
        progress: viewModel.referralProgress,
        referral: viewModel.referral,
        isLoading: viewModel.isReferralLoading,
        errorKey: viewModel.referralErrorKey,
        onReload: viewModel.reloadReferral
      )
    }

    if let cashOut = viewModel.catalog?.cashOut {
      if !cashOut.rewardsEnabled {
        notice(title: "rewards.unavailable.title", message: "rewards.unavailable.message")
      } else if viewModel.isRegistered, cashOut.unlocked, !cashOut.eligible {
        notice(
          title: "rewards.cashout.unavailable.title",
          message: "rewards.cashout.unavailable.message"
        )
      }

      if cashOut.rewardsEnabled {
        rewardCatalogue(cashOut: cashOut)
      }
    }
  }

  private var registrationCard: some View {
    VStack(spacing: OutwitSpacing.x3) {
      Text("rewards.login.title")
        .font(OutwitTypography.headlineSmall)
      Text("rewards.login.message")
        .font(OutwitTypography.bodySmall)
        .foregroundStyle(OutwitColors.mutedInk)
        .multilineTextAlignment(.center)
      Button("rewards.login.action", action: viewModel.openLogin)
        .buttonStyle(.outwitPrimary)
    }
    .padding(OutwitSpacing.x6)
    .frame(maxWidth: .infinity)
    .background(.white, in: RoundedRectangle(cornerRadius: OutwitRadius.card))
    .overlay(RoundedRectangle(cornerRadius: OutwitRadius.card).stroke(OutwitColors.paleBorder))
  }

  private func rewardCatalogue(cashOut: CashOutEligibility) -> some View {
    let rewards = viewModel.catalog?.rewards ?? []
    return VStack(spacing: OutwitSpacing.x3) {
      HStack {
        Text("rewards.catalog")
          .font(OutwitTypography.headlineSmall)
        Spacer()
        Text(rewards.count, format: .number)
          .font(OutwitTypography.bodySmall)
          .foregroundStyle(OutwitColors.mutedInk)
      }

      if rewards.isEmpty {
        notice(title: "rewards.empty.title", message: "rewards.empty.message")
      } else {
        LazyVGrid(
          columns: [GridItem(.flexible()), GridItem(.flexible())],
          spacing: OutwitSpacing.x3
        ) {
          ForEach(rewards) { reward in
            RewardCard(
              reward: reward,
              balance: viewModel.walletCoins,
              cashOut: cashOut,
              isRegistered: viewModel.isRegistered,
              redeemingSKU: viewModel.redeemingSKU,
              onRedeem: { viewModel.requestRedemption(reward) }
            )
          }
        }
      }
    }
  }

  private var redeemed: some View {
    Group {
      if viewModel.isRegistered {
        RedemptionHistoryView(
          redemptions: viewModel.redemptions,
          isLoading: viewModel.isHistoryLoading,
          errorKey: viewModel.historyErrorKey,
          onBrowse: { viewModel.selectedTab = .available },
          onOpen: viewModel.open
        )
      } else {
        registrationCard
      }
    }
  }

  private func notice(title: LocalizedStringKey, message: LocalizedStringKey) -> some View {
    VStack(spacing: OutwitSpacing.x2) {
      Text(title)
        .font(OutwitTypography.headlineSmall)
      Text(message)
        .font(OutwitTypography.bodySmall)
        .foregroundStyle(OutwitColors.mutedInk)
        .multilineTextAlignment(.center)
    }
    .padding(OutwitSpacing.x6)
    .frame(maxWidth: .infinity)
    .background(.white, in: RoundedRectangle(cornerRadius: OutwitRadius.card))
    .overlay(RoundedRectangle(cornerRadius: OutwitRadius.card).stroke(OutwitColors.paleBorder))
  }
}
