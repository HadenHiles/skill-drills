// ignore_for_file: avoid_print

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:skilldrills/login.dart';
import 'package:skilldrills/models/onboarding_preferences.dart';
import 'package:skilldrills/models/settings.dart';
import 'package:skilldrills/theme/settings_state_notifier.dart';
import 'package:skilldrills/theme/theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Activity metadata used on the picker page
// ─────────────────────────────────────────────────────────────────────────────

const Map<String, String> _activityEmoji = {
  'Hockey': '🏒',
  'Basketball': '🏀',
  'Baseball': '⚾',
  'Golf': '⛳',
  'Soccer': '⚽',
  'Weight Training': '🏋️',
  'Tennis': '🎾',
  'Running': '🏃',
  'Volleyball': '🏐',
  'Martial Arts': '🥋',
  'Pickleball': '🏓',
  'Lacrosse': '🥍',
  'Gymnastics': '🤸',
  'Guitar': '🎸',
};

// ─────────────────────────────────────────────────────────────────────────────
// WelcomeScreen – 4-page onboarding flow
// ─────────────────────────────────────────────────────────────────────────────

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  final _pageController = PageController();
  int _currentPage = 0;
  static const int _totalPages = 4;

  // ── Onboarding state ──────────────────────────────────────────────────────
  List<String> _selectedActivities = [];
  bool _includeDefaultDrills = true;

  // ── Navigation ────────────────────────────────────────────────────────────

  void _nextPage() {
    if (_currentPage < _totalPages - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _onGetStarted() async {
    try {
      final prefs = OnboardingPreferences(
        selectedActivities: _selectedActivities,
        includeDefaultDrills: _includeDefaultDrills,
      );
      await prefs.save();
      await OnboardingPreferences.markWelcomeSeen();
    } catch (e) {
      print('Welcome: failed to save onboarding prefs: $e');
    }
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const Login()),
    );
  }

  // ── Shared gradient decoration ────────────────────────────────────────────

  static const _gradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF0186B5),
      SkillDrillsColors.brandBlue,
      Color(0xFF01C4A1),
    ],
    stops: [0.0, 0.5, 1.0],
  );

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: _gradient),
        child: SafeArea(
          child: Column(
            children: [
              // ── Pages ───────────────────────────────────────────────────
              Expanded(
                child: PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  onPageChanged: (i) => setState(() => _currentPage = i),
                  children: [
                    _IntroPage(onNext: _nextPage),
                    _ActivityPickerPage(
                      selectedActivities: _selectedActivities,
                      onChanged: (updated) => setState(() => _selectedActivities = updated),
                      onNext: _nextPage,
                    ),
                    _PreferencesPage(
                      includeDefaultDrills: _includeDefaultDrills,
                      onIncludeDefaultDrillsChanged: (v) => setState(() => _includeDefaultDrills = v),
                      onNext: _nextPage,
                    ),
                    _GetStartedPage(onGetStarted: _onGetStarted),
                  ],
                ),
              ),

              // ── Progress dots ─────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.only(bottom: 32),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(_totalPages, (i) {
                    final active = i == _currentPage;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: active ? 24 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: active ? Colors.white : Colors.white.withValues(alpha: 0.4),
                        borderRadius: SkillDrillsRadius.fullBorderRadius,
                      ),
                    );
                  }),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Page 1 – Intro / Feature Highlights
// ─────────────────────────────────────────────────────────────────────────────

class _IntroPage extends StatelessWidget {
  final VoidCallback onNext;

  const _IntroPage({required this.onNext});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            height: 100,
            child: SvgPicture.asset(
              'assets/images/logo/SkillDrills.svg',
              semanticsLabel: 'Skill Drills',
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Level up your\npractice.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontFamily: 'Choplin',
              fontWeight: FontWeight.w700,
              fontSize: 34,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Track drills, measure your progress,\nand build better habits—for any\nactivity or skill.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 16,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 40),

          // ── Feature cards ─────────────────────────────────────────────
          _FeatureCard(
            emoji: '🎯',
            title: 'Track Every Rep',
            description: 'Log results for any drill — reps, times, scores — with flexible measurement schemas.',
          ),
          const SizedBox(height: 12),
          _FeatureCard(
            emoji: '📈',
            title: 'See Your Progress',
            description: 'Review session history, spot trends, and watch your personal bests improve over time.',
          ),
          const SizedBox(height: 12),
          _FeatureCard(
            emoji: '🔁',
            title: 'Build Routines',
            description: 'Save ordered drill sets and run focused practice sessions with a single tap.',
          ),
          const SizedBox(height: 40),

          // ── Continue button ───────────────────────────────────────────
          _ContinueButton(label: 'Get Started', onPressed: onNext),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  final String emoji;
  final String title;
  final String description;

  const _FeatureCard({
    required this.emoji,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: SkillDrillsRadius.mdBorderRadius,
        border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 1),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 28)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontFamily: 'Choplin',
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  description,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.75),
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Page 2 – Activity Picker
// ─────────────────────────────────────────────────────────────────────────────

const int _maxActivities = 2;

class _ActivityPickerPage extends StatelessWidget {
  final List<String> selectedActivities;
  final ValueChanged<List<String>> onChanged;
  final VoidCallback onNext;

  const _ActivityPickerPage({
    required this.selectedActivities,
    required this.onChanged,
    required this.onNext,
  });

  void _toggle(String activity) {
    final updated = List<String>.from(selectedActivities);
    if (updated.contains(activity)) {
      updated.remove(activity);
    } else if (updated.length < _maxActivities) {
      updated.add(activity);
    }
    onChanged(updated);
  }

  @override
  Widget build(BuildContext context) {
    final activities = _activityEmoji.keys.toList();
    final atMax = selectedActivities.length >= _maxActivities;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // ── Header ──────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 0),
          child: Column(
            children: [
              const Text(
                'What do you train?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontFamily: 'Choplin',
                  fontWeight: FontWeight.w700,
                  fontSize: 28,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Pick up to $_maxActivities activities. Free accounts get $_maxActivities active—you can unlock more later.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.75),
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 20),

              // Selection counter pill
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: selectedActivities.isEmpty
                    ? const SizedBox.shrink()
                    : Container(
                        key: ValueKey(selectedActivities.length),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: SkillDrillsRadius.fullBorderRadius,
                        ),
                        child: Text(
                          '${selectedActivities.length} / $_maxActivities selected',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // ── Activity grid ────────────────────────────────────────────────
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 0.9,
            ),
            itemCount: activities.length,
            itemBuilder: (context, i) {
              final name = activities[i];
              final emoji = _activityEmoji[name] ?? '🏅';
              final selected = selectedActivities.contains(name);
              final disabled = atMax && !selected;

              return _ActivityTile(
                name: name,
                emoji: emoji,
                selected: selected,
                disabled: disabled,
                onTap: () => _toggle(name),
              );
            },
          ),
        ),

        // ── Continue button ──────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
          child: _ContinueButton(
            label: selectedActivities.isEmpty ? 'Skip for now' : 'Continue',
            onPressed: onNext,
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

class _ActivityTile extends StatelessWidget {
  final String name;
  final String emoji;
  final bool selected;
  final bool disabled;
  final VoidCallback onTap;

  const _ActivityTile({
    required this.name,
    required this.emoji,
    required this.selected,
    required this.disabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: selected ? Colors.white : Colors.white.withValues(alpha: disabled ? 0.06 : 0.14),
        borderRadius: SkillDrillsRadius.mdBorderRadius,
        border: Border.all(
          color: selected ? Colors.white : Colors.white.withValues(alpha: disabled ? 0.1 : 0.25),
          width: 1.5,
        ),
      ),
      child: InkWell(
        borderRadius: SkillDrillsRadius.mdBorderRadius,
        onTap: disabled ? null : onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              alignment: Alignment.topRight,
              children: [
                Text(emoji, style: const TextStyle(fontSize: 32)),
                if (selected)
                  Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(
                      color: SkillDrillsColors.brandBlue,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.check, color: Colors.white, size: 10),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              name,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: selected ? SkillDrillsColors.brandBlue : Colors.white.withValues(alpha: disabled ? 0.4 : 0.9),
                fontFamily: 'Choplin',
                fontWeight: FontWeight.w600,
                fontSize: 11,
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Page 3 – Preferences
// ─────────────────────────────────────────────────────────────────────────────

class _PreferencesPage extends StatelessWidget {
  final bool includeDefaultDrills;
  final ValueChanged<bool> onIncludeDefaultDrillsChanged;
  final VoidCallback onNext;

  const _PreferencesPage({
    required this.includeDefaultDrills,
    required this.onIncludeDefaultDrillsChanged,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Center(
            child: Text(
              'Set up your experience',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontFamily: 'Choplin',
                fontWeight: FontWeight.w700,
                fontSize: 28,
                height: 1.2,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              'These can all be changed later in Settings.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.75),
                fontSize: 14,
                height: 1.4,
              ),
            ),
          ),
          const SizedBox(height: 32),

          // ── Appearance ────────────────────────────────────────────────
          _SectionLabel(label: 'Appearance'),
          const SizedBox(height: 8),
          _ThemeSelectorCard(),
          const SizedBox(height: 24),

          // ── Content ───────────────────────────────────────────────────
          _SectionLabel(label: 'Content'),
          const SizedBox(height: 8),
          _PrefToggleCard(
            icon: Icons.library_books_outlined,
            title: 'Include template drills',
            subtitle: 'Start with pre-built drill types tailored to your selected activities. You can delete or customise them any time.',
            value: includeDefaultDrills,
            onChanged: onIncludeDefaultDrillsChanged,
          ),
          const SizedBox(height: 24),

          // ── Feedback ──────────────────────────────────────────────────
          _SectionLabel(label: 'Feedback'),
          const SizedBox(height: 8),
          _VibrationToggleCard(),
          const SizedBox(height: 40),

          // ── Continue button ───────────────────────────────────────────
          _ContinueButton(label: 'Continue', onPressed: onNext),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;

  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: TextStyle(
        color: Colors.white.withValues(alpha: 0.55),
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
      ),
    );
  }
}

class _PrefToggleCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _PrefToggleCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: SkillDrillsRadius.mdBorderRadius,
        border: Border.all(color: Colors.white.withValues(alpha: 0.18), width: 1),
      ),
      child: SwitchListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        secondary: Icon(icon, color: Colors.white.withValues(alpha: 0.85), size: 22),
        title: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontFamily: 'Choplin',
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.65),
            fontSize: 12,
            height: 1.4,
          ),
        ),
        value: value,
        onChanged: onChanged,
        activeThumbColor: SkillDrillsColors.brandBlue,
        inactiveThumbColor: Colors.white.withValues(alpha: 0.5),
        inactiveTrackColor: Colors.white.withValues(alpha: 0.2),
      ),
    );
  }
}

/// Reads / writes dark mode via [SettingsStateNotifier] so the change is
/// reflected immediately throughout the app.
class _ThemeSelectorCard extends StatelessWidget {
  const _ThemeSelectorCard();

  @override
  Widget build(BuildContext context) {
    final notifier = context.watch<SettingsStateNotifier>();
    final isDark = notifier.settings.darkMode;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: SkillDrillsRadius.mdBorderRadius,
        border: Border.all(color: Colors.white.withValues(alpha: 0.18), width: 1),
      ),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Row(
        children: [
          Icon(Icons.palette_outlined, color: Colors.white.withValues(alpha: 0.85), size: 22),
          const SizedBox(width: 14),
          const Expanded(
            child: Text(
              'App Theme',
              style: TextStyle(
                color: Colors.white,
                fontFamily: 'Choplin',
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
            ),
          ),
          _ThemeToggle(
            isDark: isDark,
            onChanged: (dark) {
              final current = notifier.settings;
              notifier.updateSettings(Settings(current.vibrate, dark));
            },
          ),
        ],
      ),
    );
  }
}

class _ThemeToggle extends StatelessWidget {
  final bool isDark;
  final ValueChanged<bool> onChanged;

  const _ThemeToggle({required this.isDark, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: SkillDrillsRadius.smBorderRadius,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ThemeChip(
            label: 'Light',
            icon: Icons.light_mode_outlined,
            active: !isDark,
            onTap: () => onChanged(false),
          ),
          _ThemeChip(
            label: 'Dark',
            icon: Icons.dark_mode_outlined,
            active: isDark,
            onTap: () => onChanged(true),
          ),
        ],
      ),
    );
  }
}

class _ThemeChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool active;
  final VoidCallback onTap;

  const _ThemeChip({
    required this.label,
    required this.icon,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: active ? Colors.white : Colors.transparent,
          borderRadius: SkillDrillsRadius.smBorderRadius,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: active ? SkillDrillsColors.brandBlue : Colors.white.withValues(alpha: 0.6),
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: active ? SkillDrillsColors.brandBlue : Colors.white.withValues(alpha: 0.6),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Reads / writes vibration setting via [SettingsStateNotifier].
class _VibrationToggleCard extends StatelessWidget {
  const _VibrationToggleCard();

  @override
  Widget build(BuildContext context) {
    final notifier = context.watch<SettingsStateNotifier>();
    final vibrate = notifier.settings.vibrate;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: SkillDrillsRadius.mdBorderRadius,
        border: Border.all(color: Colors.white.withValues(alpha: 0.18), width: 1),
      ),
      child: SwitchListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        secondary: Icon(Icons.vibration, color: Colors.white.withValues(alpha: 0.85), size: 22),
        title: const Text(
          'Vibration',
          style: TextStyle(
            color: Colors.white,
            fontFamily: 'Choplin',
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
        subtitle: Text(
          'Haptic feedback when timers fire and sessions end.',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.65),
            fontSize: 12,
            height: 1.4,
          ),
        ),
        value: vibrate,
        onChanged: (v) {
          final current = notifier.settings;
          notifier.updateSettings(Settings(v, current.darkMode));
        },
        activeThumbColor: SkillDrillsColors.brandBlue,
        inactiveThumbColor: Colors.white.withValues(alpha: 0.5),
        inactiveTrackColor: Colors.white.withValues(alpha: 0.2),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Page 4 – Get Started (auth CTA)
// ─────────────────────────────────────────────────────────────────────────────

class _GetStartedPage extends StatelessWidget {
  final VoidCallback onGetStarted;

  const _GetStartedPage({required this.onGetStarted});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // ── Success icon ─────────────────────────────────────────────
          Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 2),
            ),
            child: const Center(
              child: Text('🎉', style: TextStyle(fontSize: 40)),
            ),
          ),
          const SizedBox(height: 24),

          const Text(
            "You're all set!",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontFamily: 'Choplin',
              fontWeight: FontWeight.w700,
              fontSize: 32,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Create a free account to save your progress,\nsync across devices, and start tracking.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 15,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),

          // ── Pro teaser ────────────────────────────────────────────────
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: SkillDrillsRadius.mdBorderRadius,
              border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 1),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                const Text('⚡', style: TextStyle(fontSize: 20)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Upgrade anytime to unlock more active activities, saved routines, and advanced analytics.',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 40),

          // ── Primary CTA ───────────────────────────────────────────────
          SizedBox(
            height: 56,
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: SkillDrillsColors.brandBlue,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: SkillDrillsRadius.smBorderRadius,
                ),
              ),
              onPressed: onGetStarted,
              child: const Text(
                'Create Account',
                style: TextStyle(
                  fontFamily: 'Choplin',
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // ── Secondary: sign in ────────────────────────────────────────
          SizedBox(
            height: 52,
            width: double.infinity,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Colors.white, width: 1.5),
                shape: RoundedRectangleBorder(
                  borderRadius: SkillDrillsRadius.smBorderRadius,
                ),
              ),
              onPressed: onGetStarted,
              child: Text(
                'I already have an account',
                style: TextStyle(
                  fontFamily: 'Choplin',
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                  color: Colors.white.withValues(alpha: 0.9),
                  letterSpacing: 0.2,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared Widgets
// ─────────────────────────────────────────────────────────────────────────────

class _ContinueButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;

  const _ContinueButton({required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      width: double.infinity,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: SkillDrillsColors.brandBlue,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: SkillDrillsRadius.smBorderRadius,
          ),
        ),
        onPressed: onPressed,
        child: Text(
          label,
          style: const TextStyle(
            fontFamily: 'Choplin',
            fontWeight: FontWeight.w700,
            fontSize: 16,
            letterSpacing: 0.3,
          ),
        ),
      ),
    );
  }
}
