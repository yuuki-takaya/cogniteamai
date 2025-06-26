import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cogniteam_app/models/chat_group.dart';
import 'package:cogniteam_app/services/chat_group_service.dart';
import 'package:cogniteam_app/providers/auth_provider.dart'; // For chatGroupServiceProvider & appUserProvider

// FutureProvider to fetch the current user's chat groups
final myChatGroupsProvider = FutureProvider<List<ChatGroup>>((ref) async {
  // This provider depends on the user being logged in.
  // If appUserProvider.value is null, it means no user is logged in, so no groups can be fetched.
  // However, this FutureProvider will attempt to run if watched.
  // Guard against calling service if user is not logged in.
  final appUser = ref.watch(appUserProvider);
  if (appUser == null) {
    // Not logged in, or user data not loaded yet. Return empty or throw specific error.
    // Throwing an error might be better to indicate that the operation cannot be performed.
    // Or, the UI layer should only watch this provider if the user is logged in.
    // For now, let's return an empty list if no user.
    print(
        "myChatGroupsProvider: No authenticated user found. Returning empty list.");
    return [];
  }

  final chatGroupService = ref.watch(chatGroupServiceProvider);
  return chatGroupService.getMyChatGroups();
});

// StateNotifier for managing the creation of a new chat group
// This could also be a simple Future method in a widget if state persistence across widgets isn't complex.
// Using a StateNotifier can help manage loading/error states for the creation process.
class ChatGroupCreationNotifier extends StateNotifier<AsyncValue<ChatGroup?>> {
  final ChatGroupService _chatGroupService;
  final Ref _ref;

  ChatGroupCreationNotifier(this._chatGroupService, this._ref)
      : super(const AsyncValue.data(null));

  Future<void> createChatGroup(String groupName, List<String> agentIds) async {
    state = const AsyncValue.loading();
    try {
      final creationData =
          ChatGroupCreationData(groupName: groupName, agentIds: agentIds);
      final newGroup = await _chatGroupService.createChatGroup(creationData);
      state = AsyncValue.data(newGroup);
      // Successfully created, now invalidate myChatGroupsProvider to refresh the list
      _ref.invalidate(myChatGroupsProvider);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      // Rethrow so UI can catch it for specific error messages
      rethrow;
    }
  }

  // Reset state, e.g., after navigating away or closing a dialog
  void resetState() {
    state = const AsyncValue.data(null);
  }
}

final chatGroupCreationNotifierProvider =
    StateNotifierProvider<ChatGroupCreationNotifier, AsyncValue<ChatGroup?>>(
        (ref) {
  final chatGroupService = ref.watch(chatGroupServiceProvider);
  return ChatGroupCreationNotifier(chatGroupService, ref);
});
