// ignore_for_file: avoid_print

import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:skilldrills/services/subscription.dart';
import 'package:skilldrills/theme/theme.dart';
import 'package:url_launcher/url_launcher.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Pro feature bullets
// ─────────────────────────────────────────────────────────────────────────────

const _features = [
  (icon: Icons.all_inclusive_rounded, text: 'Unlimited Activities'),
  (icon: Icons.event_note_rounded, text: 'Unlimited Saved Routines'),
  (icon: Icons.bar_chart_rounded, text: 'Advanced Improvement Metrics'),
  (icon: Icons.star_rounded, text: 'All Current & Future Pro Features'),
  (icon: Icons.support_agent_rounded, text: 'Priority Support'),
];

// ─────────────────────────────────────────────────────────────────────────────
// PaywallScreen
// ─────────────────────────────────────────────────────────────────────────────

/// Full-screen custom paywall for Skill Drills Pro.
///
/// Fetches the current [Offering] from RevenueCat, renders product cards
/// dynamically, and handles purchase / restore flows.
///
/// Push as a `fullscreenDialog: true` route so the OS-standard dismiss
/// gesture works on both platforms.
class PaywallScreen extends StatefulWidget {
  /// When `true`, the footer shows a "Skip" button instead of "Restore
  /// Purchases". Use this when presenting the paywall during onboarding so
  /// new users can dismiss it without being prompted to restore.
  final bool showSkip;

  const PaywallScreen({super.key, this.showSkip = false});

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen> {
  // ── State ──────────────────────────────────────────────────────────────────
  Offering? _offering;
  bool _loading = true;
  String? _error;

  Package? _selectedPackage;
  bool _purchasing = false;
  bool _restoring = false;

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _loadOffering();
  }

  Future<void> _loadOffering() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final offerings = await getOfferings();
      final offering = offerings?.current;
      if (!mounted) return;
      if (offering == null || offering.availablePackages.isEmpty) {
        setState(() {
          _error = 'Products unavailable. Please try again later.';
          _loading = false;
        });
        return;
      }
      // Default-select the annual package (best value), falling back to the
      // first available package.
      final defaultPackage = offering.annual ??
          offering.availablePackages.firstWhere(
            (p) => p.packageType == PackageType.lifetime,
            orElse: () => offering.availablePackages.first,
          );
      setState(() {
        _offering = offering;
        _selectedPackage = defaultPackage;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load products. Check your connection and try again.';
        _loading = false;
      });
    }
  }

  // ── Purchase helpers ───────────────────────────────────────────────────────

  Future<void> _purchase() async {
    if (_selectedPackage == null || _purchasing) return;
    setState(() => _purchasing = true);
    final result = await purchasePackage(_selectedPackage!);
    if (!mounted) return;
    setState(() => _purchasing = false);
    if (result.info != null && result.info!.entitlements.active.containsKey(kProEntitlement)) {
      _showSuccess('Welcome to Skill Drills Pro! 🎉');
      Navigator.of(context).pop(true);
    } else if (result.errorMessage != null) {
      _showError(result.errorMessage!);
    }
    // errorMessage == null and info == null means user cancelled — do nothing
  }

  Future<void> _restore() async {
    if (_restoring) return;
    setState(() => _restoring = true);
    final result = await restorePurchases();
    if (!mounted) return;
    setState(() => _restoring = false);
    if (result.info != null && result.info!.entitlements.active.containsKey(kProEntitlement)) {
      _showSuccess('Pro subscription restored!');
      Navigator.of(context).pop(true);
    } else if (result.errorMessage != null) {
      _showError(result.errorMessage!);
    } else {
      _showMessage('No active subscription found for this account.');
    }
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: SkillDrillsColors.success,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: SkillDrillsColors.error,
        duration: const Duration(seconds: 5),
      ),
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 4)),
    );
  }

  // ── Computed helpers ───────────────────────────────────────────────────────

  /// Returns a "Save XX%" string if both monthly and annual packages are
  /// present and their prices can be compared.
  String? _annualSavingsBadge() {
    final monthly = _offering?.monthly;
    final annual = _offering?.annual;
    if (monthly == null || annual == null) return null;
    final mp = monthly.storeProduct.price;
    final ap = annual.storeProduct.price;
    if (mp <= 0 || ap <= 0) return null;
    final monthlyEquiv = ap / 12;
    final pct = ((mp - monthlyEquiv) / mp * 100).round();
    if (pct <= 0) return null;
    return 'Save $pct%';
  }

  String _periodLabel(Package pkg) {
    switch (pkg.packageType) {
      case PackageType.monthly:
        return '/ mo';
      case PackageType.twoMonth:
        return '/ 2 mo';
      case PackageType.threeMonth:
        return '/ 3 mo';
      case PackageType.sixMonth:
        return '/ 6 mo';
      case PackageType.annual:
        return '/ yr';
      case PackageType.lifetime:
        return 'one-time';
      case PackageType.weekly:
        return '/ wk';
      default:
        return '';
    }
  }

  String _packageTitle(Package pkg) {
    switch (pkg.packageType) {
      case PackageType.monthly:
        return 'Monthly';
      case PackageType.annual:
        return 'Yearly';
      case PackageType.lifetime:
        return 'Lifetime';
      case PackageType.weekly:
        return 'Weekly';
      case PackageType.sixMonth:
        return '6 Months';
      case PackageType.threeMonth:
        return '3 Months';
      default:
        return pkg.identifier;
    }
  }

  bool _isSubscription(Package pkg) => pkg.packageType != PackageType.lifetime && pkg.packageType != PackageType.unknown && pkg.packageType != PackageType.custom;

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? SkillDrillsColors.darkBackground : SkillDrillsColors.lightBackground,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ───────────────────────────────────────────────────────
            _Header(onClose: () => Navigator.of(context).pop(false)),
            // ── Body ─────────────────────────────────────────────────────────
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: SkillDrillsColors.brandBlue,
                      ),
                    )
                  : _error != null
                      ? _ErrorState(message: _error!, onRetry: _loadOffering)
                      : _buildContent(isDark),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(bool isDark) {
    final packages = _offering!.availablePackages;
    final savingsBadge = _annualSavingsBadge();

    return Column(
      children: [
        // Scrollable middle section
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 20),
                // Feature list
                ..._features.map((f) => _FeatureRow(icon: f.icon, text: f.text)),
                const SizedBox(height: 24),
                // Package cards
                ...packages.map((pkg) {
                  final isSelected = _selectedPackage == pkg;
                  final isAnnual = pkg.packageType == PackageType.annual;
                  return _PackageCard(
                    package: pkg,
                    title: _packageTitle(pkg),
                    periodLabel: _periodLabel(pkg),
                    badge: isAnnual ? savingsBadge : null,
                    isSelected: isSelected,
                    isDark: isDark,
                    onTap: () => setState(() => _selectedPackage = pkg),
                  );
                }),
                const SizedBox(height: 8),
                // Auto-renewal disclaimer (subscriptions only)
                if (_selectedPackage != null && _isSubscription(_selectedPackage!)) _AutoRenewalNotice(package: _selectedPackage!),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),

        // ── Fixed footer ─────────────────────────────────────────────────────
        _Footer(
          purchasing: _purchasing,
          restoring: _restoring,
          selectedPackage: _selectedPackage,
          onPurchase: _purchase,
          onRestore: _restore,
          onSkip: widget.showSkip ? () => Navigator.of(context).pop(false) : null,
          isDark: isDark,
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Header
// ─────────────────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final VoidCallback onClose;
  const _Header({required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF0186B5),
            SkillDrillsColors.brandBlue,
            Color(0xFF01C4A1),
          ],
          stops: [0.0, 0.5, 1.0],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Close button
              Align(
                alignment: Alignment.topRight,
                child: GestureDetector(
                  onTap: onClose,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(38),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close, color: Colors.white, size: 20),
                  ),
                ),
              ),
              Column(
                children: [
                  const SizedBox(height: 4),
                  SvgPicture.asset(
                    'assets/images/logo/SkillDrills.svg',
                    height: 36,
                    semanticsLabel: 'Skill Drills',
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(38),
                      borderRadius: SkillDrillsRadius.fullBorderRadius,
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.star_rounded, color: Colors.white, size: 14),
                        SizedBox(width: 4),
                        Text(
                          'SKILL DRILLS PRO',
                          style: TextStyle(
                            color: Colors.white,
                            fontFamily: 'Choplin',
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Unlock your full potential',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontFamily: 'Choplin',
                      fontWeight: FontWeight.w700,
                      fontSize: 22,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Everything you need to master any skill',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withAlpha(204),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Feature row
// ─────────────────────────────────────────────────────────────────────────────

class _FeatureRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _FeatureRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: SkillDrillsColors.brandBlue.withAlpha(26),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: SkillDrillsColors.brandBlue, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const Icon(
            Icons.check_circle_rounded,
            color: SkillDrillsColors.success,
            size: 20,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Package card
// ─────────────────────────────────────────────────────────────────────────────

class _PackageCard extends StatelessWidget {
  final Package package;
  final String title;
  final String periodLabel;
  final String? badge;
  final bool isSelected;
  final bool isDark;
  final VoidCallback onTap;

  const _PackageCard({
    required this.package,
    required this.title,
    required this.periodLabel,
    required this.badge,
    required this.isSelected,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cardBg = isDark ? SkillDrillsColors.darkCard : SkillDrillsColors.lightCard;
    final borderColor = isSelected ? SkillDrillsColors.brandBlue : (isDark ? SkillDrillsColors.darkDivider : SkillDrillsColors.lightDivider);
    final borderWidth = isSelected ? 2.0 : 1.0;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: isSelected ? SkillDrillsColors.brandBlue.withAlpha(isDark ? 30 : 18) : cardBg,
          borderRadius: SkillDrillsRadius.mdBorderRadius,
          border: Border.all(color: borderColor, width: borderWidth),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              // Radio indicator
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected ? SkillDrillsColors.brandBlue : (isDark ? SkillDrillsColors.darkOnSurfaceMuted : SkillDrillsColors.lightOnSurfaceMuted),
                    width: 2,
                  ),
                  color: isSelected ? SkillDrillsColors.brandBlue : Colors.transparent,
                ),
                child: isSelected ? const Icon(Icons.check, color: Colors.white, size: 13) : null,
              ),
              const SizedBox(width: 14),
              // Package name
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: isDark ? SkillDrillsColors.darkOnSurface : SkillDrillsColors.lightOnSurface,
                  ),
                ),
              ),
              // Badge (e.g. "Save 41%")
              if (badge != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: SkillDrillsColors.energyOrange,
                    borderRadius: SkillDrillsRadius.fullBorderRadius,
                  ),
                  child: Text(
                    badge!,
                    style: const TextStyle(
                      color: Colors.white,
                      fontFamily: 'Choplin',
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
              ],
              // Price
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    package.storeProduct.priceString,
                    style: TextStyle(
                      fontFamily: 'Choplin',
                      fontWeight: FontWeight.w700,
                      fontSize: 17,
                      color: isSelected ? SkillDrillsColors.brandBlue : (isDark ? SkillDrillsColors.darkOnSurface : SkillDrillsColors.lightOnSurface),
                    ),
                  ),
                  if (periodLabel.isNotEmpty)
                    Text(
                      periodLabel,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? SkillDrillsColors.darkOnSurfaceMuted : SkillDrillsColors.lightOnSurfaceMuted,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Auto-renewal notice (required by Apple / Google)
// ─────────────────────────────────────────────────────────────────────────────

class _AutoRenewalNotice extends StatelessWidget {
  final Package package;
  const _AutoRenewalNotice({required this.package});

  String _billingPeriod() {
    return switch (package.packageType) {
      PackageType.weekly => 'week',
      PackageType.monthly => 'month',
      PackageType.twoMonth => '2 months',
      PackageType.threeMonth => '3 months',
      PackageType.sixMonth => '6 months',
      PackageType.annual => 'year',
      _ => 'period',
    };
  }

  @override
  Widget build(BuildContext context) {
    final period = _billingPeriod();
    final store = Platform.isIOS ? 'Apple ID' : 'Google Play account';
    return Text(
      '${package.storeProduct.priceString}/${_billingPeriod()} after any free trial. '
      'Payment will be charged to your $store at confirmation of purchase. '
      'Subscription automatically renews unless cancelled at least 24 hours before '
      'the end of the current $period. Manage or cancel in your account settings.',
      style: const TextStyle(
        fontSize: 11,
        color: SkillDrillsColors.lightOnSurfaceMuted,
        height: 1.5,
      ),
      textAlign: TextAlign.center,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Footer (CTA + restore + legal)
// ─────────────────────────────────────────────────────────────────────────────

class _Footer extends StatelessWidget {
  final bool purchasing;
  final bool restoring;
  final Package? selectedPackage;
  final VoidCallback onPurchase;
  final VoidCallback onRestore;

  /// When non-null, renders a "Skip" button instead of "Restore Purchases".
  final VoidCallback? onSkip;
  final bool isDark;

  const _Footer({
    required this.purchasing,
    required this.restoring,
    required this.selectedPackage,
    required this.onPurchase,
    required this.onRestore,
    required this.onSkip,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? SkillDrillsColors.darkSurface : SkillDrillsColors.lightSurface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(isDark ? 60 : 20),
            blurRadius: 12,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(context).padding.bottom + 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // CTA button
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: (purchasing || selectedPackage == null) ? null : onPurchase,
              style: ElevatedButton.styleFrom(
                backgroundColor: SkillDrillsColors.brandBlue,
                disabledBackgroundColor: SkillDrillsColors.brandBlue.withAlpha(120),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: const RoundedRectangleBorder(
                  borderRadius: SkillDrillsRadius.smBorderRadius,
                ),
              ),
              child: purchasing
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.5,
                      ),
                    )
                  : const Text(
                      'Get Skill Drills Pro',
                      style: TextStyle(
                        fontFamily: 'Choplin',
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        letterSpacing: 0.4,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 8),
          // Restore purchases / Skip
          TextButton(
            onPressed: onSkip ?? (restoring ? null : onRestore),
            style: TextButton.styleFrom(
              foregroundColor: isDark ? SkillDrillsColors.darkOnSurfaceMuted : SkillDrillsColors.lightOnSurfaceMuted,
              padding: const EdgeInsets.symmetric(vertical: 4),
              minimumSize: const Size(0, 36),
              textStyle: const TextStyle(fontSize: 13),
            ),
            child: onSkip != null
                ? const Text('Skip')
                : (restoring
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          color: SkillDrillsColors.brandBlue,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text('Restore Purchases')),
          ),
          const SizedBox(height: 2),
          // Terms & Privacy
          _LegalLinks(isDark: isDark),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Legal links (required by Apple / Google)
// ─────────────────────────────────────────────────────────────────────────────

class _LegalLinks extends StatelessWidget {
  final bool isDark;
  const _LegalLinks({required this.isDark});

  Future<void> _open(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final muted = isDark ? SkillDrillsColors.darkOnSurfaceMuted : SkillDrillsColors.lightOnSurfaceMuted;
    return RichText(
      textAlign: TextAlign.center,
      text: TextSpan(
        style: TextStyle(fontSize: 11, color: muted),
        children: [
          TextSpan(
            text: 'Privacy Policy',
            style: const TextStyle(
              decoration: TextDecoration.underline,
              color: SkillDrillsColors.brandBlue,
            ),
            recognizer: TapGestureRecognizer()..onTap = () => _open('https://skilldrills.app/privacy'),
          ),
          TextSpan(text: '  ·  ', style: TextStyle(color: muted)),
          TextSpan(
            text: 'Terms of Use',
            style: const TextStyle(
              decoration: TextDecoration.underline,
              color: SkillDrillsColors.brandBlue,
            ),
            recognizer: TapGestureRecognizer()..onTap = () => _open('https://skilldrills.app/terms'),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Error state
// ─────────────────────────────────────────────────────────────────────────────

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_rounded,
              size: 48,
              color: SkillDrillsColors.lightOnSurfaceMuted,
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15),
            ),
            const SizedBox(height: 20),
            ElevatedButton(onPressed: onRetry, child: const Text('Try Again')),
          ],
        ),
      ),
    );
  }
}
