import SwiftUI

struct ProfileView: View {
  @Environment(\.dismiss) private var dismiss
  @Environment(\.openURL) private var openURL
  @Environment(\.scenePhase) private var scenePhase
  @State private var viewModel: ProfileViewModel
  @State private var deletionConfirmation = ""

  init(
    settings: AppSettings,
    tokenStore: any TokenStore,
    authRepository: any AuthRepository,
    notifications: any NotificationPermissionRequesting,
    consent: any AdConsentServicing,
    analytics: any AnalyticsTracking,
    configuration: AppConfiguration,
    coordinator: AppCoordinator
  ) {
    _viewModel = State(
      initialValue: ProfileViewModel(
        settings: settings,
        tokenStore: tokenStore,
        authRepository: authRepository,
        notifications: notifications,
        consent: consent,
        analytics: analytics,
        configuration: configuration,
        coordinator: coordinator
      )
    )
  }

  var body: some View {
    NavigationStack {
      content
        .navigationTitle("screen.profile.title")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
          ToolbarItem(placement: .topBarTrailing) {
            Button(action: { dismiss() }) {
              Image(systemName: "xmark.circle.fill")
                .symbolRenderingMode(.hierarchical)
            }
            .foregroundStyle(OutwitColors.mutedInk)
            .accessibilityLabel("common.close")
          }
        }
        .navigationDestination(for: ProfileDestination.self) { destination in
          switch destination {
          case .language:
            ProfileLanguageSettingsView(viewModel: viewModel)
          }
        }
    }
    .font(OutwitTypography.body)
    .interactiveDismissDisabled(viewModel.isBusy)
    .presentationDetents([.fraction(0.72)])
    .presentationDragIndicator(.visible)
    .task { await viewModel.load() }
    .onChange(of: scenePhase) { _, phase in
      guard phase == .active else { return }
      Task { await viewModel.refreshNotificationState() }
    }
    .alert(
      "profile.delete.title",
      isPresented: deletionConfirmationBinding,
      actions: {
        TextField("profile.delete.placeholder", text: $deletionConfirmation)
          .textInputAutocapitalization(.characters)
          .autocorrectionDisabled()
        Button("profile.delete.confirm", role: .destructive) {
          Task {
            await viewModel.confirmAccountDeletion(confirmation: deletionConfirmation)
          }
        }
        .disabled(!isDeletionConfirmationValid)
        Button("common.cancel", role: .cancel, action: viewModel.cancelAccountDeletion)
      },
      message: { Text("profile.delete.message") }
    )
    .alert(
      "profile.error.title",
      isPresented: errorBinding,
      actions: {
        Button("common.ok", role: .cancel, action: viewModel.dismissError)
      },
      message: {
        if let key = viewModel.actionErrorKey {
          Text(LocalizedStringKey(key))
        }
      }
    )
  }

  @ViewBuilder
  private var content: some View {
    switch viewModel.state {
    case .idle, .loading:
      ProgressView()
        .tint(OutwitColors.action)
        .controlSize(.large)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(OutwitColors.softWhite)
    case .loaded(let identity):
      settingsList(identity: identity)
    case .failed(let messageKey):
      ContentUnavailableView {
        Label("profile.error.title", systemImage: "person.crop.circle.badge.exclamationmark")
      } description: {
        Text(LocalizedStringKey(messageKey))
      } actions: {
        Button("common.retry") { Task { await viewModel.load() } }
          .buttonStyle(.outwitPrimary)
          .frame(maxWidth: 300)
      }
      .background(OutwitColors.softWhite)
    }
  }

  private func settingsList(identity: ProfileIdentity) -> some View {
    List {
      Section {
        ProfileIdentityView(identity: identity)
          .listRowBackground(Color.white)

        if !identity.isRegistered {
          Button("profile.login", action: viewModel.openLogin)
            .buttonStyle(.outwitPrimary)
            .padding(.vertical, OutwitSpacing.x1)
            .listRowBackground(Color.white)
            .accessibilityIdentifier("profile-login")
        }
      }

      Section("profile.settings.section") {
        if viewModel.showsNotificationSetting {
          Button {
            Task { await viewModel.performNotificationAction() }
          } label: {
            ProfileSettingsRow(
              icon: "bell",
              title: "profile.notifications",
              detail: notificationActionTitle,
              showsProgress: viewModel.isRequestingNotifications
            )
          }
          .disabled(viewModel.isRequestingNotifications)
          .accessibilityIdentifier("profile-notifications")
        }

        NavigationLink(value: ProfileDestination.language) {
          ProfileSettingsRow(
            icon: "globe",
            title: "profile.language",
            detail: languageName
          )
        }
        .accessibilityIdentifier("profile-language")
      }

      Section("profile.legal.section") {
        Button {
          openURL(viewModel.privacyPolicyURL)
        } label: {
          ProfileSettingsRow(icon: "info.circle", title: "profile.privacy_policy")
        }

        Button {
          openURL(viewModel.termsAndConditionsURL)
        } label: {
          ProfileSettingsRow(icon: "doc.text", title: "profile.terms")
        }

        if viewModel.privacyOptionsRequired {
          Button {
            Task { await viewModel.presentPrivacyOptions() }
          } label: {
            ProfileSettingsRow(icon: "hand.raised", title: "privacy.options")
          }
        }
      }

      if identity.isRegistered {
        Section {
          Button {
            Task { await viewModel.signOut() }
          } label: {
            ProfileSettingsRow(
              icon: "rectangle.portrait.and.arrow.right",
              title: "profile.sign_out",
              showsProgress: viewModel.operation == .signingOut
            )
          }
          .disabled(viewModel.isBusy)
          .accessibilityIdentifier("profile-sign-out")
        }
      }

      Section {
        Button(role: .destructive) {
          deletionConfirmation = ""
          viewModel.requestAccountDeletion()
        } label: {
          ProfileSettingsRow(
            icon: "trash",
            title: "profile.delete.action",
            foregroundStyle: OutwitColors.action,
            showsProgress: viewModel.operation == .deletingAccount
          )
        }
        .disabled(viewModel.isBusy)
        .accessibilityIdentifier("profile-delete-account")
      }
    }
    .listStyle(.insetGrouped)
    .scrollContentBackground(.hidden)
    .background(OutwitColors.softWhite)
    .animation(.easeInOut(duration: 0.2), value: viewModel.showsNotificationSetting)
  }

  private var notificationActionTitle: LocalizedStringKey {
    viewModel.notificationState == .denied
      ? "profile.notifications.open_settings"
      : "profile.notifications.turn_on"
  }

  private var languageName: LocalizedStringKey {
    switch viewModel.selectedLanguage {
    case .english: "language.option.english.title"
    case .hindi: "language.option.hindi.title"
    }
  }

  private var isDeletionConfirmationValid: Bool {
    deletionConfirmation.trimmingCharacters(in: .whitespacesAndNewlines) == "DELETE"
  }

  private var deletionConfirmationBinding: Binding<Bool> {
    Binding(
      get: { viewModel.isDeleteConfirmationPresented },
      set: { if !$0 { viewModel.cancelAccountDeletion() } }
    )
  }

  private var errorBinding: Binding<Bool> {
    Binding(
      get: { viewModel.actionErrorKey != nil },
      set: { if !$0 { viewModel.dismissError() } }
    )
  }
}

private enum ProfileDestination: Hashable {
  case language
}
