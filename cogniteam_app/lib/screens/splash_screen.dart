import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cogniteam_app/providers/auth_provider.dart'; // To potentially trigger profile refresh

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    // Attempt to refresh user profile on app start / splash screen display.
    // GoRouter's redirect logic will handle navigation based on the auth state.
    // The AuthStateNotifier's _init method already tries to load the profile.
    // This explicit call can be a way to ensure it's triggered if needed,
    // for example, if _init might not have completed or if coming from a cold start.
    // However, ensure it doesn't cause conflicts with _init logic.
    // For now, let's rely on AuthStateNotifier's _init and GoRouter's redirect.
    // If issues arise, uncomment and refine:
    // WidgetsBinding.instance.addPostFrameCallback((_) {
    //   ref.read(authStateNotifierProvider.notifier).refreshUserProfile();
    // });
  }

  @override
  Widget build(BuildContext context) {
    // The GoRouter redirect logic handles navigation away from splash.
    // This screen is primarily a visual placeholder during initial auth check.
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 20),
            Text("Loading CogniTeamAI..."),
          ],
        ),
      ),
    );
  }
}
