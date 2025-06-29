import 'package:cogniteam_app/services/api_service.dart';
import 'package:cogniteam_app/models/simulation.dart';

class SimulationService {
  ApiService? _apiService;

  SimulationService();

  Future<ApiService> get _apiServiceInstance async {
    _apiService ??= await ApiService.getInstance();
    return _apiService!;
  }

  /// 新しいシミュレーションを作成
  Future<Simulation> createSimulation({
    required String simulationName,
    required String instruction,
    required List<String> participantUserIds,
  }) async {
    try {
      final apiService = await _apiServiceInstance;
      final response = await apiService.post(
        '/simulations/',
        data: {
          'simulation_name': simulationName,
          'instruction': instruction,
          'participant_user_ids': participantUserIds,
        },
      );

      if (response.statusCode == 200 && response.data != null) {
        return Simulation.fromJson(response.data as Map<String, dynamic>);
      } else {
        throw Exception(
            'Failed to create simulation: ${response.statusMessage}');
      }
    } catch (e) {
      throw Exception('Error creating simulation: $e');
    }
  }

  /// シミュレーション一覧を取得
  Future<SimulationList> getSimulations({
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      final apiService = await _apiServiceInstance;
      final response = await apiService.get(
        '/simulations/?limit=$limit&offset=$offset',
      );

      if (response.statusCode == 200 && response.data != null) {
        return SimulationList.fromJson(response.data as Map<String, dynamic>);
      } else {
        throw Exception('Failed to get simulations: ${response.statusMessage}');
      }
    } catch (e) {
      throw Exception('Error getting simulations: $e');
    }
  }

  /// 特定のシミュレーション詳細を取得
  Future<Simulation?> getSimulation(String simulationId) async {
    try {
      final apiService = await _apiServiceInstance;
      final response = await apiService.get('/simulations/$simulationId');

      if (response.statusCode == 200 && response.data != null) {
        return Simulation.fromJson(response.data as Map<String, dynamic>);
      } else if (response.statusCode == 404) {
        return null; // シミュレーションが見つからない
      } else {
        throw Exception('Failed to get simulation: ${response.statusMessage}');
      }
    } catch (e) {
      throw Exception('Error getting simulation: $e');
    }
  }

  /// シミュレーションを削除
  Future<bool> deleteSimulation(String simulationId) async {
    try {
      final apiService = await _apiServiceInstance;
      final response = await apiService.delete('/simulations/$simulationId');

      if (response.statusCode == 200) {
        return true;
      } else {
        throw Exception(
            'Failed to delete simulation: ${response.statusMessage}');
      }
    } catch (e) {
      throw Exception('Error deleting simulation: $e');
    }
  }

  /// シミュレーションを再実行
  Future<Simulation> rerunSimulation(String simulationId) async {
    try {
      final apiService = await _apiServiceInstance;
      final response =
          await apiService.post('/simulations/$simulationId/rerun');

      if (response.statusCode == 200 && response.data != null) {
        return Simulation.fromJson(response.data as Map<String, dynamic>);
      } else {
        throw Exception(
            'Failed to rerun simulation: ${response.statusMessage}');
      }
    } catch (e) {
      throw Exception('Error rerunning simulation: $e');
    }
  }
}
