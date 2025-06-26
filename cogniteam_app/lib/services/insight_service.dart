import 'package:cogniteam_app/models/insight.dart';
import 'package:cogniteam_app/services/api_service.dart';
import 'package:dio/dio.dart';

class InsightService {
  final ApiService _apiService;

  InsightService(this._apiService);

  /// Fetches insights for a specific chat group from the backend.
  /// - `groupId`: The ID of the chat group.
  /// - `insightType`: Optional. The type of insight to fetch (e.g., "summary", "sentiment"). Defaults to "summary".
  Future<Insight> getInsightsForGroup(String groupId, {String insightType = "summary"}) async {
    try {
      final response = await _apiService.get(
        '/insights/$groupId',
        queryParameters: {'insight_type': insightType},
      );

      if (response.statusCode == 200 && response.data != null) {
        return Insight.fromJson(response.data as Map<String, dynamic>);
      } else {
        throw Exception('Failed to load insights for group $groupId (type: $insightType): ${response.statusMessage} ${response.data}');
      }
    } on DioException catch (e) {
      final errorMsg = e.response?.data?['detail'] ?? e.message ?? "Failed to load insights";
      throw Exception('API Error loading insights for group $groupId (type: $insightType): $errorMsg');
    } catch (e) {
      throw Exception('An unexpected error occurred while loading insights for group $groupId (type: $insightType): $e');
    }
  }
}
```
