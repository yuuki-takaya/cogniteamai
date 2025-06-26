import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cogniteam_app/providers/chat_group_provider.dart';
import 'package:cogniteam_app/models/chat_group.dart';
import 'package:go_router/go_router.dart';
import 'package:cogniteam_app/navigation/app_router.dart'; // For route names

class ChatGroupsListScreen extends ConsumerWidget {
  const ChatGroupsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final myChatGroupsAsync = ref.watch(myChatGroupsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Chat Groups'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Create New Group',
            onPressed: () {
              context.push(AppRoutes.createChatGroup); // Use push for a new screen over the list
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh List',
            onPressed: () {
              ref.invalidate(myChatGroupsProvider);
            },
          ),
        ],
      ),
      body: myChatGroupsAsync.when(
        data: (groups) {
          if (groups.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('No chat groups found.'),
                  const SizedBox(height: 10),
                  ElevatedButton(
                    onPressed: () => context.push(AppRoutes.createChatGroup),
                    child: const Text('Create Your First Group'),
                  ),
                ],
              ),
            );
          }
          return ListView.builder(
            itemCount: groups.length,
            itemBuilder: (context, index) {
              final group = groups[index];
              return ListTile(
                title: Text(group.groupName),
                subtitle: Text(
                  'Agents: ${group.agentIds.length} | Created: ${group.createdAt.toLocal().toString().split(' ')[0]}',
                ),
                trailing: const Icon(Icons.arrow_forward_ios),
                onTap: () {
                  // Navigate to the specific chat screen for this group
                  // The path parameter :groupId will be replaced by group.groupId
                  context.push(AppRoutes.chatScreen.replaceFirst(':groupId', group.groupId));
                },
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Error loading chat groups: $err'),
                ElevatedButton(
                  onPressed: () => ref.invalidate(myChatGroupsProvider),
                  child: const Text('Retry'),
                )
              ],
            ),
          );
        },
      ),
    );
  }
}
```
