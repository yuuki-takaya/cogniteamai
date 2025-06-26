import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cogniteam_app/models/insight.dart';
import 'package:cogniteam_app/services/insight_service.dart';
import 'package:cogniteam_app/providers/auth_provider.dart'; // For insightServiceProvider

// Parameter class for the family provider
class InsightProviderParams {
  final String groupId;
  final String insightType;

  InsightProviderParams({required this.groupId, this.insightType = "summary"});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is InsightProviderParams &&
          runtimeType == other.runtimeType &&
          groupId == other.groupId &&
          insightType == other.insightType;

  @override
  int get hashCode => groupId.hashCode ^ insightType.hashCode;
}

// FutureProvider.family to fetch insight for a specific group and type
// This will automatically handle loading/error states and caching based on params.
final groupInsightProvider = FutureProvider.autoDispose.family<Insight, InsightProviderParams>((ref, params) async {
  final insightService = ref.watch(insightServiceProvider);
  // Ensure user is logged in before attempting to fetch insights,
  // as insight routes are protected. ApiService interceptor handles token.
  final appUser = ref.watch(appUserProvider);
  if (appUser == null) {
    throw Exception("User not authenticated. Cannot fetch insights.");
  }

  return insightService.getInsightsForGroup(params.groupId, insightType: params.insightType);
});
```
