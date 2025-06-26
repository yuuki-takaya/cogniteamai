import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cogniteam_app/providers/agent_provider.dart';
import 'package:cogniteam_app/providers/chat_group_provider.dart';
import 'package:cogniteam_app/models/agent.dart';
import 'package:go_router/go_router.dart';
// import 'package:cogniteam_app/navigation/app_router.dart'; // For specific chat screen later

class CreateChatGroupScreen extends ConsumerStatefulWidget {
  const CreateChatGroupScreen({super.key});

  @override
  ConsumerState<CreateChatGroupScreen> createState() => _CreateChatGroupScreenState();
}

class _CreateChatGroupScreenState extends ConsumerState<CreateChatGroupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _groupNameController = TextEditingController();
  final Set<String> _selectedAgentIds = {}; // Store IDs of selected agents
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
    if (_selectedAgentIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one agent.')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      await ref.read(chatGroupCreationNotifierProvider.notifier).createChatGroup(
            _groupNameController.text.trim(),
            _selectedAgentIds.toList(),
          );

      // Check the state of creation
      final creationState = ref.read(chatGroupCreationNotifierProvider);
      if (creationState is AsyncData && creationState.value != null && mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Group "${creationState.value!.groupName}" created successfully!')),
        );
        // Optionally navigate to the new chat group screen or back
        // context.go(AppRoutes.chatScreen, extra: creationState.value!.groupId); // Example
        context.pop(); // Go back to previous screen for now
      } else if (creationState is AsyncError && mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create group: ${creationState.error}')),
        );
      }
    } catch (e) { // Catch rethrown error from notifier
       if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create group: ${e.toString()}')),
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

    return Scaffold(
      appBar: AppBar(title: const Text('Create New Chat Group')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _groupNameController,
                decoration: const InputDecoration(labelText: 'Group Name'),
                validator: (value) => value!.trim().isEmpty ? 'Group name cannot be empty' : null,
              ),
              const SizedBox(height: 20),
              Text('Select Agents:', style: Theme.of(context).textTheme.titleMedium),
              Expanded(
                child: allAgentsAsync.when(
                  data: (agents) {
                    if (agents.isEmpty) {
                      return const Center(child: Text('No agents available.'));
                    }
                    return ListView.builder(
                      itemCount: agents.length,
                      itemBuilder: (context, index) {
                        final agent = agents[index];
                        return CheckboxListTile(
                          title: Text(agent.name),
                          subtitle: Text(agent.description ?? 'No description'),
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
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (err, stack) => Center(child: Text('Error loading agents: $err')),
                ),
              ),
              const SizedBox(height: 20),
              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _submitCreateGroup,
                        child: const Text('Create Group'),
                      ),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
```
