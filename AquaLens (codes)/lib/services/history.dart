import 'package:flutter/foundation.dart';

import 'classifier.dart';

class ClassificationHistoryEntry {
  final String boatType;
  final double confidence;
  final String imagePath;
  final DateTime timestamp;

  ClassificationHistoryEntry({
    required this.boatType,
    required this.confidence,
    required this.imagePath,
    required this.timestamp,
  });
}

/// Simple in-memory history store for classification results.
/// This is reset when the app restarts.
class ClassificationHistory {
  ClassificationHistory._();

  static final ClassificationHistory instance = ClassificationHistory._();

  /// Notifies listeners whenever history changes.
  final ValueNotifier<List<ClassificationHistoryEntry>> entries =
      ValueNotifier<List<ClassificationHistoryEntry>>(<ClassificationHistoryEntry>[]);

  void addResult({
    required ClassificationResult result,
    required String imagePath,
  }) {
    final updated = <ClassificationHistoryEntry>[
      ClassificationHistoryEntry(
        boatType: result.boatType,
        confidence: result.confidence,
        imagePath: imagePath,
        timestamp: DateTime.now(),
      ),
      ...entries.value,
    ];
    entries.value = updated;
  }

  void clear() {
    entries.value = <ClassificationHistoryEntry>[];
  }
}


