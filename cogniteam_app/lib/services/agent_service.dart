import 'package:cogniteam_app/models/agent.dart';
import 'package:cogniteam_app/services/api_service.dart';
import 'package:dio/dio.dart';

class AgentService {
  final ApiService _apiService;

  AgentService(this._apiService);

  /// Fetches a list of all available system agents from the backend.
  Future<List<Agent>> getAllAgents() async {
    try {
      final response = await _apiService.get('/agents'); // Backend endpoint for listing agents

      if (response.statusCode == 200 && response.data != null) {
        final List<dynamic> agentListJson = response.data as List<dynamic>;
        return agentListJson.map((json) => Agent.fromJson(json as Map<String, dynamic>)).toList();
      } else {
        throw Exception('Failed to load agents: ${response.statusMessage} ${response.data}');
      }
    } on DioException catch (e) {
      final errorMsg = e.response?.data?['detail'] ?? e.message ?? "Failed to load agents";
      throw Exception('API Error loading agents: $errorMsg');
    } catch (e) {
      throw Exception('An unexpected error occurred while loading agents: $e');
    }
  }
}
```
