import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cogniteam_app/providers/auth_provider.dart'; // To listen to auth state
import 'package:cogniteam_app/screens/login_screen.dart';
import 'package:cogniteam_app/screens/signup_screen.dart';
import 'package:cogniteam_app/screens/home_screen.dart';
import 'package:cogniteam_app/screens/splash_screen.dart';
import 'package:cogniteam_app/screens/edit_my_agent_screen.dart';
import 'package:cogniteam_app/screens/create_chat_group_screen.dart';
import 'package:cogniteam_app/screens/chat_groups_list_screen.dart';
import 'package:cogniteam_app/screens/chat_screen.dart'; // Import ChatScreen
import 'package:cogniteam_app/screens/create_simulation_screen.dart';
import 'package:cogniteam_app/screens/simulations_list_screen.dart';
import 'package:cogniteam_app/screens/simulation_detail_screen.dart';

// Route paths
class AppRoutes {
  static const String splash = '/'; // Initial route, handles auth check
  static const String login = '/login';
  static const String signup = '/signup';
  static const String home = '/home';
  static const String editMyAgent = '/edit-my-agent';
  static const String createChatGroup = '/create-chat-group';
  static const String chatGroupsList = '/chat-groups';
  static const String chatScreen =
      '/chat/:groupId'; // Route with path parameter for groupId
  static const String createSimulation = '/create-simulation';
  static const String simulationsList = '/simulations';
  static const String simulationDetail = '/simulation/:simulationId';
  // Add other routes here, e.g., editProfile, chatGroup, etc.
}

// GoRouter configuration
// We need a ConsumerWidget or similar to access Riverpod's ref for redirect logic.
// GoRouter's refreshListenable and redirect are suitable for this.

final goRouterProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateNotifierProvider); // For redirect logic

  // Create a ValueNotifier that updates when auth state changes
  final refreshNotifier = ValueNotifier(0);

  // Listen to auth state changes and update the notifier
  ref.listen(authStateNotifierProvider, (previous, next) {
    refreshNotifier.value++;
  });

  return GoRouter(
    initialLocation: AppRoutes.splash, // Start at a splash/loading screen
    refreshListenable: refreshNotifier,

    // This redirect logic is crucial for auth flow.
    redirect: (BuildContext context, GoRouterState state) {
      final currentLocation = state.uri.toString();
      final isAuthLoading = authState.isLoading;
      final loggedIn = authState.hasValue && authState.value != null;

      print(
          "GoRouter Redirect: Current Location: $currentLocation, LoggedIn: $loggedIn, AuthLoading: $isAuthLoading");

      // If auth state is still loading, and we are not on splash, stay or go to splash.
      // This prevents redirect loops during initial auth check.
      if (isAuthLoading) {
        return currentLocation == AppRoutes.splash ? null : AppRoutes.splash;
      }

      final isGoingToLogin = currentLocation == AppRoutes.login;
      final isGoingToSignup = currentLocation == AppRoutes.signup;
      final isGoingToSplash = currentLocation == AppRoutes.splash;

      // If logged in:
      if (loggedIn) {
        if (isGoingToLogin || isGoingToSignup || isGoingToSplash) {
          print(
              "Redirect: Logged in, redirecting from auth/splash page to home.");
          return AppRoutes
              .home; // Redirect to home if logged in and on an auth/splash page
        }
        return null; // No redirect needed if logged in and on an allowed page
      }
      // If not logged in:
      else {
        if (isGoingToLogin || isGoingToSignup) {
          return null; // Allow navigation to login, signup if not logged in
        }
        if (isGoingToSplash) {
          print("Redirect: Not logged in, redirecting from splash to login.");
          return AppRoutes
              .login; // Redirect from splash to login if not logged in
        }
        print("Redirect: Not logged in, redirecting to login.");
        return AppRoutes
            .login; // Redirect to login if not logged in and not on an allowed page
      }
    },

    routes: <RouteBase>[
      GoRoute(
        path: AppRoutes.splash,
        builder: (BuildContext context, GoRouterState state) =>
            const SplashScreen(),
      ),
      GoRoute(
        path: AppRoutes.login,
        builder: (BuildContext context, GoRouterState state) =>
            const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.signup,
        builder: (BuildContext context, GoRouterState state) =>
            const SignupScreen(),
      ),
      GoRoute(
        path: AppRoutes.home,
        builder: (BuildContext context, GoRouterState state) =>
            const HomeScreen(),
      ),
      GoRoute(
        path: AppRoutes.editMyAgent,
        builder: (BuildContext context, GoRouterState state) =>
            const EditMyAgentScreen(),
      ),
      GoRoute(
        path: AppRoutes.chatGroupsList,
        builder: (BuildContext context, GoRouterState state) =>
            const ChatGroupsListScreen(),
      ),
      GoRoute(
        path: AppRoutes.createChatGroup, // Typically pushed, not a main tab
        builder: (BuildContext context, GoRouterState state) =>
            const CreateChatGroupScreen(),
      ),
      GoRoute(
        path: AppRoutes.chatScreen, // Matches '/chat/:groupId'
        builder: (BuildContext context, GoRouterState state) {
          final groupId = state.pathParameters['groupId'];
          if (groupId == null) {
            // This should not happen if path is matched correctly, but handle defensively
            return Scaffold(
              appBar: AppBar(title: const Text("Error")),
              body: const Center(child: Text("Group ID is missing.")),
            );
          }
          return ChatScreen(groupId: groupId);
        },
      ),
      GoRoute(
        path: AppRoutes.createSimulation,
        builder: (BuildContext context, GoRouterState state) =>
            const CreateSimulationScreen(),
      ),
      GoRoute(
        path: AppRoutes.simulationsList,
        builder: (BuildContext context, GoRouterState state) =>
            const SimulationsListScreen(),
      ),
      GoRoute(
        path: AppRoutes.simulationDetail,
        builder: (BuildContext context, GoRouterState state) {
          final simulationId = state.pathParameters['simulationId'];
          if (simulationId == null) {
            return Scaffold(
              appBar: AppBar(title: const Text("Error")),
              body: const Center(child: Text("Simulation ID is missing.")),
            );
          }
          return SimulationDetailScreen(simulationId: simulationId);
        },
      ),
    ],
    // Error page (optional)
    errorBuilder: (context, state) => Scaffold(
      appBar: AppBar(title: const Text('Page Not Found')),
      body: Center(child: Text('Error: ${state.error?.message}')),
    ),
  );
});

// Helper class for GoRouter's refreshListenable if needed for more complex scenarios,
// e.g., listening to a stream. For StateNotifier, passing it directly might work or ValueNotifier wrapper.
// class GoRouterRefreshStream extends ChangeNotifier {
//   GoRouterRefreshStream(Stream<dynamic> stream) {
//     notifyListeners(); // Initial notification
//     _subscription = stream.asBroadcastStream().listen((_) => notifyListeners());
//   }
//   late final StreamSubscription<dynamic> _subscription;
//   @override
//   void dispose() {
//     _subscription.cancel();
//     super.dispose();
//   }
// }
