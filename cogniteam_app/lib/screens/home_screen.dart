import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cogniteam_app/providers/auth_provider.dart';
import 'package:cogniteam_app/providers/simulation_provider.dart';
import 'package:cogniteam_app/models/user.dart';
import 'package:go_router/go_router.dart'; // For context.go
import 'package:cogniteam_app/navigation/app_router.dart'; // For AppRoutes

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateNotifierProvider);
    final notificationState = ref.watch(simulationNotificationProvider);

    print(
        "HomeScreen: Building with notification state - connected: ${notificationState.isConnected}, notifications: ${notificationState.notifications.length}, error: ${notificationState.errorMessage}");

    return Scaffold(
      appBar: AppBar(
        title: const Text('CogniTeamAI Home'),
        actions: [
          // 通知アイコン
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.notifications),
                onPressed: () {
                  _showNotificationsDialog(context, ref, notificationState);
                },
                tooltip: 'シミュレーション通知',
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
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await ref.read(authStateNotifierProvider.notifier).signOut();
              // GoRouter redirect should handle navigation to login screen
            },
            tooltip: 'Logout',
          ),
        ],
      ),
      body: Center(
        child: authState.when(
          data: (AppUser? user) {
            if (user != null) {
              return Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Text('Welcome, ${user.name}!'),
                  Text('Email: ${user.email}'),
                  Text('User ID: ${user.userId}'),
                  const SizedBox(height: 20),
                  Text(
                      'Current Prompt (from User object): ${user.prompt ?? "Not set"}'),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () {
                      context.go(AppRoutes.editMyAgent);
                    },
                    child: const Text('Edit My Agent Profile'),
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton(
                    onPressed: () {
                      context.push(AppRoutes
                          .chatGroupsList); // Use push to keep home in stack
                    },
                    child: const Text('View My Chat Groups'),
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton(
                    onPressed: () {
                      context.push(AppRoutes.simulationsList);
                    },
                    child: const Text('シミュレーション一覧'),
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton(
                    onPressed: () {
                      context.push(AppRoutes.createSimulation);
                    },
                    child: const Text('新しいシミュレーションを作成'),
                  ),
                  // Add more buttons/navigation to other features like:
                  // - Create/View Chat Groups (direct create button might be on ChatGroupsListScreen)
                ],
              );
            } else {
              // This case should ideally be handled by GoRouter redirecting to login
              return const Text('Not logged in. Redirecting...');
            }
          },
          loading: () => const CircularProgressIndicator(),
          error: (error, stackTrace) => Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('Error loading user profile:'),
              Text(error.toString()),
              ElevatedButton(
                onPressed: () => ref
                    .read(authStateNotifierProvider.notifier)
                    .refreshUserProfile(),
                child: const Text("Try Again"),
              )
            ],
          ),
        ),
      ),
    );
  }

  void _showNotificationsDialog(
      BuildContext context, WidgetRef ref, notificationState) {
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
