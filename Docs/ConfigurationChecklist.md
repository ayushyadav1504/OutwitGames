# Outwit Games iOS configuration request

This is the complete list of external configuration that the iOS app team needs. Existing Android product/service values will be reused where they are platform-independent.

## Confirmed Apple application identity

The signed App Store provisioning profile establishes these final values:

- Bundle identifier: `club.outwit.games`
- Apple Developer Team ID: `R4B78HKAFH`
- Explicit application identifier: `R4B78HKAFH.club.outwit.games`
- Apple App ID name: `Outwit Games Bundle`
- App Store provisioning profile name: `Outwit Games App Store`
- App Store provisioning profile UUID: `b519da3b-9d88-4ff0-b6a0-dfb094f0cda1`
- Distribution certificate SHA-1: `24EE249FC396B4A62C9684559D90DADEF6813641`
- Profile and distribution certificate expiry: August 31, 2027
- Production APNs entitlement: enabled

The provisioning profile and distribution certificate are signing assets and must remain outside Git. The supplied `.cer` matches the certificate embedded in the profile, but manual distribution signing still requires its matching private key (normally installed from a password-protected `.p12`) or an Xcode-managed distribution identity.

## Please provide later

### 1. Firebase for iOS

- Add a new **Apple/iOS app** to the existing Outwit Firebase project with the case-sensitive bundle identifier `club.outwit.games`.
- Provide the generated `GoogleService-Info.plist`.
- For push notifications, connect the Apple APNs authentication key to Firebase Cloud Messaging. This requires the APNs `.p8` file, its Key ID, and the Apple Team ID. Keep the `.p8` file outside Git.
- If development and production use separate Firebase projects, provide one iOS plist per environment.

The Firebase project may be the same project used by Android, but iOS must have its own app registration. Android's `google-services.json`, Android package name, SHA fingerprints, and Android Firebase app ID cannot be used by iOS.

References: [Firebase Apple setup](https://firebase.google.com/docs/ios/setup), [Firebase Cloud Messaging for Apple apps](https://firebase.google.com/docs/cloud-messaging/ios/get-started), [Apple APNs authentication keys](https://developer.apple.com/help/account/capabilities/communicate-with-apns-using-authentication-tokens).

### 2. Google Mobile Ads for iOS

Create an **iOS app** in the existing AdMob account and provide:

- iOS AdMob app ID (`ca-app-pub-…~…`).
- iOS interstitial ad unit ID for the feed placement.
- iOS rewarded ad unit ID for the challenge multiplier placement.
- iOS rewarded ad unit ID for the challenge retry placement.

For each rewarded ad unit, also configure AdMob server-side verification (SSV):

- Use the backend-provided iOS reward verification callback URL.
- The backend must verify Google's signature and reject reused transaction IDs.
- Keep challenge rewards server-authoritative. The app sends the signed-in user ID
  and the backend-issued ad-session ID as SSV metadata; it does not credit the
  reward locally.

In AdMob **Privacy & messaging**, publish the consent messages required for the
app's supported regions. The iOS app uses Google's User Messaging Platform before
requesting ads and exposes privacy choices when UMP requires them.

Android's AdMob app ID and Android ad unit IDs are platform-specific and cannot be used by iOS.

References: [Google Mobile Ads iOS quick start](https://developers.google.com/admob/ios/quick-start), [AdMob app setup](https://support.google.com/admob/answer/9989980).

## Values used during development

The Google Mobile Ads and User Messaging Platform SDK integration is present.
Until the production iOS AdMob identifiers are available, the current development
checkpoint intentionally uses Google's official iOS test values in **both Debug
and Release** configurations:

- Test app ID: `ca-app-pub-3940256099942544~1458002511`
- Test interstitial unit: `ca-app-pub-3940256099942544/4411468910`
- Test rewarded unit: `ca-app-pub-3940256099942544/1712485313`

The same test rewarded unit is safe for both the multiplier and retry placements; the app will continue to distinguish those placements in its own analytics and reward flow.

Before an App Store archive is submitted, replace these Xcode build settings with
the production iOS values:

- `OUTWIT_GAD_APPLICATION_ID`
- `OUTWIT_INTERSTITIAL_FEED_AD_UNIT_ID`
- `OUTWIT_REWARDED_MULTIPLIER_AD_UNIT_ID`
- `OUTWIT_REWARDED_RETRY_AD_UNIT_ID`

Do not submit a build that still contains Google's test identifiers. The app's
`Info.plist` already includes Google's current recommended SKAdNetwork identifier
list. Review that list against the current Google documentation when preparing a
release because advertising network requirements can change.

Reference: [official iOS test ad units](https://developers.google.com/admob/ios/test-ads).

## Reuse from the Android product configuration

The iOS implementation will reuse these existing values and contracts:

- Development and production Outwit API base URLs.
- Development and production Outwit WebSocket URLs.
- Development and production hosted-game allowlist domains.
- PostHog project token and host.
- Meta App ID and client token, with an iOS platform entry for `club.outwit.games` added to the same Meta app.
- Analytics event names and property schema.
- Backend API/socket contracts, feature rules, economy rules, and ad-placement names.

These values will be expressed in native iOS build configuration. The iOS project will not import Android JSON, XML, manifest, resource, or Gradle files.

## Files that must never be copied from Android

- `google-services.json`
- Android application/package ID
- Android Firebase app ID or SHA fingerprints
- Android AdMob app ID or ad unit IDs
- Android signing keystore or signing properties
- Android manifest metadata and Gradle configuration

The rewarded and feed-interstitial Google Mobile Ads integrations and typed
analytics boundary are now implemented. Firebase, Meta, PostHog, and production
AdMob identifiers remain separate approved integration checkpoints.
