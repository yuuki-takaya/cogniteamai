import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cogniteam_app/models/agent.dart';
import 'package:cogniteam_app/services/agent_service.dart';
import 'package:cogniteam_app/providers/auth_provider.dart'; // For apiServiceProvider dependency

// This provider depends on apiServiceProvider to get an instance of ApiService
// which is then used to create AgentService.

// Provider for AgentService instance
final agentServiceProvider = Provider<AgentService>((ref) {
  final apiService = ref.watch(apiServiceProvider).value;
  if (apiService == null) {
    // This state indicates that ApiService is not yet ready.
    // Consumers of this provider or providers depending on this one
    // should handle the loading/error state of apiServiceProvider.
    throw StateError(
        "ApiService not yet available for AgentService. Ensure ApiServiceProvider is loaded.");
  }
  return AgentService(apiService);
});

// FutureProvider to fetch all agents
// This will automatically handle loading/error states and caching.
final allAgentsProvider = FutureProvider<List<Agent>>((ref) async {
  final agentService = ref.watch(agentServiceProvider);
  return agentService.getAllAgents();
});
