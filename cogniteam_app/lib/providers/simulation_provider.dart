import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cogniteam_app/services/simulation_service.dart';
import 'package:cogniteam_app/models/simulation.dart';
import 'package:cogniteam_app/services/user_service.dart';
import 'package:cogniteam_app/providers/auth_provider.dart';
import 'package:cogniteam_app/services/sse_service.dart';
import 'package:cogniteam_app/services/api_service.dart';

// SimulationServiceのプロバイダー
final simulationServiceProvider = Provider<SimulationService>((ref) {
  return SimulationService();
});

// UserServiceのプロバイダー
final userServiceProvider = Provider<UserService>((ref) {
  final apiService = ref.watch(apiServiceProvider).value;
  if (apiService == null) {
    throw Exception(
        "ApiService not yet available for UserService. Ensure ApiServiceProvider is loaded.");
  }
  return UserService(apiService);
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

// 参加者のユーザー情報を取得するプロバイダー
final participantsInfoProvider =
    FutureProvider.family<List<Map<String, dynamic>>, List<String>>(
        (ref, userIds) async {
  final userService = ref.watch(userServiceProvider);
  final participants = <Map<String, dynamic>>[];

  for (final userId in userIds) {
    try {
      final user = await userService.getUserById(userId);
      if (user != null) {
        participants.add({
          'userId': userId,
          'displayName': user.name,
          'email': user.email,
        });
      } else {
        // ユーザーが見つからない場合は、userIdをそのまま使用
        participants.add({
          'userId': userId,
          'displayName': userId,
          'email': 'Unknown',
        });
      }
    } catch (e) {
      // エラーが発生した場合は、userIdをそのまま使用
      participants.add({
        'userId': userId,
        'displayName': userId,
        'email': 'Error',
      });
    }
  }

  return participants;
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

// シミュレーション通知の状態
class SimulationNotificationState {
  final List<Map<String, dynamic>> notifications;
  final bool isConnected;
  final String? errorMessage;

  SimulationNotificationState({
    this.notifications = const [],
    this.isConnected = false,
    this.errorMessage,
  });

  SimulationNotificationState copyWith({
    List<Map<String, dynamic>>? notifications,
    bool? isConnected,
    String? errorMessage,
    bool clearErrorMessage = false,
  }) {
    return SimulationNotificationState(
      notifications: notifications ?? this.notifications,
      isConnected: isConnected ?? this.isConnected,
      errorMessage:
          clearErrorMessage ? null : errorMessage ?? this.errorMessage,
    );
  }
}

// シミュレーション通知のNotifier
class SimulationNotificationNotifier
    extends StateNotifier<SimulationNotificationState> {
  SimulationSSEService? _sseService;
  StreamSubscription? _notificationSubscription;
  StreamSubscription? _connectionStatusSubscription;

  SimulationNotificationNotifier() : super(SimulationNotificationState()) {
    _initializeSSE();
  }

  void _initializeSSE() {
    print("SimulationNotificationNotifier: Starting initialization");
    _sseService = SimulationSSEService();

    // Listen to connection status
    _connectionStatusSubscription =
        _sseService!.connectionStatusStream.listen((isConnected) {
      print(
          "SimulationNotificationNotifier: Connection status changed to: $isConnected");
      state = state.copyWith(isConnected: isConnected);
      if (!isConnected) {
        state = state.copyWith(errorMessage: "シミュレーション通知の接続が切断されました");
      } else {
        state = state.copyWith(errorMessage: null);
      }
    });

    // Listen to notifications
    _notificationSubscription =
        _sseService!.notificationStream.listen((notification) {
      print(
          "SimulationNotificationNotifier: Received notification: $notification");

      // 新しい通知をリストの先頭に追加
      final updatedNotifications = [notification, ...state.notifications];

      // 最大10件まで保持
      if (updatedNotifications.length > 10) {
        updatedNotifications.removeRange(10, updatedNotifications.length);
      }

      state = state.copyWith(notifications: updatedNotifications);
    });

    print(
        "SimulationNotificationNotifier: Attempting to connect to SSE service");
    _sseService!.connect().then((_) {
      print("SimulationNotificationNotifier: SSE connection attempt completed");
    }).catchError((error) {
      print("SimulationNotificationNotifier: SSE connection failed: $error");
      state = state.copyWith(errorMessage: "シミュレーション通知の接続に失敗しました: $error");
    });

    print(
        "SimulationNotificationNotifier: Initialization completed successfully");
  }

  void clearNotifications() {
    state = state.copyWith(notifications: []);
  }

  void removeNotification(int index) {
    if (index >= 0 && index < state.notifications.length) {
      final updatedNotifications =
          List<Map<String, dynamic>>.from(state.notifications);
      updatedNotifications.removeAt(index);
      state = state.copyWith(notifications: updatedNotifications);
    }
  }

  @override
  void dispose() {
    _notificationSubscription?.cancel();
    _connectionStatusSubscription?.cancel();
    _sseService?.dispose();
    super.dispose();
  }
}

// シミュレーション通知のプロバイダー
final simulationNotificationProvider = StateNotifierProvider<
    SimulationNotificationNotifier, SimulationNotificationState>((ref) {
  return SimulationNotificationNotifier();
});
