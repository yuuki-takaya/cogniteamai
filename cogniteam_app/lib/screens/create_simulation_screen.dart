import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cogniteam_app/providers/simulation_provider.dart';
import 'package:cogniteam_app/providers/auth_provider.dart';
import 'package:cogniteam_app/models/user.dart' as app_user;
import 'package:go_router/go_router.dart';

class CreateSimulationScreen extends ConsumerStatefulWidget {
  const CreateSimulationScreen({super.key});

  @override
  ConsumerState<CreateSimulationScreen> createState() =>
      _CreateSimulationScreenState();
}

class _CreateSimulationScreenState
    extends ConsumerState<CreateSimulationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _simulationNameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final Set<String> _selectedUserIds = {}; // Store IDs of selected users
  bool _isLoading = false;

  @override
  void dispose() {
    _simulationNameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submitCreateSimulation() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    if (_selectedUserIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('最低1つのユーザーを選択してください。')),
      );
      return;
    }

    try {
      await ref.read(simulationCreationProvider.notifier).createSimulation(
            simulationName: _simulationNameController.text.trim(),
            instruction: _descriptionController.text.trim(),
            participantUserIds: _selectedUserIds.toList(),
          );

      // 作成成功時の処理
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'シミュレーション "${_simulationNameController.text}" が正常に作成されました！'),
          ),
        );

        // シミュレーション一覧画面に遷移
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('シミュレーションの作成に失敗しました: ${e.toString()}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final allUsersAsync = ref.watch(allUsersProvider);
    final creationState = ref.watch(simulationCreationProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('新しいシミュレーションを作成')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _simulationNameController,
                decoration: const InputDecoration(labelText: 'シミュレーション名'),
                validator: (value) =>
                    value!.trim().isEmpty ? 'シミュレーション名を入力してください' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(labelText: '説明（instruction）'),
                maxLines: 3,
                validator: (value) =>
                    value!.trim().isEmpty ? '説明を入力してください' : null,
              ),
              const SizedBox(height: 20),
              Text('参加ユーザーを選択:',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Container(
                height: 300,
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
              creationState.when(
                data: (simulation) => SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _submitCreateSimulation,
                    child: const Text('シミュレーションを作成'),
                  ),
                ),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stack) => Column(
                  children: [
                    Text(
                      'エラー: $error',
                      style: const TextStyle(color: Colors.red),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _submitCreateSimulation,
                        child: const Text('再試行'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
