import 'package:cloud_firestore/cloud_firestore.dart';

/// A note attached to a drill — either defined in a [Routine] or added on the
/// fly during a session.
///
/// Notes with [isPinned] == true are carried forward to future sessions of the
/// same routine+drill so the user can see them without re-creating them.
///
/// [source] is a lightweight tag:
///   'routine' — note was authored in the routine builder (always visible)
///   'session' — note was added on the fly during a session
class DrillNote {
  String? id;

  /// The note text.
  String text;

  /// When true this note is surfaced at the start of future sessions for the
  /// same routine+drill. Users can pin/unpin at any time.
  bool isPinned;

  final DateTime createdAt;

  /// 'routine' or 'session'. Informational only — drives UI labelling.
  final String source;

  DrillNote({
    this.id,
    required this.text,
    this.isPinned = false,
    required this.createdAt,
    this.source = 'session',
  });

  factory DrillNote.routine(String text) => DrillNote(
        text: text,
        isPinned: true,
        createdAt: DateTime.now(),
        source: 'routine',
      );

  factory DrillNote.session(String text, {bool isPinned = false}) => DrillNote(
        text: text,
        isPinned: isPinned,
        createdAt: DateTime.now(),
        source: 'session',
      );

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'text': text,
        'is_pinned': isPinned,
        'created_at': Timestamp.fromDate(createdAt),
        'source': source,
      };

  DrillNote.fromMap(Map<String, dynamic> map)
      : id = map['id'] as String?,
        text = (map['text'] as String?) ?? '',
        isPinned = (map['is_pinned'] as bool?) ?? false,
        createdAt = map['created_at'] != null ? (map['created_at'] as Timestamp).toDate() : DateTime.now(),
        source = (map['source'] as String?) ?? 'session';

  DrillNote copyWith({
    String? text,
    bool? isPinned,
  }) =>
      DrillNote(
        id: id,
        text: text ?? this.text,
        isPinned: isPinned ?? this.isPinned,
        createdAt: createdAt,
        source: source,
      );
}
