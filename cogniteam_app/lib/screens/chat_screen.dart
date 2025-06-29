import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cogniteam_app/providers/chat_provider.dart';
import 'package:cogniteam_app/providers/auth_provider.dart'; // For current user ID
import 'package:cogniteam_app/models/message.dart';

class ChatScreen extends ConsumerStatefulWidget {
  final String groupId;
  const ChatScreen({super.key, required this.groupId});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController(); // To scroll to bottom

  @override
  void initState() {
    super.initState();
    // Optionally, trigger initial actions if not handled by provider's init
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _sendMessage() {
    if (_messageController.text.trim().isEmpty) return;
    ref
        .read(chatScreenNotifierProvider(widget.groupId).notifier)
        .sendMessage(_messageController.text.trim());
    _messageController.clear();
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _showSetMissionDialog() {
    final missionTextController = TextEditingController();
    final currentMissionText = ref
        .read(chatScreenNotifierProvider(widget.groupId))
        .currentMission
        ?.missionText;
    if (currentMissionText != null) {
      missionTextController.text = currentMissionText;
    }

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Set Group Mission'),
          content: TextField(
            controller: missionTextController,
            decoration:
                const InputDecoration(hintText: 'Enter mission details...'),
            maxLines: 3,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            Consumer(// Use Consumer here to access ref for the action
                builder: (context, dialogRef, child) {
              return ElevatedButton(
                onPressed: () async {
                  if (missionTextController.text.trim().isNotEmpty) {
                    try {
                      await dialogRef
                          .read(chatScreenNotifierProvider(widget.groupId)
                              .notifier)
                          .setMission(missionTextController.text.trim());
                      Navigator.of(context).pop(); // Close dialog on success
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Mission updated!')),
                      );
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Failed to set mission: $e')),
                      );
                    }
                  }
                },
                child: const Text('Set Mission'),
              );
            }),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(chatScreenNotifierProvider(widget.groupId));
    final currentUserId = ref.watch(appUserProvider)?.userId;

    // Scroll to bottom when messages change
    ref.listen(
        chatScreenNotifierProvider(widget.groupId)
            .select((cs) => cs.messages.length), (_, __) {
      _scrollToBottom();
    });

    return Scaffold(
      appBar: AppBar(
        title: Text(
            'Chat Group: ${widget.groupId.substring(0, 6)}...'), // Show part of group ID or fetch group name
        actions: [
          IconButton(
            icon: const Icon(Icons.assignment),
            tooltip: 'Set Mission',
            onPressed: _showSetMissionDialog,
          ),
        ],
      ),
      body: Column(
        children: [
          // Display current mission if any
          if (chatState.currentMission != null)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Material(
                elevation: 1,
                color: Theme.of(context).colorScheme.secondaryContainer,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12.0, vertical: 8.0),
                  child: Text(
                    "Mission: ${chatState.currentMission!.missionText}",
                    style: TextStyle(
                        fontStyle: FontStyle.italic,
                        color:
                            Theme.of(context).colorScheme.onSecondaryContainer),
                  ),
                ),
              ),
            ),
          Expanded(
            child: chatState.isLoadingMessages
                ? const Center(child: CircularProgressIndicator())
                : chatState.errorMessage != null && chatState.messages.isEmpty
                    ? Center(child: Text('Error: ${chatState.errorMessage}'))
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(8.0),
                        itemCount: chatState.messages.length,
                        itemBuilder: (context, index) {
                          final message = chatState.messages[index];
                          final isMyMessage = message.senderId == currentUserId;
                          return _buildMessageBubble(
                              message, isMyMessage, context);
                        },
                      ),
          ),
          if (chatState.isSendingMessage)
            const Padding(
                padding: EdgeInsets.all(4.0), child: LinearProgressIndicator()),
          if (chatState.errorMessage != null &&
              !chatState
                  .isLoadingMessages) // Show persistent error if not loading
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
              child: Text("Error: ${chatState.errorMessage}",
                  style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ),
          _buildMessageInputField(),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(
      Message message, bool isMyMessage, BuildContext context) {
    return Align(
      alignment: isMyMessage ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
        padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 14.0),
        decoration: BoxDecoration(
          color: isMyMessage
              ? Theme.of(context).colorScheme.primaryContainer
              : Theme.of(context).colorScheme.surfaceVariant,
          borderRadius: BorderRadius.circular(16.0),
        ),
        child: Column(
          crossAxisAlignment:
              isMyMessage ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Text(
              message.senderName ?? message.senderId,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: isMyMessage
                      ? Theme.of(context)
                          .colorScheme
                          .onPrimaryContainer
                          .withOpacity(0.8)
                      : Theme.of(context)
                          .colorScheme
                          .onSurfaceVariant
                          .withOpacity(0.8)),
            ),
            const SizedBox(height: 2),
            Text(message.content,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: isMyMessage
                        ? Theme.of(context).colorScheme.onPrimaryContainer
                        : Theme.of(context).colorScheme.onSurfaceVariant)),
            const SizedBox(height: 4),
            Text(
              // Format timestamp e.g., 10:30 AM
              "${message.timestamp.hour.toString().padLeft(2, '0')}:${message.timestamp.minute.toString().padLeft(2, '0')}",
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  fontSize: 10,
                  color: isMyMessage
                      ? Theme.of(context)
                          .colorScheme
                          .onPrimaryContainer
                          .withOpacity(0.6)
                      : Theme.of(context)
                          .colorScheme
                          .onSurfaceVariant
                          .withOpacity(0.6)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageInputField() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              decoration: InputDecoration(
                hintText: 'Type a message...',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24.0)),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16.0, vertical: 12.0),
              ),
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          const SizedBox(width: 8.0),
          IconButton(
            icon: const Icon(Icons.send),
            onPressed: _sendMessage,
            style: IconButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
                padding: const EdgeInsets.all(12.0)),
          ),
        ],
      ),
    );
  }
}
