/// Subscription service for SkillDrills.
///
/// Integrates the RevenueCat SDK ([purchases_flutter] + [purchases_ui_flutter])
/// to manage in-app purchases, entitlement checking, paywalls, and the
/// Customer Center for subscription self-service.
///
/// ## Usage
/// 1. Call [initializeRevenueCat] once from `main()` before `runApp`.
/// 2. After successful Firebase auth, call [loginRevenueCatUser] with the
///    Firebase UID so purchases are attributed to the correct user.
/// 3. On sign-out, call [logoutRevenueCatUser].
/// 4. Gate premium features with [hasActiveSubscription].
/// 5. Navigate to [PaywallScreen] to let the user subscribe.
/// 6. Show the Customer Center (subscription management) with
///    [presentCustomerCenter].
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:purchases_ui_flutter/purchases_ui_flutter.dart';

// ── Constants ────────────────────────────────────────────────────────────────

/// RevenueCat entitlement identifier that unlocks Skill Drills Pro.
const String kProEntitlement = 'Skill Drills Pro';

/// RevenueCat product identifiers matching your dashboard configuration.
const String kMonthlyProductId = 'monthly';
const String kYearlyProductId = 'yearly';
const String kLifetimeProductId = 'lifetime';

/// The maximum number of activities a free (non-subscribed) user may have
/// active simultaneously.
const int kFreeActiveActivityLimit = 2;

// ── Helpers ──────────────────────────────────────────────────────────────────

/// `true` when the current platform supports RevenueCat (iOS or Android).
bool get _rcSupported => Platform.isIOS || Platform.isAndroid;

// ── Initialization ────────────────────────────────────────────────────────────

/// Initialize the RevenueCat SDK.
///
/// Call this **once** from `main()` after `Firebase.initializeApp`, before
/// calling `runApp`. Safe to call on unsupported platforms (no-op).
///
/// API keys are injected at build time via `--dart-define-from-file=dart_defines.json`
/// (or individual `--dart-define` flags in CI). Never hardcode them in source.
Future<void> initializeRevenueCat() async {
  if (!_rcSupported) return;

  // Keys are compiled into the binary via --dart-define-from-file.
  // They are never stored in source code or bundled as readable assets.
  // See dart_defines.json (git-ignored) and the README for setup instructions.
  const iosKey = String.fromEnvironment('RC_API_KEY_IOS');
  const androidKey = String.fromEnvironment('RC_API_KEY_ANDROID');
  final apiKey = Platform.isIOS ? iosKey : androidKey;

  assert(
    apiKey.isNotEmpty,
    'RevenueCat API key is empty. '
    'Run flutter with --dart-define-from-file=dart_defines.json or '
    'set RC_API_KEY_IOS / RC_API_KEY_ANDROID via --dart-define.',
  );

  final config = PurchasesConfiguration(apiKey);
  await Purchases.configure(config);

  if (kDebugMode) {
    await Purchases.setLogLevel(LogLevel.debug);
  }
}

// ── User identity ─────────────────────────────────────────────────────────────

/// Associate RevenueCat with the signed-in Firebase user.
///
/// Call this **after every successful auth** (Google, email sign-in, sign-up)
/// using the Firebase UID so that purchases are correctly attributed and
/// entitlements are restored across devices.
Future<void> loginRevenueCatUser(String firebaseUid) async {
  if (!_rcSupported) return;
  try {
    await Purchases.logIn(firebaseUid);
    debugPrint('[RevenueCat] Logged in as $firebaseUid');
  } catch (e, st) {
    debugPrint('[RevenueCat] logIn error: $e\n$st');
  }
}

/// Reset RevenueCat to an anonymous session.
///
/// Call this when the user signs out of Firebase so that a subsequent login
/// can re-associate their purchases.
Future<void> logoutRevenueCatUser() async {
  if (!_rcSupported) return;
  try {
    await Purchases.logOut();
    debugPrint('[RevenueCat] Logged out — anonymous session started');
  } catch (e, st) {
    debugPrint('[RevenueCat] logOut error: $e\n$st');
  }
}

// ── Customer info ─────────────────────────────────────────────────────────────

/// Returns the current [CustomerInfo], or `null` if unavailable.
Future<CustomerInfo?> getCustomerInfo() async {
  if (!_rcSupported) return null;
  try {
    return await Purchases.getCustomerInfo();
  } catch (e, st) {
    debugPrint('[RevenueCat] getCustomerInfo error: $e\n$st');
    return null;
  }
}

/// Live stream of [CustomerInfo] updates.
///
/// Subscribe in long-lived widgets to react to subscription state changes
/// in real-time (e.g., updating UI when a purchase completes in the background).
/// The returned stream is broadcast; cancel the subscription when done to
/// automatically remove the underlying RevenueCat listener.
Stream<CustomerInfo> get customerInfoStream {
  if (!_rcSupported) return const Stream.empty();
  // Wrap RevenueCat's callback-based API in a broadcast StreamController so
  // callers can use idiomatic Dart async patterns.
  late StreamController<CustomerInfo> controller;
  void listener(CustomerInfo info) => controller.add(info);
  controller = StreamController<CustomerInfo>.broadcast(
    onListen: () => Purchases.addCustomerInfoUpdateListener(listener),
    onCancel: () => Purchases.removeCustomerInfoUpdateListener(listener),
  );
  return controller.stream;
}

/// Returns `true` if the current user holds an active [kProEntitlement].
Future<bool> hasActiveSubscription() async {
  final info = await getCustomerInfo();
  if (info == null) return false;
  return info.entitlements.active.containsKey(kProEntitlement);
}

// ── Offerings & purchases ─────────────────────────────────────────────────────

/// Fetches the current [Offerings] from RevenueCat.
///
/// The returned [Offerings] contains all configured offerings with their
/// packages (monthly, yearly, lifetime).  Returns `null` on error.
Future<Offerings?> getOfferings() async {
  if (!_rcSupported) return null;
  try {
    return await Purchases.getOfferings();
  } catch (e, st) {
    debugPrint('[RevenueCat] getOfferings error: $e\n$st');
    return null;
  }
}

/// Purchase [package] and return a result record.
///
/// - `(info: CustomerInfo, errorMessage: null)` — purchase succeeded.
/// - `(info: null, errorMessage: null)` — user cancelled (silent).
/// - `(info: null, errorMessage: String)` — a real error occurred; the string
///   is suitable for display to the user.
Future<({CustomerInfo? info, String? errorMessage})> purchasePackage(
  Package package,
) async {
  if (!_rcSupported) return (info: null, errorMessage: null);
  try {
    final result = await Purchases.purchase(PurchaseParams.package(package));
    return (info: result.customerInfo, errorMessage: null);
  } on PlatformException catch (e) {
    final code = PurchasesErrorHelper.getErrorCode(e);
    if (code == PurchasesErrorCode.purchaseCancelledError) {
      return (info: null, errorMessage: null);
    }
    debugPrint('[RevenueCat] purchasePackage error ($code): $e');
    return (info: null, errorMessage: _purchaseErrorMessage(code));
  } catch (e, st) {
    debugPrint('[RevenueCat] purchasePackage unexpected error: $e\n$st');
    return (info: null, errorMessage: 'Something went wrong. Please try again.');
  }
}

String _purchaseErrorMessage(PurchasesErrorCode code) {
  return switch (code) {
    PurchasesErrorCode.networkError => 'Network error. Check your connection and try again.',
    PurchasesErrorCode.purchaseNotAllowedError || PurchasesErrorCode.insufficientPermissionsError => 'Purchases are not allowed on this device.',
    PurchasesErrorCode.paymentPendingError => 'Your payment is pending. Check back soon.',
    PurchasesErrorCode.productAlreadyPurchasedError => 'You already own this subscription.',
    _ => 'Purchase failed. Please try again.',
  };
}

/// Restore prior App Store / Play Store purchases.
///
/// - `(info: CustomerInfo, errorMessage: null)` — restore succeeded.
/// - `(info: null, errorMessage: String)` — a real error occurred; the string
///   is suitable for display to the user.
Future<({CustomerInfo? info, String? errorMessage})> restorePurchases() async {
  if (!_rcSupported) return (info: null, errorMessage: null);
  try {
    final info = await Purchases.restorePurchases();
    return (info: info, errorMessage: null);
  } on PlatformException catch (e) {
    final code = PurchasesErrorHelper.getErrorCode(e);
    debugPrint('[RevenueCat] restorePurchases error ($code): $e');
    final message = code == PurchasesErrorCode.networkError ? 'Network error. Check your connection and try again.' : 'Could not restore purchases. Please try again.';
    return (info: null, errorMessage: message);
  } catch (e, st) {
    debugPrint('[RevenueCat] restorePurchases unexpected error: $e\n$st');
    return (info: null, errorMessage: 'Could not restore purchases. Please try again.');
  }
}

// ── Customer Center ───────────────────────────────────────────────────────────

/// Present the RevenueCat Customer Center.
///
/// Gives subscribers a self-service UI to cancel, change plan, request
/// refunds (iOS), restore purchases, and contact support — without leaving
/// the app.  Requires [purchases_ui_flutter] >= 8.6.0.
///
/// Note: Customer Center is available on RevenueCat Pro and Enterprise plans.
Future<void> presentCustomerCenter() async {
  if (!_rcSupported) return;
  try {
    await RevenueCatUI.presentCustomerCenter();
  } catch (e, st) {
    debugPrint('[RevenueCat] presentCustomerCenter error: $e\n$st');
  }
}
