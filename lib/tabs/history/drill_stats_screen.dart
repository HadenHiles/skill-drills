import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:skilldrills/main.dart';
import 'package:skilldrills/models/firestore/session.dart';
import 'package:skilldrills/services/subscription.dart';
import 'package:skilldrills/theme/theme.dart';
import 'package:skilldrills/widgets/paywall_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────

/// Shows a line-chart trend for each measurement of a specific drill.
///
/// Loads the last 50 sessions for the user, filters client-side to those
/// containing the given [drillId], and renders one line per measurement label.
///
/// Pro-only: free users see a blurred placeholder with an upgrade prompt.
class DrillStatsScreen extends StatefulWidget {
  const DrillStatsScreen({
    super.key,
    required this.drillId,
    required this.drillTitle,
  });

  final String drillId;
  final String drillTitle;

  @override
  State<DrillStatsScreen> createState() => _DrillStatsScreenState();
}

class _DrillStatsScreenState extends State<DrillStatsScreen> {
  bool _loading = true;
  bool _isPro = false;

  /// One entry per matching session (oldest → newest).
  /// Outer key: measurement label. Value: list of values in session order.
  final Map<String, List<_DataPoint>> _series = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final results = await Future.wait([
      hasActiveSubscription(),
      FirebaseFirestore.instance.collection('sessions').doc(uid).collection('sessions').orderBy('started_at', descending: true).limit(50).get(),
    ]);

    final isPro = results[0] as bool;
    final snap = results[1] as QuerySnapshot;

    // Filter sessions client-side to those containing the target drill.
    final series = <String, List<_DataPoint>>{};
    final docs = snap.docs.reversed.toList(); // oldest → newest

    for (final doc in docs) {
      final session = Session.fromSnapshot(doc as DocumentSnapshot<Map<String, dynamic>>);
      final drillResult = session.drillResults.cast<DrillResult?>().firstWhere((d) => d?.drillId == widget.drillId, orElse: () => null);
      if (drillResult == null) continue;

      // Best value per measurement across all sets.
      final best = <String, ({num value, String type})>{};
      for (final setResult in drillResult.setResults) {
        for (final m in setResult.measurementResults) {
          if (m.value == null) continue;
          final existing = best[m.label];
          if (existing == null) {
            best[m.label] = (value: m.value!, type: m.type);
          } else if (m.type == 'duration' ? m.value! < existing.value : m.value! > existing.value) {
            best[m.label] = (value: m.value!, type: m.type);
          }
        }
      }

      for (final entry in best.entries) {
        series.putIfAbsent(entry.key, () => []).add(
              _DataPoint(
                date: session.startedAt,
                value: entry.value.value.toDouble(),
                type: entry.value.type,
              ),
            );
      }
    }

    if (mounted) {
      setState(() {
        _isPro = isPro;
        _series
          ..clear()
          ..addAll(series);
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.drillTitle, style: const TextStyle(fontFamily: 'Choplin')),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _isPro
              ? _buildCharts(context)
              : _buildGatedView(context),
    );
  }

  // ── Pro view: one chart card per measurement ──────────────────────────────

  Widget _buildCharts(BuildContext context) {
    if (_series.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.bar_chart_rounded, size: 52, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.25)),
              const SizedBox(height: 16),
              Text('No data yet', style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 8),
              Text(
                'Complete sessions with this drill to see progress charts.',
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(SkillDrillsSpacing.md),
      children: _series.entries.map((e) => _ChartCard(label: e.key, points: e.value)).toList(),
    );
  }

  // ── Free upsell view ──────────────────────────────────────────────────────

  Widget _buildGatedView(BuildContext context) {
    return Stack(
      children: [
        // Fake blurred chart in the background.
        ImageFiltered(
          imageFilter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Padding(
            padding: const EdgeInsets.all(SkillDrillsSpacing.md),
            child: _FakePlaceholderChart(),
          ),
        ),
        // Overlay.
        Center(
          child: Card(
            margin: const EdgeInsets.all(32),
            child: Padding(
              padding: const EdgeInsets.all(SkillDrillsSpacing.xl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.lock_rounded, size: 36),
                  const SizedBox(height: 12),
                  Text(
                    'Progress Charts',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontFamily: 'Choplin'),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Unlock trend charts for every drill measurement with Skill Drills Pro.',
                    style: Theme.of(context).textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: SkillDrillsSpacing.md),
                  ElevatedButton.icon(
                    onPressed: () => navigatorKey.currentState!.push(
                      MaterialPageRoute(fullscreenDialog: true, builder: (_) => const PaywallScreen()),
                    ),
                    icon: const Icon(Icons.star_rounded, size: 18),
                    label: const Text('Upgrade to Pro', style: TextStyle(fontFamily: 'Choplin', fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Chart card: one measurement label → line chart
// ─────────────────────────────────────────────────────────────────────────────

class _ChartCard extends StatelessWidget {
  const _ChartCard({required this.label, required this.points});

  final String label;
  final List<_DataPoint> points;

  String _format(double v, _DataPoint? ref) {
    if (ref == null) return v.toStringAsFixed(0);
    if (ref.type == 'duration') {
      final d = Duration(seconds: v.toInt());
      final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
      final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
      return d.inHours >= 1 ? '${d.inHours}:$m:$s' : '$m:$s';
    }
    return v.toStringAsFixed(0);
  }

  @override
  Widget build(BuildContext context) {
    final spots = points.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value.value)).toList();
    final minY = spots.map((s) => s.y).reduce((a, b) => a < b ? a : b);
    final maxY = spots.map((s) => s.y).reduce((a, b) => a > b ? a : b);
    final yRange = (maxY - minY).abs();
    final yPadding = yRange < 1 ? 1.0 : yRange * 0.15;
    final color = Theme.of(context).primaryColor;

    return Card(
      margin: const EdgeInsets.only(bottom: SkillDrillsSpacing.md),
      child: Padding(
        padding: const EdgeInsets.all(SkillDrillsSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text('${points.length} session${points.length == 1 ? '' : 's'}', style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: SkillDrillsSpacing.md),
            SizedBox(
              height: 180,
              child: LineChart(
                LineChartData(
                  minY: (minY - yPadding).clamp(0, double.infinity),
                  maxY: maxY + yPadding,
                  gridData: FlGridData(
                    horizontalInterval: yPadding > 0 ? yPadding : 1,
                    getDrawingHorizontalLine: (_) => FlLine(
                      color: Theme.of(context).dividerColor,
                      strokeWidth: 1,
                    ),
                    drawVerticalLine: false,
                  ),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 48,
                        getTitlesWidget: (v, _) => Text(
                          _format(v, points.firstOrNull),
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 10),
                        ),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        interval: spots.length > 6 ? (spots.length / 4).ceilToDouble() : 1,
                        getTitlesWidget: (v, _) {
                          final i = v.toInt();
                          if (i < 0 || i >= points.length) return const SizedBox.shrink();
                          final d = points[i].date;
                          return Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              '${d.month}/${d.day}',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 10),
                            ),
                          );
                        },
                      ),
                    ),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      color: color,
                      barWidth: 2.5,
                      belowBarData: BarAreaData(
                        show: true,
                        color: color.withValues(alpha: 0.08),
                      ),
                      dotData: FlDotData(
                        getDotPainter: (spot, _, __, ___) => FlDotCirclePainter(
                          radius: 3.5,
                          color: color,
                          strokeColor: Theme.of(context).colorScheme.surface,
                          strokeWidth: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Placeholder "blurred" chart shown to free users
// ─────────────────────────────────────────────────────────────────────────────

class _FakePlaceholderChart extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).primaryColor;
    // A static fake chart with random-ish spots to give the blur something to render.
    const fakeSpots = [
      FlSpot(0, 10),
      FlSpot(1, 14),
      FlSpot(2, 12),
      FlSpot(3, 18),
      FlSpot(4, 15),
      FlSpot(5, 20),
      FlSpot(6, 22),
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(SkillDrillsSpacing.md),
        child: SizedBox(
          height: 200,
          child: LineChart(
            LineChartData(
              lineBarsData: [
                LineChartBarData(
                  spots: fakeSpots,
                  isCurved: true,
                  color: color,
                  barWidth: 2.5,
                  belowBarData: BarAreaData(show: true, color: color.withValues(alpha: 0.08)),
                ),
              ],
              titlesData: const FlTitlesData(show: false),
              borderData: FlBorderData(show: false),
              gridData: const FlGridData(show: false),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _DataPoint {
  final DateTime date;
  final double value;
  final String type;

  const _DataPoint({required this.date, required this.value, required this.type});
}
