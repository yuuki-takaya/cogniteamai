import 'package:flutter/foundation.dart';

// Corresponds to Insight model in the backend
class Insight {
  final String insightId;
  final String groupId;
  final String insightText;
  final String insightType; // e.g., "summary", "sentiment_analysis", "keyword_extraction"
  final DateTime generatedAt;

  Insight({
    required this.insightId,
    required this.groupId,
    required this.insightText,
    required this.insightType,
    required this.generatedAt,
  });

  factory Insight.fromJson(Map<String, dynamic> json) {
    return Insight(
      insightId: json['insight_id'] as String,
      groupId: json['group_id'] as String,
      insightText: json['insight_text'] as String,
      insightType: json['insight_type'] as String,
      generatedAt: DateTime.parse(json['generated_at'] as String).toLocal(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'insight_id': insightId,
      'group_id': groupId,
      'insight_text': insightText,
      'insight_type': insightType,
      'generated_at': generatedAt.toUtc().toIso8601String(),
    };
  }
}
```
