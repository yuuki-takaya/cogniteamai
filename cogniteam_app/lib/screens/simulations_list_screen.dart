import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cogniteam_app/providers/simulation_provider.dart';
import 'package:cogniteam_app/providers/auth_provider.dart';
import 'package:cogniteam_app/models/simulation.dart' as sim;
import 'package:go_router/go_router.dart';
import 'package:cogniteam_app/navigation/app_router.dart';

class SimulationsListScreen extends ConsumerStatefulWidget {
  const SimulationsListScreen({super.key});

  @override
  ConsumerState<SimulationsListScreen> createState() =>
      _SimulationsListScreenState();
}

class _SimulationsListScreenState extends ConsumerState<SimulationsListScreen> {
  @override
  Widget build(BuildContext context) {
    final simulationsAsync = ref.watch(simulationsListProvider);
    final notificationState = ref.watch(simulationNotificationProvider);

    print(
        "SimulationsListScreen: Building with notification state - connected: ${notificationState.isConnected}, notifications: ${notificationState.notifications.length}, error: ${notificationState.errorMessage}");

    return Scaffold(
      appBar: AppBar(
        title: const Text('シミュレーション一覧'),
        actions: [
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.notifications),
                onPressed: () {
                  _showNotificationsDialog(context, notificationState);
                },
              ),
              if (notificationState.notifications.isNotEmpty)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    child: Text(
                      '${notificationState.notifications.length}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              context.push('/simulations/create');
            },
            tooltip: '新しいシミュレーションを作成',
          ),
        ],
      ),
      body: simulationsAsync.when(
        data: (simulations) {
          if (simulations.simulations.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.science,
                    size: 64,
                    color: Colors.grey,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'シミュレーションがありません',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    '新しいシミュレーションを作成してください',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(simulationsListProvider);
            },
            child: ListView.builder(
              itemCount: simulations.simulations.length,
              itemBuilder: (context, index) {
                final simulation = simulations.simulations[index];
                return _SimulationCard(
                  simulation: simulation,
                  onTap: () {
                    print(
                        "SimulationsListScreen: Navigating to simulation detail with ID: ${simulation.simulationId}");
                    final path = '/simulations/${simulation.simulationId}';
                    print("SimulationsListScreen: Navigation path: $path");
                    context.push(path);
                  },
                );
              },
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error,
                size: 64,
                color: Colors.red,
              ),
              const SizedBox(height: 16),
              Text(
                'エラーが発生しました',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                error.toString(),
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  ref.invalidate(simulationsListProvider);
                },
                child: const Text('再試行'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showNotificationsDialog(BuildContext context, notificationState) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('シミュレーション通知'),
          content: SizedBox(
            width: double.maxFinite,
            child: notificationState.notifications.isEmpty
                ? const Text('通知はありません')
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: notificationState.notifications.length,
                    itemBuilder: (context, index) {
                      final notification =
                          notificationState.notifications[index];
                      return _NotificationCard(
                        notification: notification,
                        onDismiss: () {
                          ref
                              .read(simulationNotificationProvider.notifier)
                              .removeNotification(index);
                          Navigator.of(context).pop();
                        },
                      );
                    },
                  ),
          ),
          actions: [
            if (notificationState.notifications.isNotEmpty)
              TextButton(
                onPressed: () {
                  ref
                      .read(simulationNotificationProvider.notifier)
                      .clearNotifications();
                  Navigator.of(context).pop();
                },
                child: const Text('すべて削除'),
              ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('閉じる'),
            ),
          ],
        );
      },
    );
  }
}

class _SimulationCard extends ConsumerWidget {
  final sim.Simulation simulation;
  final VoidCallback onTap;

  const _SimulationCard({
    required this.simulation,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      simulation.simulationName,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ),
                  _StatusChip(status: simulation.status),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                simulation.instruction,
                style: Theme.of(context).textTheme.bodyMedium,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.people,
                    size: 16,
                    color: Colors.grey[600],
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${simulation.participantUserIds.length}人の参加者',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey[600],
                        ),
                  ),
                  const Spacer(),
                  Text(
                    _formatDate(simulation.createdAt),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey[600],
                        ),
                  ),
                ],
              ),
              if (simulation.status == 'completed' &&
                  simulation.resultSummary != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green[50],
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.check_circle,
                        size: 16,
                        color: Colors.green[700],
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          'シミュレーション完了',
                          style: TextStyle(
                            color: Colors.green[700],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (simulation.status == 'failed' &&
                  simulation.errorMessage != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.error,
                        size: 16,
                        color: Colors.red[700],
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          'エラー: ${simulation.errorMessage}',
                          style: TextStyle(
                            color: Colors.red[700],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 0) {
      return '${difference.inDays}日前';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}時間前';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}分前';
    } else {
      return '今';
    }
  }
}

class _StatusChip extends StatelessWidget {
  final String status;

  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    String text;
    IconData icon;

    switch (status) {
      case 'pending':
        color = Colors.orange;
        text = '待機中';
        icon = Icons.schedule;
        break;
      case 'running':
        color = Colors.blue;
        text = '実行中';
        icon = Icons.play_arrow;
        break;
      case 'completed':
        color = Colors.green;
        text = '完了';
        icon = Icons.check_circle;
        break;
      case 'failed':
        color = Colors.red;
        text = '失敗';
        icon = Icons.error;
        break;
      case 'cancelled':
        color = Colors.grey;
        text = 'キャンセル';
        icon = Icons.cancel;
        break;
      default:
        color = Colors.grey;
        text = status;
        icon = Icons.help;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 12,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  final Map<String, dynamic> notification;
  final VoidCallback onDismiss;

  const _NotificationCard({
    required this.notification,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final type = notification['type'] as String?;
    final message = notification['message'] as String?;
    final simulationName = notification['simulation_name'] as String?;
    final timestamp = notification['timestamp'] as String?;

    Color color;
    IconData icon;
    String title;

    switch (type) {
      case 'simulation_completed':
        color = Colors.green;
        icon = Icons.check_circle;
        title = 'シミュレーション完了';
        break;
      case 'simulation_failed':
        color = Colors.red;
        icon = Icons.error;
        title = 'シミュレーションエラー';
        break;
      default:
        color = Colors.blue;
        icon = Icons.info;
        title = '通知';
    }

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(title,
            style: TextStyle(fontWeight: FontWeight.bold, color: color)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (simulationName != null) Text(simulationName),
            if (message != null) Text(message),
            if (timestamp != null)
              Text(
                _formatTimestamp(timestamp),
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.close),
          onPressed: onDismiss,
        ),
      ),
    );
  }

  String _formatTimestamp(String timestamp) {
    try {
      final dateTime = DateTime.parse(timestamp);
      return '${dateTime.year}/${dateTime.month.toString().padLeft(2, '0')}/${dateTime.day.toString().padLeft(2, '0')} '
          '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return timestamp;
    }
  }
}
