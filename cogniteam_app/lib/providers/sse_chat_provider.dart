import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cogniteam_app/models/message.dart';
import 'package:cogniteam_app/models/mission.dart';
import 'package:cogniteam_app/services/chat_group_service.dart';
import 'package:cogniteam_app/services/sse_service.dart';
import 'package:cogniteam_app/providers/auth_provider.dart';

// Represents the state of a single chat screen with SSE
class SSEChatScreenState {
  final List<Message> messages;
  final Mission? currentMission;
  final bool isLoadingMessages;
  final bool isSendingMessage;
  final bool isSettingMission;
  final bool isSSEConnected;
  final String? errorMessage;

  SSEChatScreenState({
    this.messages = const [],
    this.currentMission,
    this.isLoadingMessages = true,
    this.isSendingMessage = false,
    this.isSettingMission = false,
    this.isSSEConnected = false,
    this.errorMessage,
  });

  SSEChatScreenState copyWith({
    List<Message>? messages,
    Mission? currentMission,
    bool? isLoadingMessages,
    bool? isSendingMessage,
    bool? isSettingMission,
    bool? isSSEConnected,
    String? errorMessage,
    bool clearErrorMessage = false,
  }) {
    return SSEChatScreenState(
      messages: messages ?? this.messages,
      currentMission: currentMission ?? this.currentMission,
      isLoadingMessages: isLoadingMessages ?? this.isLoadingMessages,
      isSendingMessage: isSendingMessage ?? this.isSendingMessage,
      isSettingMission: isSettingMission ?? this.isSettingMission,
      isSSEConnected: isSSEConnected ?? this.isSSEConnected,
      errorMessage:
          clearErrorMessage ? null : errorMessage ?? this.errorMessage,
    );
  }
}

class SSEChatScreenNotifier extends StateNotifier<SSEChatScreenState> {
  final String groupId;
  final ChatGroupService _chatGroupService;
  final SSEService _sseService;
  final Ref _ref;
  StreamSubscription? _sseMessageSubscription;
  StreamSubscription? _sseConnectionStatusSubscription;

  SSEChatScreenNotifier(this.groupId, this._chatGroupService, this._ref)
      : _sseService = SSEService(groupId),
        super(SSEChatScreenState()) {
    _initialize();
  }

  Future<void> _initialize() async {
    state = state.copyWith(isLoadingMessages: true, clearErrorMessage: true);
    try {
      // Fetch initial messages via REST
      final initialMessages =
          await _chatGroupService.getMessagesForGroup(groupId, limit: 50);

      print(
          "SSEChatScreenNotifier: Loaded ${initialMessages.length} initial messages");
      for (var msg in initialMessages) {
        print(
            "SSEChatScreenNotifier: Initial message: ${msg.messageId} - ${msg.content}");
      }

      state =
          state.copyWith(messages: initialMessages, isLoadingMessages: false);
      print(
          "SSEChatScreenNotifier: State updated with initial messages. Total: ${state.messages.length}");

      // Connect SSE with retry logic
      await _connectSSEWithRetry();

      // Set up SSE listeners
      _sseConnectionStatusSubscription =
          _sseService.connectionStatus.listen((isConnected) {
        state = state.copyWith(isSSEConnected: isConnected);
        if (!isConnected) {
          state = state.copyWith(errorMessage: "SSE disconnected.");
        }
      });

      _sseMessageSubscription = _sseService.messages.listen((newMessage) {
        print(
            "SSEChatScreenNotifier: Received SSE message: ${newMessage.messageId} - ${newMessage.content}");
        // Add new message to the list, avoid duplicates
        if (!state.messages.any((m) => m.messageId == newMessage.messageId)) {
          print("SSEChatScreenNotifier: Adding new message to state");
          print(
              "SSEChatScreenNotifier: Current messages count: ${state.messages.length}");
          final updatedMessages = [...state.messages, newMessage];
          print(
              "SSEChatScreenNotifier: Updated messages count: ${updatedMessages.length}");
          state = state.copyWith(messages: updatedMessages);
          print(
              "SSEChatScreenNotifier: State updated with new message. Total messages: ${state.messages.length}");
        } else {
          print("SSEChatScreenNotifier: Message already exists, skipping");
        }
      }, onError: (error) {
        print("SSEChatScreenNotifier: SSE error: $error");
        state = state.copyWith(
            errorMessage: "SSE error: $error", isSSEConnected: false);
      });
    } catch (e, stack) {
      state =
          state.copyWith(isLoadingMessages: false, errorMessage: e.toString());
      print("SSEChatScreenNotifier Init Error: $e \n$stack");
    }
  }

  Future<void> _connectSSEWithRetry() async {
    int retryCount = 0;
    const maxRetries = 3;

    while (retryCount < maxRetries && !_sseService.isConnected) {
      try {
        print(
            "Attempting SSE connection (attempt ${retryCount + 1}/$maxRetries)...");
        await _sseService.connect();

        // Wait a bit for connection to establish
        await Future.delayed(const Duration(seconds: 2));

        if (_sseService.isConnected) {
          print("SSE connection established successfully.");
          break;
        }
      } catch (e) {
        print("SSE connection attempt ${retryCount + 1} failed: $e");
        retryCount++;
        if (retryCount < maxRetries) {
          await Future.delayed(const Duration(seconds: 2));
        }
      }
    }

    if (!_sseService.isConnected) {
      print("Failed to establish SSE connection after $maxRetries attempts.");
      state = state.copyWith(
          errorMessage:
              "Failed to establish real-time connection. Messages will still be sent via REST API.");
    }
  }

  Future<void> sendMessage(String content) async {
    print("SSEChatScreenNotifier: Attempting to send message: '$content'");
    state = state.copyWith(isSendingMessage: true, clearErrorMessage: true);
    try {
      print(
          "SSEChatScreenNotifier: Calling ChatGroupService.sendMessageToGroup...");
      // Send message via REST API (SSE connection is not required for sending)
      final sentMessage =
          await _chatGroupService.sendMessageToGroup(groupId, content);
      print(
          "SSEChatScreenNotifier: Message sent successfully: ${sentMessage.messageId}");
      state = state.copyWith(isSendingMessage: false);

      // If SSE is not connected, try to reconnect for receiving messages
      if (!_sseService.isConnected) {
        print(
            "SSE not connected, attempting to reconnect for receiving messages...");
        await _sseService.connect();
      }
    } catch (e) {
      print("SSEChatScreenNotifier: Error sending message: $e");
      state =
          state.copyWith(isSendingMessage: false, errorMessage: e.toString());
    }
  }

  Future<void> setMission(String missionText) async {
    state = state.copyWith(isSettingMission: true, clearErrorMessage: true);
    try {
      final missionData = MissionCreationData(missionText: missionText);
      final newMission =
          await _chatGroupService.setMissionForGroup(groupId, missionData);
      state =
          state.copyWith(isSettingMission: false, currentMission: newMission);
    } catch (e) {
      state =
          state.copyWith(isSettingMission: false, errorMessage: e.toString());
      rethrow;
    }
  }

  // Method to fetch older messages (pagination)
  Future<void> fetchOlderMessages() async {
    // Logic for pagination
  }

  @override
  void dispose() {
    print("Disposing SSEChatScreenNotifier for group $groupId");
    _sseMessageSubscription?.cancel();
    _sseConnectionStatusSubscription?.cancel();
    _sseService.dispose();
    super.dispose();
  }
}

// AutoDispose keeps the provider alive only while it's being listened to.
// .family allows passing the groupId to the provider.
final sseChatScreenNotifierProvider = StateNotifierProvider.autoDispose
    .family<SSEChatScreenNotifier, SSEChatScreenState, String>((ref, groupId) {
  final chatGroupService = ref.watch(chatGroupServiceProvider);
  return SSEChatScreenNotifier(groupId, chatGroupService, ref);
});
