import Foundation
import Observation
import UIKit

@MainActor
@Observable
final class RewardsViewModel {
  private static let staleStoreErrors: Set<String> = [
    "insufficient_funds",
    "rewards_disabled",
    "not_eligible",
    "cash_out_locked",
    "geo_blocked",
    "item_not_found",
    "out_of_stock",
    "daily_cap_reached",
  ]

  private let rewardsRepository: any RewardsRepository
  private let referralsRepository: any ReferralsRepository
  private let homeRepository: any HomeRepository
  private let tokenStore: any TokenStore
  private let analytics: any AnalyticsTracking
  private let coordinator: AppCoordinator
  private let entrySource: RewardsEntrySource
  private let historyPollInterval: Duration

  private var operationTask: Task<Void, Never>?
  private var historyPollTask: Task<Void, Never>?
  private var revision = 0
  private var didTrackEntry = false
  private var didReadHistory = false
  private var analyticsRedemptionIDs: [Int: String] = [:]
  private var reportedOutcomes = Set<String>()
  private var knownStatuses: [Int: RewardRedemptionStatus] = [:]

  private(set) var phase = RewardsPhase.idle
  private(set) var catalog: RewardCatalog?
  private(set) var walletCoins = 0
  private(set) var playerInitials = "P"
  private(set) var isRegistered = false
  private(set) var referral: ReferralInfo?
  private(set) var isReferralLoading = false
  private(set) var referralErrorKey: String?
  private(set) var redemptions: [RewardRedemption] = []
  private(set) var isHistoryLoading = false
  private(set) var historyErrorKey: String?
  private(set) var redeemingSKU: String?
  private(set) var openedRedemption: OpenedRedemption?
  var selectedTab = RewardsTab.available
  var confirmationReward: RewardItem?
  var alertMessageKey: String?

  init(
    rewardsRepository: any RewardsRepository,
    referralsRepository: any ReferralsRepository,
    homeRepository: any HomeRepository,
    tokenStore: any TokenStore,
    analytics: any AnalyticsTracking,
    coordinator: AppCoordinator,
    entrySource: RewardsEntrySource,
    historyPollInterval: Duration = .seconds(30)
  ) {
    self.rewardsRepository = rewardsRepository
    self.referralsRepository = referralsRepository
    self.homeRepository = homeRepository
    self.tokenStore = tokenStore
    self.analytics = analytics
    self.coordinator = coordinator
    self.entrySource = entrySource
    self.historyPollInterval = historyPollInterval
  }

  var referralProgress: ReferralProgress {
    referral?.progress
      ?? catalog?.cashOut.referrals
      ?? ReferralProgress(qualified: 0, needed: 0, threshold: 0)
  }

  var isRedeeming: Bool { redeemingSKU != nil }

  var confirmationBalance: Int {
    guard let confirmationReward else { return walletCoins }
    return max(walletCoins - confirmationReward.coinCost, 0)
  }

  func loadIfNeeded() async {
    guard phase == .idle else { return }
    await load()
  }

  func load() async {
    guard !isRedeeming else { return }
    revision += 1
    let requestRevision = revision
    historyPollTask?.cancel()
    phase = .loading

    do {
      async let catalog = rewardsRepository.loadCatalog(geo: nil)
      async let wallet = homeRepository.loadWallet(forceRefresh: true)
      async let session = tokenStore.loadSession()
      let loaded = try await (catalog, wallet, session)
      try Task.checkCancellation()
      guard requestRevision == revision else { return }

      self.catalog = loaded.0
      walletCoins = loaded.1.coins
      isRegistered = loaded.2?.user.isRegistered == true
      playerInitials = Self.initials(from: loaded.2?.user.username)
      referral = nil
      redemptions = []
      referralErrorKey = nil
      historyErrorKey = nil
      phase = .loaded
      trackEntryIfNeeded()

      guard isRegistered else { return }
      await loadReferral()
      await loadHistory()
    } catch is CancellationError {
      return
    } catch {
      guard requestRevision == revision else { return }
      phase = .failed(messageKey: Self.messageKey(for: error))
    }
  }

  func refreshHistory() async {
    await loadHistory()
  }

  func reloadReferral() {
    operationTask?.cancel()
    operationTask = Task { [weak self] in await self?.loadReferral(showError: true) }
  }

  func requestRedemption(_ reward: RewardItem) {
    guard canRedeem(reward) else { return }
    confirmationReward = reward
  }

  func dismissConfirmation() {
    confirmationReward = nil
  }

  func confirmRedemption() {
    guard let reward = confirmationReward else { return }
    confirmationReward = nil
    guard canRedeem(reward) else { return }
    operationTask?.cancel()
    operationTask = Task { [weak self] in await self?.redeem(reward) }
  }

  func open(_ redemption: RewardRedemption) {
    guard redemption.hasOutcome else { return }
    openedRedemption = OpenedRedemption(
      redemption: redemption,
      source: .redeemedHistory
    )
  }

  func closeOutcome() {
    openedRedemption = nil
    selectedTab = .redeemed
  }

  func copyCode() {
    guard
      let openedRedemption,
      let code = openedRedemption.redemption.code,
      !code.isEmpty
    else {
      return
    }
    UIPasteboard.general.string = code
    track(
      .giftCardCodeCopied(
        openedRedemption.redemption,
        redemptionID: analyticsID(for: openedRedemption.redemption),
        source: openedRedemption.source
      )
    )
  }

  func outcomeAppeared() {
    guard
      let openedRedemption,
      openedRedemption.redemption.status == .fulfilled,
      openedRedemption.redemption.code?.isEmpty == false
    else {
      return
    }
    track(
      .giftCardViewed(
        openedRedemption.redemption,
        redemptionID: analyticsID(for: openedRedemption.redemption),
        source: openedRedemption.source
      )
    )
  }

  func openProfile() {
    coordinator.present(.profile)
  }

  func openLogin() {
    coordinator.push(.login)
  }

  func close() {
    guard !isRedeeming else { return }
    cancel()
    coordinator.back()
  }

  func dismissAlert() {
    alertMessageKey = nil
  }

  func cancel() {
    revision += 1
    operationTask?.cancel()
    historyPollTask?.cancel()
    operationTask = nil
    historyPollTask = nil
  }

  func canRedeem(_ reward: RewardItem) -> Bool {
    guard let cashOut = catalog?.cashOut else { return false }
    return redeemingSKU == nil
      && isRegistered
      && cashOut.rewardsEnabled
      && cashOut.unlocked
      && cashOut.eligible
      && reward.isInStock
      && reward.coinsNeeded(balance: walletCoins) == 0
  }

  private func loadReferral(showError: Bool = false) async {
    guard phase == .loaded, isRegistered else { return }
    isReferralLoading = true
    referralErrorKey = nil
    do {
      referral = try await referralsRepository.load()
      isReferralLoading = false
    } catch is CancellationError {
      return
    } catch {
      let key = Self.messageKey(for: error)
      isReferralLoading = false
      referralErrorKey = key
      if showError { alertMessageKey = key }
    }
  }

  private func loadHistory(silent: Bool = false) async {
    guard phase == .loaded, isRegistered else { return }
    if !silent {
      isHistoryLoading = true
      historyErrorKey = nil
    }
    do {
      let values = try await rewardsRepository.loadRedemptions()
      let returnedCoins = hasNewRefund(previous: redemptions, current: values)
      redemptions = values
      isHistoryLoading = false
      historyErrorKey = nil
      updateOpenedRedemption(from: values)
      reportTransitions(values)
      scheduleHistoryPoll(for: values)
      if returnedCoins { await refreshWallet() }
    } catch is CancellationError {
      return
    } catch {
      isHistoryLoading = false
      historyErrorKey = Self.messageKey(for: error)
    }
  }

  private func redeem(_ reward: RewardItem) async {
    guard canRedeem(reward) else { return }
    let analyticsID = UUID().uuidString
    redeemingSKU = reward.sku
    track(.redemptionInitiated(reward: reward, redemptionID: analyticsID, balance: walletCoins))

    do {
      let response = try await rewardsRepository.redeem(sku: reward.sku, geo: nil)
      let redemption = response.attaching(reward: reward)
      analyticsRedemptionIDs[redemption.id] = analyticsID
      let debit = redemption.status.returnsCoins ? 0 : reward.coinCost
      walletCoins = max(walletCoins - debit, 0)
      redemptions = merge(redemption, into: redemptions)
      redeemingSKU = nil
      knownStatuses[redemption.id] = redemption.status
      if redemption.hasOutcome {
        openedRedemption = OpenedRedemption(
          redemption: redemption,
          source: .redemptionSuccess
        )
      }
      reportOutcome(redemption, balance: walletCoins)
      await refreshAfterRedemption()
    } catch is CancellationError {
      redeemingSKU = nil
    } catch let error as AppError {
      redeemingSKU = nil
      if case .validation = error {
        reportKnownFailure(error, reward: reward, analyticsID: analyticsID)
      } else if case .forbidden = error {
        reportKnownFailure(error, reward: reward, analyticsID: analyticsID)
      } else {
        await handleUncertainRedemption()
      }
    } catch {
      redeemingSKU = nil
      await handleUncertainRedemption()
    }
  }

  private func reportKnownFailure(
    _ error: AppError,
    reward: RewardItem,
    analyticsID: String
  ) {
    if reportedOutcomes.insert(analyticsID).inserted {
      track(
        .redemptionFailed(
          rewardID: reward.sku,
          valueCents: reward.fiatValueCents,
          currency: reward.currency,
          redemptionID: analyticsID,
          coinsRequired: reward.coinCost,
          reason: error.messageKey,
          coinsRefunded: 0,
          balance: walletCoins
        )
      )
    }
    alertMessageKey = error.messageKey
    if Self.staleStoreErrors.contains(error.messageKey) {
      operationTask = Task { [weak self] in await self?.load() }
    }
  }

  private func handleUncertainRedemption() async {
    alertMessageKey = "redemption_status_uncertain"
    async let wallet: Void = refreshWallet()
    async let history: Void = loadHistory(silent: true)
    _ = await (wallet, history)
  }

  private func refreshAfterRedemption() async {
    await refreshWallet()
    if let updated = try? await rewardsRepository.loadCatalog(geo: nil) {
      catalog = updated
    }
    await loadHistory(silent: true)
  }

  private func refreshWallet() async {
    guard let wallet = try? await homeRepository.loadWallet(forceRefresh: true) else { return }
    walletCoins = wallet.coins
  }

  private func scheduleHistoryPoll(for values: [RewardRedemption]) {
    historyPollTask?.cancel()
    guard values.contains(where: { $0.status.isAwaitingFulfillment }) else { return }
    historyPollTask = Task { [weak self, historyPollInterval] in
      do {
        try await Task.sleep(for: historyPollInterval)
        try Task.checkCancellation()
        await self?.loadHistory(silent: true)
      } catch {
        return
      }
    }
  }

  private func updateOpenedRedemption(from values: [RewardRedemption]) {
    guard
      let openedRedemption,
      let updated = values.first(where: { $0.id == openedRedemption.redemption.id })
    else {
      return
    }
    guard updated.hasOutcome else {
      self.openedRedemption = nil
      selectedTab = .redeemed
      return
    }

    let becameReady = openedRedemption.redemption.status != .fulfilled
      && updated.status == .fulfilled
      && updated.code?.isEmpty == false
    self.openedRedemption = OpenedRedemption(
      redemption: updated,
      source: openedRedemption.source
    )
    if becameReady {
      track(
        .giftCardViewed(
          updated,
          redemptionID: analyticsID(for: updated),
          source: openedRedemption.source
        )
      )
    }
  }

  private func trackEntryIfNeeded() {
    guard !didTrackEntry else { return }
    didTrackEntry = true
    track(.rewardsViewed(source: entrySource, tab: selectedTab, balance: walletCoins))
  }

  private func reportTransitions(_ values: [RewardRedemption]) {
    let isBaseline = !didReadHistory
    didReadHistory = true
    for value in values {
      let previous = knownStatuses.updateValue(value.status, forKey: value.id)
      if isBaseline, analyticsRedemptionIDs[value.id] == nil { continue }
      guard previous != value.status else { continue }
      reportOutcome(value, balance: walletCoins)
    }
  }

  private func reportOutcome(_ redemption: RewardRedemption, balance: Int) {
    let fulfilled = redemption.status == .fulfilled
    guard fulfilled || redemption.status.returnsCoins else { return }
    let analyticsID = analyticsID(for: redemption)
    guard reportedOutcomes.insert(analyticsID).inserted else { return }
    if fulfilled {
      track(.rewardRedeemed(redemption, redemptionID: analyticsID, balance: balance))
    } else {
      track(
        .redemptionFailed(
          rewardID: redemption.rewardSKU ?? "",
          valueCents: redemption.fiatValueCents,
          currency: redemption.currency,
          redemptionID: analyticsID,
          coinsRequired: redemption.coinCost,
          reason: redemption.status == .rejected ? "rejected" : "refunded",
          coinsRefunded: redemption.coinCost,
          balance: balance
        )
      )
    }
  }

  private func analyticsID(for redemption: RewardRedemption) -> String {
    analyticsRedemptionIDs[redemption.id] ?? "redemption:\(redemption.id)"
  }

  private func track(_ event: AnalyticsEvent) {
    Task { [analytics] in await analytics.track(event) }
  }

  private func merge(
    _ redemption: RewardRedemption,
    into values: [RewardRedemption]
  ) -> [RewardRedemption] {
    [redemption] + values.filter { $0.id != redemption.id }
  }

  private func hasNewRefund(
    previous: [RewardRedemption],
    current: [RewardRedemption]
  ) -> Bool {
    let statuses = Dictionary(uniqueKeysWithValues: previous.map { ($0.id, $0.status) })
    return current.contains { $0.status.returnsCoins && statuses[$0.id] != $0.status }
  }

  private static func initials(from username: String?) -> String {
    let initials = (username ?? "")
      .split(whereSeparator: \Character.isWhitespace)
      .prefix(2)
      .compactMap(\.first)
    return initials.isEmpty ? "P" : String(initials).uppercased()
  }

  private static func messageKey(for error: Error) -> String {
    (error as? AppError)?.messageKey ?? "something_wrong"
  }
}
