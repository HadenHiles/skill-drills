import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:skilldrills/models/firestore/drill.dart';
import 'package:skilldrills/models/firestore/measurement.dart';
import 'package:skilldrills/models/firestore/skill.dart';
import 'package:skilldrills/services/factory.dart';
import 'package:skilldrills/tabs/drills/drill_item.dart';
import 'package:skilldrills/theme/theme.dart';

final FirebaseAuth auth = FirebaseAuth.instance;

class Drills extends StatefulWidget {
  const Drills({super.key});

  @override
  State<Drills> createState() => _DrillsState();
}

class _DrillsState extends State<Drills> with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic));
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Widget _buildDrills(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: isBootstrapping,
      builder: (context, bootstrapping, _) {
        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('drills').doc(auth.currentUser!.uid).collection('drills').orderBy('title', descending: false).snapshots(),
          builder: (context, snapshot) {
            // Still waiting for the first Firestore response
            if (!snapshot.hasData) {
              return _buildSetupLoadingState(context, bootstrapping);
            }
            return _buildDrillList(context, snapshot.data!.docs.cast<DocumentSnapshot<Map<String, dynamic>>>(), bootstrapping);
          },
        );
      },
    );
  }

  Widget _buildSetupLoadingState(BuildContext context, bool bootstrapping) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.secondary.withAlpha(18),
                shape: BoxShape.circle,
              ),
              child: Icon(
                bootstrapping ? Icons.construction_rounded : Icons.fitness_center_rounded,
                size: 52,
                color: Theme.of(context).colorScheme.secondary,
              ),
            ),
            const SizedBox(height: SkillDrillsSpacing.lg),
            Text(
              bootstrapping ? 'Building Your Library…' : 'Loading Drills…',
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: SkillDrillsSpacing.sm),
            Text(
              bootstrapping
                  ? 'Generating your default drill templates. This only happens once.'
                  : 'Hang tight…',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: SkillDrillsSpacing.lg),
            const SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrillList(BuildContext context, List<DocumentSnapshot<Map<String, dynamic>>> snapshot, bool bootstrapping) {
    List<DrillItem> items = [];

    for (var docSnap in snapshot) {
      Drill d = Drill.fromSnapshot(docSnap);
      d.reference!.collection('measurements').get().then((mSnap) {
        List<Measurement>? measurements = [];
        for (var m in mSnap.docs) {
          measurements.add(Measurement.fromSnapshot(m));
        }
        d.measurements = measurements;
      });
      d.reference!.collection('skills').get().then((cSnap) {
        List<Skill> categories = [];
        for (var m in cSnap.docs) {
          categories.add(Skill.fromSnapshot(m));
        }
        d.skills = categories;
      });
      items.add(DrillItem(drill: d, deleteCallback: _deleteDrill));
    }

    if (items.isEmpty) {
      // Bootstrap is still running — drills are being written to Firestore.
      if (bootstrapping) {
        return _buildSetupLoadingState(context, true);
      }
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.secondary.withAlpha(18),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.fitness_center_rounded,
                  size: 52,
                  color: Theme.of(context).colorScheme.secondary,
                ),
              ),
              const SizedBox(height: SkillDrillsSpacing.lg),
              Text(
                'No Drills Yet',
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: SkillDrillsSpacing.sm),
              Text(
                'Tap the + button to create your first drill',
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.only(top: 8, bottom: 24),
      children: items,
    );
  }

  void _deleteDrill(Drill drill) {
    final ref = FirebaseFirestore.instance.collection('drills').doc(auth.currentUser!.uid).collection('drills').doc(drill.reference!.id);

    ref.get().then((doc) {
      doc.reference.collection('measurements').get().then((mSnapshots) {
        for (var mDoc in mSnapshots.docs) {
          mDoc.reference.delete();
        }
      });
      doc.reference.collection('skills').get().then((catSnapshots) {
        for (var cDoc in catSnapshots.docs) {
          cDoc.reference.delete();
        }
      });
      doc.reference.delete();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnim,
      child: SlideTransition(
        position: _slideAnim,
        child: _buildDrills(context),
      ),
    );
  }
}
