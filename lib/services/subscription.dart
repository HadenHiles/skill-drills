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
/// 5. Show the paywall with [presentPaywall] or [presentPaywallIfNeeded].
/// 6. Show the Customer Center (subscription management) with
///    [presentCustomerCenter].
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
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
Future<void> initializeRevenueCat() async {
  if (!_rcSupported) return;

  // Same test key for both platforms — replace with production keys before
  // shipping.  Use separate iOS / Android keys if your RevenueCat project has
  // different app entries per platform.
  const apiKey = 'test_OpSHyTwjtuWPWDinlceOpCBhGLA';

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

/// Purchase [package] and return the updated [CustomerInfo] on success.
///
/// Returns `null` if the user cancels or an error occurs. Cancellation is
/// treated silently (no error logged to avoid noise in telemetry).
Future<CustomerInfo?> purchasePackage(Package package) async {
  if (!_rcSupported) return null;
  try {
    final result = await Purchases.purchase(PurchaseParams.package(package));
    return result.customerInfo;
  } catch (e) {
    // Suppress cancellation noise; log everything else.
    final msg = e.toString();
    if (!msg.contains('purchaseCancelled') && !msg.contains('1')) {
      debugPrint('[RevenueCat] purchasePackage error: $e');
    }
    return null;
  }
}

/// Restore prior App Store / Play Store purchases.
///
/// Returns the updated [CustomerInfo] on success, or `null` on error.
Future<CustomerInfo?> restorePurchases() async {
  if (!_rcSupported) return null;
  try {
    return await Purchases.restorePurchases();
  } catch (e, st) {
    debugPrint('[RevenueCat] restorePurchases error: $e\n$st');
    return null;
  }
}

// ── Paywall UI ────────────────────────────────────────────────────────────────

/// Present the RevenueCat-configured paywall for the current (default)
/// offering.
///
/// Pass an [offering] to show a specific offering's paywall instead.
/// Returns `true` if the user purchased or restored a subscription.
Future<bool> presentPaywall({Offering? offering}) async {
  if (!_rcSupported) return false;
  try {
    final result = await RevenueCatUI.presentPaywall(offering: offering);
    debugPrint('[RevenueCat] Paywall result: $result');
    return result == PaywallResult.purchased || result == PaywallResult.restored;
  } catch (e, st) {
    debugPrint('[RevenueCat] presentPaywall error: $e\n$st');
    return false;
  }
}

/// Present the paywall **only if** the user does not already hold
/// [kProEntitlement].
///
/// This is the preferred entry point after sign-up / onboarding — it
/// silently skips showing the paywall for existing subscribers.
/// Returns `true` if the user purchased or restored a subscription.
Future<bool> presentPaywallIfNeeded() async {
  if (!_rcSupported) return false;
  try {
    final result = await RevenueCatUI.presentPaywallIfNeeded(kProEntitlement);
    debugPrint('[RevenueCat] PaywallIfNeeded result: $result');
    return result == PaywallResult.purchased || result == PaywallResult.restored;
  } catch (e, st) {
    debugPrint('[RevenueCat] presentPaywallIfNeeded error: $e\n$st');
    return false;
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
