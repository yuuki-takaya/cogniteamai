// Corresponds to Agent model in the backend
class Agent {
  final String agentId;
  final String name;
  final String? description;
  final String defaultPrompt;

  Agent({
    required this.agentId,
    required this.name,
    this.description,
    required this.defaultPrompt,
  });

  factory Agent.fromJson(Map<String, dynamic> json) {
    return Agent(
      agentId: json['agent_id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      defaultPrompt: json['default_prompt'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'agent_id': agentId,
      'name': name,
      'description': description,
      'default_prompt': defaultPrompt,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Agent &&
          runtimeType == other.runtimeType &&
          agentId == other.agentId;

  @override
  int get hashCode => agentId.hashCode;

  @override
  String toString() {
    return 'Agent{agentId: $agentId, name: $name}';
  }
}
