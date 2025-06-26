import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cogniteam_app/providers/agent_provider.dart';
import 'package:cogniteam_app/providers/chat_group_provider.dart';
import 'package:cogniteam_app/providers/auth_provider.dart';
import 'package:cogniteam_app/models/agent.dart';
import 'package:cogniteam_app/models/user.dart';
import 'package:go_router/go_router.dart';
// import 'package:cogniteam_app/navigation/app_router.dart'; // For specific chat screen later

class CreateChatGroupScreen extends ConsumerStatefulWidget {
  const CreateChatGroupScreen({super.key});

  @override
  ConsumerState<CreateChatGroupScreen> createState() =>
      _CreateChatGroupScreenState();
}

class _CreateChatGroupScreenState extends ConsumerState<CreateChatGroupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _groupNameController = TextEditingController();
  final Set<String> _selectedAgentIds = {}; // Store IDs of selected agents
  final Set<String> _selectedUserIds = {}; // Store IDs of selected users
  bool _isLoading = false;

  @override
  void dispose() {
    _groupNameController.dispose();
    super.dispose();
  }

  Future<void> _submitCreateGroup() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    if (_selectedUserIds.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('最低2つのユーザーを選択してください。')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      await ref
          .read(chatGroupCreationNotifierProvider.notifier)
          .createChatGroup(
            _groupNameController.text.trim(),
            _selectedAgentIds.toList(),
            _selectedUserIds.toList(),
          );

      // Check the state of creation
      final creationState = ref.read(chatGroupCreationNotifierProvider);
      if (creationState is AsyncData &&
          creationState.value != null &&
          mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'グループ "${creationState.value!.groupName}" が正常に作成されました！')),
        );
        // Optionally navigate to the new chat group screen or back
        // context.go(AppRoutes.chatScreen, extra: creationState.value!.groupId); // Example
        context.pop(); // Go back to previous screen for now
      } else if (creationState is AsyncError && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('グループの作成に失敗しました: ${creationState.error}')),
        );
      }
    } catch (e) {
      // Catch rethrown error from notifier
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('グループの作成に失敗しました: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final allAgentsAsync = ref.watch(allAgentsProvider);
    final allUsersAsync = ref.watch(allUsersProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('新しいチャットグループを作成')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _groupNameController,
                decoration: const InputDecoration(labelText: 'グループ名'),
                validator: (value) =>
                    value!.trim().isEmpty ? 'グループ名を入力してください' : null,
              ),
              const SizedBox(height: 20),
              Text('エージェントを選択 (オプション):',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Container(
                height: 200,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: allAgentsAsync.when(
                  data: (agents) {
                    if (agents.isEmpty) {
                      return const Center(child: Text('利用可能なエージェントがありません。'));
                    }
                    return ListView.builder(
                      itemCount: agents.length,
                      itemBuilder: (context, index) {
                        final agent = agents[index];
                        return CheckboxListTile(
                          title: Text(agent.name),
                          subtitle: Text(agent.description ?? '説明なし'),
                          value: _selectedAgentIds.contains(agent.agentId),
                          onChanged: (bool? selected) {
                            setState(() {
                              if (selected == true) {
                                _selectedAgentIds.add(agent.agentId);
                              } else {
                                _selectedAgentIds.remove(agent.agentId);
                              }
                            });
                          },
                        );
                      },
                    );
                  },
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (err, stack) =>
                      Center(child: Text('エージェントの読み込みエラー: $err')),
                ),
              ),
              const SizedBox(height: 20),
              Text('Select Users (Required - Minimum 2):',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Container(
                height: 200,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: allUsersAsync.when(
                  data: (users) {
                    if (users.isEmpty) {
                      return const Center(child: Text('利用可能なユーザーがありません。'));
                    }
                    return ListView.builder(
                      itemCount: users.length,
                      itemBuilder: (context, index) {
                        final user = users[index];
                        return CheckboxListTile(
                          title: Text(user.name),
                          subtitle:
                              Text('${user.company ?? '会社なし'} - ${user.email}'),
                          value: _selectedUserIds.contains(user.userId),
                          onChanged: (bool? selected) {
                            setState(() {
                              if (selected == true) {
                                _selectedUserIds.add(user.userId);
                              } else {
                                _selectedUserIds.remove(user.userId);
                              }
                            });
                          },
                        );
                      },
                    );
                  },
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (err, stack) =>
                      Center(child: Text('ユーザーの読み込みエラー: $err')),
                ),
              ),
              const SizedBox(height: 20),
              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _submitCreateGroup,
                        child: const Text('グループを作成'),
                      ),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
