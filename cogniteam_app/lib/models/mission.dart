import 'package:flutter/foundation.dart';

// Corresponds to Mission model in the backend
class Mission {
  final String missionId;
  final String groupId;
  final String missionText;
  final String status; // e.g., "pending", "in_progress", "completed"
  final DateTime createdAt;
  // final DateTime? updatedAt; // Optional

  Mission({
    required this.missionId,
    required this.groupId,
    required this.missionText,
    required this.status,
    required this.createdAt,
    // this.updatedAt,
  });

  factory Mission.fromJson(Map<String, dynamic> json) {
    return Mission(
      missionId: json['mission_id'] as String,
      groupId: json['group_id'] as String,
      missionText: json['mission_text'] as String,
      status: json['status'] as String,
      createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
      // updatedAt: json['updated_at'] == null ? null : DateTime.parse(json['updated_at'] as String).toLocal(),
    );
  }

  Map<String, dynamic> toJson() {
    // Client might primarily send MissionCreationData, but toJson can be useful.
    return {
      'mission_id': missionId,
      'group_id': groupId,
      'mission_text': missionText,
      'status': status,
      'created_at': createdAt.toUtc().toIso8601String(),
      // 'updated_at': updatedAt?.toUtc().toIso8601String(),
    };
  }
}

// Corresponds to MissionCreate model in the backend
class MissionCreationData {
  final String missionText;

  MissionCreationData({required this.missionText});

  Map<String, dynamic> toJson() {
    return {
      'mission_text': missionText,
    };
  }
}
```
