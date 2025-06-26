import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cogniteam_app/models/message.dart';
import 'package:cogniteam_app/models/mission.dart';
import 'package:cogniteam_app/services/chat_group_service.dart';
import 'package:cogniteam_app/services/websocket_service.dart';
import 'package:cogniteam_app/providers/auth_provider.dart'; // For chatGroupServiceProvider

// Represents the state of a single chat screen
class ChatScreenState {
  final List<Message> messages;
  final Mission? currentMission;
  final bool isLoadingMessages;
  final bool isSendingMessage;
  final bool isSettingMission;
  final bool isWebSocketConnected;
  final String? errorMessage;

  ChatScreenState({
    this.messages = const [],
    this.currentMission,
    this.isLoadingMessages = true,
    this.isSendingMessage = false,
    this.isSettingMission = false,
    this.isWebSocketConnected = false,
    this.errorMessage,
  });

  ChatScreenState copyWith({
    List<Message>? messages,
    Mission? currentMission,
    bool? isLoadingMessages,
    bool? isSendingMessage,
    bool? isSettingMission,
    bool? isWebSocketConnected,
    String? errorMessage,
    bool clearErrorMessage = false,
  }) {
    return ChatScreenState(
      messages: messages ?? this.messages,
      currentMission: currentMission ?? this.currentMission,
      isLoadingMessages: isLoadingMessages ?? this.isLoadingMessages,
      isSendingMessage: isSendingMessage ?? this.isSendingMessage,
      isSettingMission: isSettingMission ?? this.isSettingMission,
      isWebSocketConnected: isWebSocketConnected ?? this.isWebSocketConnected,
      errorMessage:
          clearErrorMessage ? null : errorMessage ?? this.errorMessage,
    );
  }
}

class ChatScreenNotifier extends StateNotifier<ChatScreenState> {
  final String groupId;
  final ChatGroupService _chatGroupService;
  final WebSocketService _webSocketService;
  final Ref _ref;
  StreamSubscription? _wsMessageSubscription;
  StreamSubscription? _wsConnectionStatusSubscription;

  ChatScreenNotifier(this.groupId, this._chatGroupService, this._ref)
      : _webSocketService = WebSocketService(
            groupId), // Each notifier instance gets its own WebSocketService
        super(ChatScreenState()) {
    _initialize();
  }

  Future<void> _initialize() async {
    state = state.copyWith(isLoadingMessages: true, clearErrorMessage: true);
    try {
      // Fetch initial messages via REST
      final initialMessages =
          await _chatGroupService.getMessagesForGroup(groupId, limit: 50);
      // Fetch current mission (if any) - this needs a method in ChatGroupService
      // final currentMission = await _chatGroupService.getActiveMissionForGroup(groupId);
      // For now, mission fetching is not implemented in ChatGroupService on frontend.

      state =
          state.copyWith(messages: initialMessages, isLoadingMessages: false);

      // Connect WebSocket
      await _webSocketService.connect();
      _wsConnectionStatusSubscription =
          _webSocketService.connectionStatus.listen((isConnected) {
        state = state.copyWith(isWebSocketConnected: isConnected);
        if (!isConnected) {
          // Handle disconnection, maybe try to reconnect or show error
          state = state.copyWith(errorMessage: "WebSocket disconnected.");
        }
      });

      _wsMessageSubscription = _webSocketService.messages.listen((newMessage) {
        // Add new message to the list, avoid duplicates if any race condition
        if (!state.messages.any((m) => m.messageId == newMessage.messageId)) {
          state = state.copyWith(messages: [...state.messages, newMessage]);
        }
      }, onError: (error) {
        state = state.copyWith(
            errorMessage: "WebSocket error: $error",
            isWebSocketConnected: false);
      });
    } catch (e, stack) {
      state =
          state.copyWith(isLoadingMessages: false, errorMessage: e.toString());
      print("ChatScreenNotifier Init Error: $e \n$stack");
    }
  }

  Future<void> sendMessage(String content) async {
    if (!_webSocketService.isConnected) {
      state = state.copyWith(
          errorMessage: "Not connected to chat. Please try again.");
      // Attempt to reconnect or prompt user
      await _webSocketService.connect();
      return;
    }
    // Optimistically add message to UI? Or wait for WebSocket echo?
    // For now, rely on WebSocket echo.
    state = state.copyWith(isSendingMessage: true, clearErrorMessage: true);
    try {
      _webSocketService.sendMessage(content);
      // Message is sent; backend will broadcast it back including to sender.
      // No need to manually add to state.messages here if relying on broadcast.
      state = state.copyWith(isSendingMessage: false);
    } catch (e) {
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

  // Method to fetch older messages (pagination) - TBD
  Future<void> fetchOlderMessages() async {
    // Logic for pagination
  }

  @override
  void dispose() {
    print("Disposing ChatScreenNotifier for group $groupId");
    _wsMessageSubscription?.cancel();
    _wsConnectionStatusSubscription?.cancel();
    _webSocketService
        .dispose(); // Important to close WebSocket connection and stream controllers
    super.dispose();
  }
}

// AutoDispose keeps the provider alive only while it's being listened to.
// .family allows passing the groupId to the provider.
final chatScreenNotifierProvider = StateNotifierProvider.autoDispose
    .family<ChatScreenNotifier, ChatScreenState, String>((ref, groupId) {
  final chatGroupService = ref.watch(chatGroupServiceProvider);
  // WebSocketService is instantiated directly by ChatScreenNotifier.
  return ChatScreenNotifier(groupId, chatGroupService, ref);
});
