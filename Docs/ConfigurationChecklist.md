# iOS configuration checklist

This document lists the configuration needed to ship the native iOS app. It does not copy Android platform credentials into iOS.

> **Bundle identifier timing:** the current bundle identifier is temporarily `outwit.OutwitGames`. Wait for the final bundle identifier before creating production Firebase and AdMob iOS app registrations, unless recreating their configuration later is acceptable. Firebase treats the registered Apple bundle identifier as case-sensitive and it cannot be changed after registration.

## Must be created specifically for iOS

### Apple Developer and App Store Connect

- Final explicit App ID / bundle identifier.
- Apple Developer Team ID and the team that will sign the app.
- App Store Connect app record and Apple app ID once the final bundle identifier is known.
- Push Notifications capability on the iOS App ID.
- APNs authentication key (`.p8`), Key ID, and Team ID. Store the `.p8` outside Git. One suitable APNs key may serve multiple apps on the same Apple team; it is not an Android key.
- Production privacy policy URL and support URL for the App Store listing.
- App privacy answers covering analytics, advertising, identifiers, diagnostics, and tracking used by the finished app.
- The final wording for the App Tracking Transparency purpose message (`NSUserTrackingUsageDescription`) before tracking is enabled.

References: [Register with APNs](https://developer.apple.com/documentation/usernotifications/registering-your-app-with-apns), [APNs authentication keys](https://developer.apple.com/help/account/capabilities/communicate-with-apns-using-authentication-tokens), [tracking usage description](https://developer.apple.com/documentation/bundleresources/information-property-list/nsusertrackingusagedescription).

### Firebase for Apple platforms

- Register a new **Apple/iOS app** inside the intended Firebase project using the final iOS bundle identifier.
- Download that registration's `GoogleService-Info.plist`.
- Upload the Apple APNs authentication key to Firebase Cloud Messaging and record its Key ID and Apple Team ID.
- Confirm whether development and production use separate Firebase projects. If they do, generate a separate iOS plist for each environment.

Do not use Android's `google-services.json`, Android package name, SHA fingerprints, or Android Firebase app ID. The Firebase project may be shared, but it must contain a distinct Apple app registration.

References: [Add Firebase to an Apple project](https://firebase.google.com/docs/ios/setup), [Firebase Cloud Messaging for Apple apps](https://firebase.google.com/docs/cloud-messaging/ios/get-started).

### Google Mobile Ads / AdMob

Create an **iOS app** in AdMob and provide:

1. iOS AdMob app ID (`ca-app-pub-…~…`).
2. iOS interstitial ad unit ID for the feed placement.
3. iOS rewarded ad unit ID for the challenge multiplier placement.
4. iOS rewarded ad unit ID for the challenge retry placement.

The Android AdMob app ID and all Android ad unit IDs are platform-specific and must not be used by the iOS app.

Development will use Google's official iOS test configuration:

- Test app ID: `ca-app-pub-3940256099942544~1458002511`
- Test interstitial unit: `ca-app-pub-3940256099942544/4411468910`
- Test rewarded unit: `ca-app-pub-3940256099942544/1712485313`

Before release, also complete the AdMob app's privacy and messaging setup and confirm the consent regions that the app must support. The iOS target will receive `GADApplicationIdentifier` and Google's current `SKAdNetworkItems` list during the ads integration checkpoint.

References: [Google Mobile Ads iOS quick start](https://developers.google.com/admob/ios/quick-start), [official iOS test ad units](https://developers.google.com/admob/ios/test-ads), [set up an AdMob app](https://support.google.com/admob/answer/9989980).

### Meta App Events

- Add an iOS platform entry to the intended Meta app using the final iOS bundle identifier.
- Configure the iPhone/iPad App Store ID after the App Store Connect record exists.
- Confirm the Meta App ID and client token that the iOS app should use.
- Confirm whether advertiser ID collection will be enabled after Apple tracking authorization.

The same Meta app-level App ID and client token may be used when Android and iOS report into the same Meta app, but Android manifest entries and Android package registration are not iOS configuration. The iOS platform record and iOS property-list configuration must be created separately.

Reference: [Meta iOS SDK](https://github.com/facebook/facebook-ios-sdk).

## Values that may be shared with Android

These are service or backend values rather than Android platform credentials. Reuse is appropriate only after the service owner confirms that both apps should report to the same environment.

- PostHog project token and PostHog host, if iOS and Android should share one product analytics project.
- Outwit API base URL for each environment.
- Outwit WebSocket URL for each environment.
- Allowlisted hosted-game domains for each environment.
- Analytics event names and property schema, so cross-platform dashboards stay comparable.
- Backend feature flags, economy rules, and ad-placement names.

The iOS app will store environment values in iOS build configuration, not by importing Android JSON or Gradle files.

## Backend confirmations needed for iOS

- Confirm that guest login, OTP, profile, feed, rewards, challenge, and socket contracts accept an iOS device/platform value.
- Confirm how the existing push-token endpoint distinguishes iOS Firebase/APNs tokens from Android FCM tokens.
- Confirm that rewarded-ad server-side rules use the placement names `multiplier` and `retry` for iOS as well.
- Confirm whether Apple receipt or App Store server configuration will be needed for any future in-app purchase flow.

## Files and secrets policy

- Never commit APNs `.p8` keys, signing certificates, provisioning profiles, private server keys, or service-account JSON.
- `GoogleService-Info.plist` is iOS-specific service configuration. This repository currently ignores it, so each developer/CI environment must inject the correct file securely.
- Public client configuration such as an AdMob app ID is not a server secret, but production identifiers should still be supplied through the app's environment configuration so test and production builds cannot be mixed.
- No Android keystore, `google-services.json`, Android application ID, Android AdMob identifier, Android resource entry, or Gradle configuration belongs in the iOS target.
