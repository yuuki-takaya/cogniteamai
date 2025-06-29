import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cogniteam_app/models/simulation.dart' as sim;
import 'package:cogniteam_app/providers/simulation_provider.dart';
import 'package:cogniteam_app/navigation/app_router.dart';

class SimulationDetailScreen extends ConsumerWidget {
  final String simulationId;

  const SimulationDetailScreen({
    super.key,
    required this.simulationId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final simulationAsync = ref.watch(simulationDetailProvider(simulationId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('シミュレーション詳細'),
        backgroundColor: Colors.blue[600],
        foregroundColor: Colors.white,
      ),
      body: simulationAsync.when(
        data: (simulation) {
          if (simulation == null) {
            return const Center(
              child: Text('シミュレーションが見つかりません'),
            );
          }

          // 参加者情報を取得
          final participantsAsync = ref.watch(
            participantsInfoProvider(simulation.participantUserIds),
          );

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeaderSection(simulation),
                const SizedBox(height: 16),
                participantsAsync.when(
                  data: (participants) =>
                      _buildParticipantsSection(simulation, participants),
                  loading: () => _buildParticipantsSection(simulation, []),
                  error: (error, stack) =>
                      _buildParticipantsSection(simulation, []),
                ),
                const SizedBox(height: 16),
                _buildInstructionSection(simulation),
                if (simulation.status == 'completed' &&
                    simulation.resultSummary != null) ...[
                  const SizedBox(height: 16),
                  _buildResultSection(simulation),
                ],
                if (simulation.status == 'error' &&
                    simulation.errorMessage != null) ...[
                  const SizedBox(height: 16),
                  _buildErrorSection(simulation),
                ],
                const SizedBox(height: 16),
                _buildTimelineSection(simulation),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Text('エラーが発生しました: $error'),
        ),
      ),
    );
  }

  Widget _buildHeaderSection(sim.Simulation simulation) {
    return Card(
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
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                _StatusChip(status: simulation.status),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '作成日時: ${_formatDateTime(simulation.createdAt)}',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusSection(sim.Simulation simulation) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'ステータス',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 12),
            _StatusChip(status: simulation.status),
            if (simulation.status == 'running') ...[
              const SizedBox(height: 8),
              const LinearProgressIndicator(),
              const SizedBox(height: 8),
              Text(
                'シミュレーション実行中...',
                style: TextStyle(
                  color: Colors.blue[700],
                  fontSize: 14,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildParticipantsSection(
      sim.Simulation simulation, List<Map<String, dynamic>> participants) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '参加者',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '${participants.length}人の参加者',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: participants.map((participant) {
                return Chip(
                  label:
                      Text(participant['displayName'] ?? participant['userId']),
                  backgroundColor: Colors.blue[50],
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInstructionSection(sim.Simulation simulation) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'シミュレーション指示',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              simulation.instruction,
              style: const TextStyle(fontSize: 16, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultSection(sim.Simulation simulation) {
    return Card(
      color: Colors.green[50],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.check_circle,
                  color: Colors.green[700],
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'シミュレーション結果',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.green[700],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              simulation.resultSummary!,
              style: TextStyle(
                fontSize: 16,
                height: 1.5,
                color: Colors.green[800],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorSection(sim.Simulation simulation) {
    return Card(
      color: Colors.red[50],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.error,
                  color: Colors.red[700],
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'エラー',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.red[700],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              simulation.errorMessage!,
              style: TextStyle(
                fontSize: 16,
                height: 1.5,
                color: Colors.red[800],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimelineSection(sim.Simulation simulation) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'タイムライン',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 16),
            _TimelineItem(
              icon: Icons.create,
              title: '作成',
              time: simulation.createdAt,
              isCompleted: true,
            ),
            if (simulation.startedAt != null) ...[
              _TimelineItem(
                icon: Icons.play_arrow,
                title: '開始',
                time: simulation.startedAt!,
                isCompleted: true,
              ),
            ],
            if (simulation.completedAt != null) ...[
              _TimelineItem(
                icon: Icons.check_circle,
                title: '完了',
                time: simulation.completedAt!,
                isCompleted: true,
              ),
            ],
            if (simulation.status == 'pending') ...[
              _TimelineItem(
                icon: Icons.schedule,
                title: '待機中',
                time: null,
                isCompleted: false,
              ),
            ],
            if (simulation.status == 'running') ...[
              _TimelineItem(
                icon: Icons.play_arrow,
                title: '実行中',
                time: null,
                isCompleted: false,
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.year}/${dateTime.month.toString().padLeft(2, '0')}/${dateTime.day.toString().padLeft(2, '0')} '
        '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color: color,
          ),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              fontSize: 14,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _TimelineItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final DateTime? time;
  final bool isCompleted;

  const _TimelineItem({
    required this.icon,
    required this.title,
    required this.time,
    required this.isCompleted,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: isCompleted ? Colors.blue : Colors.grey[300],
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: isCompleted ? Colors.white : Colors.grey[600],
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: isCompleted ? Colors.black : Colors.grey[600],
                  ),
                ),
                if (time != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    '${time!.year}/${time!.month.toString().padLeft(2, '0')}/${time!.day.toString().padLeft(2, '0')} '
                    '${time!.hour.toString().padLeft(2, '0')}:${time!.minute.toString().padLeft(2, '0')}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
