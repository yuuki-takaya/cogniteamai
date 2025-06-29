import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cogniteam_app/providers/auth_provider.dart';
import 'package:cogniteam_app/models/user.dart';
import 'package:go_router/go_router.dart'; // For context.go
import 'package:cogniteam_app/navigation/app_router.dart'; // For AppRoutes

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateNotifierProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('CogniTeamAI Home'),
        actions: [
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
}
