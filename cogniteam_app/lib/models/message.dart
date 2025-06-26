// Corresponds to Message model in the backend
class Message {
  final String messageId;
  final String groupId;
  final String senderId; // User ID or Agent ID
  final String? senderName; // Display name of the sender
  final String content;
  final DateTime
      timestamp; // Store as DateTime, convert from/to ISO string for API

  Message({
    required this.messageId,
    required this.groupId,
    required this.senderId,
    this.senderName,
    required this.content,
    required this.timestamp,
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      messageId: json['message_id'] as String,
      groupId: json['group_id'] as String,
      senderId: json['sender_id'] as String,
      senderName: json['sender_name'] as String?,
      content: json['content'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String)
          .toLocal(), // Parse and convert to local time
    );
  }

  Map<String, dynamic> toJson() {
    // Typically, client doesn't send full Message objects to backend,
    // rather just content or specific actions.
    // This is more for local use or if sending structured messages via WebSocket.
    return {
      'message_id': messageId,
      'group_id': groupId,
      'sender_id': senderId,
      'sender_name': senderName,
      'content': content,
      'timestamp':
          timestamp.toUtc().toIso8601String(), // Send as UTC ISO string
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Message &&
          runtimeType == other.runtimeType &&
          messageId == other.messageId;

  @override
  int get hashCode => messageId.hashCode;

  @override
  String toString() {
    return 'Message{messageId: $messageId, senderId: $senderId, content: "$content"}';
  }
}
