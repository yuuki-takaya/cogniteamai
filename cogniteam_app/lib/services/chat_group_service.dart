import 'package:cogniteam_app/models/chat_group.dart';
import 'package:cogniteam_app/models/message.dart'; // Import Message model
import 'package:cogniteam_app/models/mission.dart'; // Import Mission models
import 'package:cogniteam_app/services/api_service.dart';
import 'package:dio/dio.dart';

class ChatGroupService {
  final ApiService _apiService;

  ChatGroupService(this._apiService);

  /// Creates a new chat group on the backend.
  Future<ChatGroup> createChatGroup(ChatGroupCreationData creationData) async {
    try {
      final response = await _apiService.post(
        '/chat_groups/', // Backend endpoint for creating a chat group
        data: creationData.toJson(),
      );

      if (response.statusCode == 201 && response.data != null) {
        // 201 Created
        return ChatGroup.fromJson(response.data as Map<String, dynamic>);
      } else {
        throw Exception(
            'Failed to create chat group: ${response.statusMessage} ${response.data}');
      }
    } on DioException catch (e) {
      final errorMsg = e.response?.data?['detail'] ??
          e.message ??
          "Chat group creation failed";
      throw Exception('API Error creating chat group: $errorMsg');
    } catch (e) {
      throw Exception(
          'An unexpected error occurred while creating chat group: $e');
    }
  }

  /// Fetches a list of chat groups the current user is a member of.
  Future<List<ChatGroup>> getMyChatGroups() async {
    try {
      final response = await _apiService.get(
          '/chat_groups/'); // Backend endpoint for listing user's chat groups

      if (response.statusCode == 200 && response.data != null) {
        final List<dynamic> groupListJson = response.data as List<dynamic>;
        return groupListJson
            .map((json) => ChatGroup.fromJson(json as Map<String, dynamic>))
            .toList();
      } else {
        throw Exception(
            'Failed to load user chat groups: ${response.statusMessage} ${response.data}');
      }
    } on DioException catch (e) {
      final errorMsg = e.response?.data?['detail'] ??
          e.message ??
          "Failed to load chat groups";
      throw Exception('API Error loading chat groups: $errorMsg');
    } catch (e) {
      throw Exception(
          'An unexpected error occurred while loading chat groups: $e');
    }
  }

  /// Fetches details of a specific chat group by its ID.
  Future<ChatGroup> getChatGroupDetails(String groupId) async {
    try {
      final response = await _apiService.get('/chat_groups/$groupId');
      if (response.statusCode == 200 && response.data != null) {
        return ChatGroup.fromJson(response.data as Map<String, dynamic>);
      } else {
        throw Exception(
            'Failed to load chat group details: ${response.statusMessage} ${response.data}');
      }
    } on DioException catch (e) {
      final errorMsg = e.response?.data?['detail'] ??
          e.message ??
          "Failed to load chat group details";
      throw Exception('API Error loading chat group details: $errorMsg');
    } catch (e) {
      throw Exception(
          'An unexpected error occurred loading chat group details: $e');
    }
  }

  // Messages related methods will be here or in a separate MessageService
  Future<List<Message>> getMessagesForGroup(String groupId,
      {int limit = 50}) async {
    try {
      final response = await _apiService.get(
        '/chat_groups/$groupId/messages',
        queryParameters: {'limit': limit},
      );
      if (response.statusCode == 200 && response.data != null) {
        final List<dynamic> messageListJson = response.data as List<dynamic>;
        return messageListJson
            .map((json) => Message.fromJson(json as Map<String, dynamic>))
            .toList();
      } else {
        throw Exception(
            'Failed to load messages for group $groupId: ${response.statusMessage} ${response.data}');
      }
    } on DioException catch (e) {
      final errorMsg =
          e.response?.data?['detail'] ?? e.message ?? "Failed to load messages";
      throw Exception(
          'API Error loading messages for group $groupId: $errorMsg');
    } catch (e) {
      throw Exception(
          'An unexpected error occurred loading messages for group $groupId: $e');
    }
  }

  /// Sets or updates the mission for a chat group.
  Future<Mission> setMissionForGroup(
      String groupId, MissionCreationData missionData) async {
    try {
      final response = await _apiService.post(
        '/chat_groups/$groupId/mission',
        data: missionData.toJson(),
      );
      if (response.statusCode == 200 && response.data != null) {
        // Backend returns 200 for POST on this route
        return Mission.fromJson(response.data as Map<String, dynamic>);
      } else {
        throw Exception(
            'Failed to set mission for group $groupId: ${response.statusMessage} ${response.data}');
      }
    } on DioException catch (e) {
      final errorMsg =
          e.response?.data?['detail'] ?? e.message ?? "Failed to set mission";
      throw Exception(
          'API Error setting mission for group $groupId: $errorMsg');
    } catch (e) {
      throw Exception(
          'An unexpected error occurred setting mission for group $groupId: $e');
    }
  }
}
