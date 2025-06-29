import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cogniteam_app/services/simulation_service.dart';
import 'package:cogniteam_app/models/simulation.dart';

// SimulationServiceのプロバイダー
final simulationServiceProvider = Provider<SimulationService>((ref) {
  return SimulationService();
});

// シミュレーション作成の状態管理
final simulationCreationProvider =
    StateNotifierProvider<SimulationCreationNotifier, AsyncValue<Simulation?>>(
        (ref) {
  final simulationService = ref.watch(simulationServiceProvider);
  return SimulationCreationNotifier(simulationService);
});

// シミュレーション一覧の状態管理
final simulationsListProvider = FutureProvider<SimulationList>((ref) async {
  final simulationService = ref.watch(simulationServiceProvider);
  return await simulationService.getSimulations();
});

// 特定のシミュレーション詳細の状態管理
final simulationDetailProvider =
    FutureProvider.family<Simulation?, String>((ref, simulationId) async {
  final simulationService = ref.watch(simulationServiceProvider);
  return await simulationService.getSimulation(simulationId);
});

// シミュレーション削除の状態管理
final simulationDeletionProvider =
    StateNotifierProvider<SimulationDeletionNotifier, AsyncValue<bool>>((ref) {
  final simulationService = ref.watch(simulationServiceProvider);
  return SimulationDeletionNotifier(simulationService);
});

// シミュレーション再実行の状態管理
final simulationRerunProvider =
    StateNotifierProvider<SimulationRerunNotifier, AsyncValue<Simulation?>>(
        (ref) {
  final simulationService = ref.watch(simulationServiceProvider);
  return SimulationRerunNotifier(simulationService);
});

// シミュレーション作成のNotifier
class SimulationCreationNotifier
    extends StateNotifier<AsyncValue<Simulation?>> {
  final SimulationService _simulationService;

  SimulationCreationNotifier(this._simulationService)
      : super(const AsyncValue.data(null));

  Future<void> createSimulation({
    required String simulationName,
    required String instruction,
    required List<String> participantUserIds,
  }) async {
    state = const AsyncValue.loading();

    try {
      final simulation = await _simulationService.createSimulation(
        simulationName: simulationName,
        instruction: instruction,
        participantUserIds: participantUserIds,
      );
      state = AsyncValue.data(simulation);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  void reset() {
    state = const AsyncValue.data(null);
  }
}

// シミュレーション削除のNotifier
class SimulationDeletionNotifier extends StateNotifier<AsyncValue<bool>> {
  final SimulationService _simulationService;

  SimulationDeletionNotifier(this._simulationService)
      : super(const AsyncValue.data(false));

  Future<void> deleteSimulation(String simulationId) async {
    state = const AsyncValue.loading();

    try {
      final success = await _simulationService.deleteSimulation(simulationId);
      state = AsyncValue.data(success);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  void reset() {
    state = const AsyncValue.data(false);
  }
}

// シミュレーション再実行のNotifier
class SimulationRerunNotifier extends StateNotifier<AsyncValue<Simulation?>> {
  final SimulationService _simulationService;

  SimulationRerunNotifier(this._simulationService)
      : super(const AsyncValue.data(null));

  Future<void> rerunSimulation(String simulationId) async {
    state = const AsyncValue.loading();

    try {
      final simulation = await _simulationService.rerunSimulation(simulationId);
      state = AsyncValue.data(simulation);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  void reset() {
    state = const AsyncValue.data(null);
  }
}
