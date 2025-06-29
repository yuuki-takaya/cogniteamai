class Simulation {
  final String simulationId;
  final String simulationName;
  final String instruction;
  final List<String> participantUserIds;
  final String status;
  final DateTime createdAt;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final String? resultSummary;
  final String? errorMessage;
  final String createdBy;

  Simulation({
    required this.simulationId,
    required this.simulationName,
    required this.instruction,
    required this.participantUserIds,
    required this.status,
    required this.createdAt,
    this.startedAt,
    this.completedAt,
    this.resultSummary,
    this.errorMessage,
    required this.createdBy,
  });

  factory Simulation.fromJson(Map<String, dynamic> json) {
    return Simulation(
      simulationId: json['simulation_id'] ?? '',
      simulationName: json['simulation_name'] ?? '',
      instruction: json['instruction'] ?? '',
      participantUserIds: List<String>.from(json['participant_user_ids'] ?? []),
      status: json['status'] ?? '',
      createdAt: DateTime.parse(json['created_at']),
      startedAt: json['started_at'] != null
          ? DateTime.parse(json['started_at'])
          : null,
      completedAt: json['completed_at'] != null
          ? DateTime.parse(json['completed_at'])
          : null,
      resultSummary: json['result_summary'],
      errorMessage: json['error_message'],
      createdBy: json['created_by'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'simulation_id': simulationId,
      'simulation_name': simulationName,
      'instruction': instruction,
      'participant_user_ids': participantUserIds,
      'status': status,
      'created_at': createdAt.toIso8601String(),
      'started_at': startedAt?.toIso8601String(),
      'completed_at': completedAt?.toIso8601String(),
      'result_summary': resultSummary,
      'error_message': errorMessage,
      'created_by': createdBy,
    };
  }

  Simulation copyWith({
    String? simulationId,
    String? simulationName,
    String? instruction,
    List<String>? participantUserIds,
    String? status,
    DateTime? createdAt,
    DateTime? startedAt,
    DateTime? completedAt,
    String? resultSummary,
    String? errorMessage,
    String? createdBy,
  }) {
    return Simulation(
      simulationId: simulationId ?? this.simulationId,
      simulationName: simulationName ?? this.simulationName,
      instruction: instruction ?? this.instruction,
      participantUserIds: participantUserIds ?? this.participantUserIds,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
      resultSummary: resultSummary ?? this.resultSummary,
      errorMessage: errorMessage ?? this.errorMessage,
      createdBy: createdBy ?? this.createdBy,
    );
  }
}

class SimulationList {
  final List<Simulation> simulations;
  final int totalCount;

  SimulationList({
    required this.simulations,
    required this.totalCount,
  });

  factory SimulationList.fromJson(Map<String, dynamic> json) {
    return SimulationList(
      simulations: (json['simulations'] as List)
          .map((simulation) => Simulation.fromJson(simulation))
          .toList(),
      totalCount: json['total_count'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'simulations':
          simulations.map((simulation) => simulation.toJson()).toList(),
      'total_count': totalCount,
    };
  }
}

class SimulationCreate {
  final String simulationName;
  final String instruction;
  final List<String> participantUserIds;

  SimulationCreate({
    required this.simulationName,
    required this.instruction,
    required this.participantUserIds,
  });

  Map<String, dynamic> toJson() {
    return {
      'simulation_name': simulationName,
      'instruction': instruction,
      'participant_user_ids': participantUserIds,
    };
  }
}
