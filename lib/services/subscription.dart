/// Subscription service for SkillDrills.
///
/// This service is responsible for checking whether the current user holds
/// an active paid subscription, which gates premium features such as enabling
/// more than [kFreeActiveActivityLimit] activities at once.
///
/// TODO: Replace the stub in [hasActiveSubscription] with a real RevenueCat
/// SDK call once `purchases_flutter` is integrated:
///   ```dart
///   final customerInfo = await Purchases.getCustomerInfo();
///   return customerInfo.entitlements.active.isNotEmpty;
///   ```
library;

/// The maximum number of activities a free (non-subscribed) user may have
/// active simultaneously.
const int kFreeActiveActivityLimit = 2;

/// Returns `true` if the current user has an active paid subscription.
///
/// **Testing stub** — hardcoded to `false` so the paywall gate is always
/// enforced during development. Flip to `true` to test the unlocked path.
///
/// Replace the body of this function with a RevenueCat SDK call when ready:
/// ```dart
/// // 1. Add purchases_flutter to pubspec.yaml
/// // 2. Configure with your RevenueCat API key in main.dart
/// // 3. Replace the return statement below:
/// final customerInfo = await Purchases.getCustomerInfo();
/// return customerInfo.entitlements.active.isNotEmpty;
/// ```
Future<bool> hasActiveSubscription() async {
  // ── STUB ─────────────────────────────────────────────────────────────────
  // Change to `true` to bypass the paywall gate while testing.
  return false;
  // ─────────────────────────────────────────────────────────────────────────
}
