import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:skilldrills/models/firestore/category.dart';
import 'package:skilldrills/models/firestore/drill.dart';
import 'package:skilldrills/models/firestore/measurement.dart';
import 'package:skilldrills/tabs/drills/drill_item.dart';

final FirebaseAuth auth = FirebaseAuth.instance;

class Drills extends StatefulWidget {
  const Drills({super.key});

  @override
  State<Drills> createState() => _DrillsState();
}

class _DrillsState extends State<Drills> {
  Widget _buildDrills(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('drills').doc(auth.currentUser!.uid).collection('drills').orderBy('title', descending: false).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return Column(
              children: [
                LinearProgressIndicator(
                  backgroundColor: Theme.of(context).primaryColor,
                ),
              ],
            );
          }

          return _buildDrillList(context, snapshot.data!.docs.cast<DocumentSnapshot<Map<String, dynamic>>>());
        });
  }

  Widget _buildDrillList(BuildContext context, List<DocumentSnapshot<Map<String, dynamic>>> snapshot) {
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

      d.reference!.collection('categories').get().then((cSnap) {
        List<Category> categories = [];

        for (var m in cSnap.docs) {
          categories.add(Category.fromSnapshot(m));
        }

        d.categories = categories;
      });

      items.add(
        DrillItem(
          drill: d,
          deleteCallback: _deleteDrill,
        ),
      );
    }

    return items.isNotEmpty
        ? ListView(
            padding: const EdgeInsets.only(top: 10),
            children: items,
          )
        : const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                "There are no drills to display",
                style: TextStyle(
                  fontSize: 16,
                ),
              ),
            ],
          );
  }

  void _deleteDrill(Drill drill) {
    FirebaseFirestore.instance.collection('drills').doc(auth.currentUser!.uid).collection('drills').doc(drill.reference!.id).delete();

    FirebaseFirestore.instance.collection('drills').doc(auth.currentUser!.uid).collection('drills').doc(drill.reference!.id).get().then((doc) {
      doc.reference.collection('measurements').get().then((mSnapshots) {
        for (var mDoc in mSnapshots.docs) {
          mDoc.reference.delete();
        }
      });

      doc.reference.collection('categories').get().then((catSnapshots) {
        for (var cDoc in catSnapshots.docs) {
          cDoc.reference.delete();
        }
      });

      doc.reference.delete();
    });
  }

  @override
  Widget build(BuildContext context) {
    return _buildDrills(context);
  }
}
