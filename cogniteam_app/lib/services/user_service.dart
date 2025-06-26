import 'package:cogniteam_app/models/user.dart'; // AppUser and UserUpdate (if we make a specific model for FE)
import 'package:cogniteam_app/services/api_service.dart';
import 'package:dio/dio.dart';

// UserUpdate model for frontend (optional, can use Map<String, dynamic> directly)
// This would mirror backend's UserUpdate Pydantic model for type safety.
class UserProfileUpdateData {
  final String? name;
  final String? sex;
  final DateTime? birthDate;
  final String? mbti;
  final String? company;
  final String? division;
  final String? department;
  final String? section;
  final String? role;

  UserProfileUpdateData({
    this.name,
    this.sex,
    this.birthDate,
    this.mbti,
    this.company,
    this.division,
    this.department,
    this.section,
    this.role,
  });

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = {};
    if (name != null) data['name'] = name;
    if (sex != null) data['sex'] = sex;
    if (birthDate != null)
      data['birth_date'] = birthDate!.toIso8601String().split('T').first;
    if (mbti != null) data['mbti'] = mbti;
    if (company != null) data['company'] = company;
    if (division != null) data['division'] = division;
    if (department != null) data['department'] = department;
    if (section != null) data['section'] = section;
    if (role != null) data['role'] = role;
    return data;
  }
}

class UserService {
  final ApiService _apiService;

  UserService(this._apiService);

  /// Updates the current user's profile on the backend.
  /// Takes a UserProfileUpdateData object (or Map<String, dynamic>) with the fields to update.
  Future<AppUser> updateUserProfile(UserProfileUpdateData updateData) async {
    try {
      final response = await _apiService.put(
        '/users/me', // Backend endpoint for updating user profile
        data: updateData.toJson(),
      );

      if (response.statusCode == 200 && response.data != null) {
        return AppUser.fromJson(response.data as Map<String, dynamic>);
      } else {
        throw Exception(
            'Failed to update user profile: ${response.statusMessage} ${response.data}');
      }
    } on DioException catch (e) {
      final errorMsg =
          e.response?.data?['detail'] ?? e.message ?? "Profile update failed";
      throw Exception('API Error updating profile: $errorMsg');
    } catch (e) {
      throw Exception(
          'An unexpected error occurred while updating profile: $e');
    }
  }

  /// Fetches the current user's generated agent prompt from the backend.
  Future<String?> getUserAgentPrompt() async {
    try {
      final response =
          await _apiService.get('/users/me/prompt'); // Backend endpoint

      if (response.statusCode == 200 && response.data != null) {
        final responseData = response.data as Map<String, dynamic>;
        return responseData['prompt'] as String?; // Prompt can be null
      } else {
        throw Exception(
            'Failed to get user prompt: ${response.statusMessage} ${response.data}');
      }
    } on DioException catch (e) {
      final errorMsg =
          e.response?.data?['detail'] ?? e.message ?? "Failed to get prompt";
      throw Exception('API Error getting prompt: $errorMsg');
    } catch (e) {
      throw Exception('An unexpected error occurred while getting prompt: $e');
    }
  }

  /// Fetches all users from the backend (excluding the current user).
  Future<List<AppUser>> getAllUsers() async {
    try {
      final response = await _apiService.get('/users/');

      if (response.statusCode == 200 && response.data != null) {
        final List<dynamic> userListJson = response.data as List<dynamic>;
        return userListJson
            .map((json) => AppUser.fromJson(json as Map<String, dynamic>))
            .toList();
      } else {
        throw Exception(
            'Failed to load users: ${response.statusMessage} ${response.data}');
      }
    } on DioException catch (e) {
      final errorMsg =
          e.response?.data?['detail'] ?? e.message ?? "Failed to load users";
      throw Exception('API Error loading users: $errorMsg');
    } catch (e) {
      throw Exception('An unexpected error occurred while loading users: $e');
    }
  }
}
