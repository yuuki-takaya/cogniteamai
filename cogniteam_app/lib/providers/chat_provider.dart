import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cogniteam_app/models/message.dart';
import 'package:cogniteam_app/models/mission.dart';
import 'package:cogniteam_app/services/chat_group_service.dart';
import 'package:cogniteam_app/providers/auth_provider.dart'; // For chatGroupServiceProvider

// Represents the state of a single chat screen
class ChatScreenState {
  final List<Message> messages;
  final Mission? currentMission;
  final bool isLoadingMessages;
  final bool isSendingMessage;
  final bool isSettingMission;
  final String? errorMessage;

  ChatScreenState({
    this.messages = const [],
    this.currentMission,
    this.isLoadingMessages = true,
    this.isSendingMessage = false,
    this.isSettingMission = false,
    this.errorMessage,
  });

  ChatScreenState copyWith({
    List<Message>? messages,
    Mission? currentMission,
    bool? isLoadingMessages,
    bool? isSendingMessage,
    bool? isSettingMission,
    String? errorMessage,
    bool clearErrorMessage = false,
  }) {
    return ChatScreenState(
      messages: messages ?? this.messages,
      currentMission: currentMission ?? this.currentMission,
      isLoadingMessages: isLoadingMessages ?? this.isLoadingMessages,
      isSendingMessage: isSendingMessage ?? this.isSendingMessage,
      isSettingMission: isSettingMission ?? this.isSettingMission,
      errorMessage:
          clearErrorMessage ? null : errorMessage ?? this.errorMessage,
    );
  }
}

class ChatScreenNotifier extends StateNotifier<ChatScreenState> {
  final String groupId;
  final ChatGroupService _chatGroupService;
  final Ref _ref;

  ChatScreenNotifier(this.groupId, this._chatGroupService, this._ref)
      : super(ChatScreenState()) {
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
    } catch (e, stack) {
      state =
          state.copyWith(isLoadingMessages: false, errorMessage: e.toString());
      print("ChatScreenNotifier Init Error: $e \n$stack");
    }
  }

  Future<void> sendMessage(String content) async {
    state = state.copyWith(isSendingMessage: true, clearErrorMessage: true);
    try {
      // Send message via REST API
      final newMessage =
          await _chatGroupService.sendMessageToGroup(groupId, content);

      // Add the new message to the state
      state = state.copyWith(
          messages: [...state.messages, newMessage], isSendingMessage: false);
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

  // Method to refresh messages
  Future<void> refreshMessages() async {
    state = state.copyWith(isLoadingMessages: true, clearErrorMessage: true);
    try {
      final messages =
          await _chatGroupService.getMessagesForGroup(groupId, limit: 50);
      state = state.copyWith(messages: messages, isLoadingMessages: false);
    } catch (e) {
      state =
          state.copyWith(isLoadingMessages: false, errorMessage: e.toString());
    }
  }

  @override
  void dispose() {
    print("Disposing ChatScreenNotifier for group $groupId");
    super.dispose();
  }
}

// AutoDispose keeps the provider alive only while it's being listened to.
// .family allows passing the groupId to the provider.
final chatScreenNotifierProvider = StateNotifierProvider.autoDispose
    .family<ChatScreenNotifier, ChatScreenState, String>((ref, groupId) {
  final chatGroupService = ref.watch(chatGroupServiceProvider);
  return ChatScreenNotifier(groupId, chatGroupService, ref);
});
