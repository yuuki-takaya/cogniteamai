import 'package:flutter/foundation.dart';

// Corresponds to ChatGroup model in the backend
class ChatGroup {
  final String groupId;
  final String groupName;
  final List<String> agentIds;
  final String createdBy; // User ID of the creator
  final DateTime createdAt;
  final List<String> memberUserIds;
  final String? activeMissionId;
  final DateTime? lastMessageAt;
  final String? lastMessageSnippet;

  ChatGroup({
    required this.groupId,
    required this.groupName,
    required this.agentIds,
    required this.createdBy,
    required this.createdAt,
    required this.memberUserIds,
    this.activeMissionId,
    this.lastMessageAt,
    this.lastMessageSnippet,
  });

  factory ChatGroup.fromJson(Map<String, dynamic> json) {
    return ChatGroup(
      groupId: json['group_id'] as String,
      groupName: json['group_name'] as String,
      agentIds: List<String>.from(json['agent_ids'] as List<dynamic>),
      createdBy: json['created_by'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      memberUserIds: List<String>.from(json['member_user_ids'] as List<dynamic>),
      activeMissionId: json['active_mission_id'] as String?,
      lastMessageAt: json['last_message_at'] == null
          ? null
          : DateTime.parse(json['last_message_at'] as String),
      lastMessageSnippet: json['last_message_snippet'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'group_id': groupId,
      'group_name': groupName,
      'agent_ids': agentIds,
      'created_by': createdBy,
      'created_at': createdAt.toIso8601String(),
      'member_user_ids': memberUserIds,
      'active_mission_id': activeMissionId,
      'last_message_at': lastMessageAt?.toIso8601String(),
      'last_message_snippet': lastMessageSnippet,
    };
  }
}

// Corresponds to ChatGroupCreate model in the backend
class ChatGroupCreationData {
  final String groupName;
  final List<String> agentIds;

  ChatGroupCreationData({
    required this.groupName,
    required this.agentIds,
  });

  Map<String, dynamic> toJson() {
    return {
      'group_name': groupName,
      'agent_ids': agentIds,
    };
  }
}
```
