import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cogniteam_app/models/user.dart';
import 'package:cogniteam_app/services/auth_service.dart';
import 'package:cogniteam_app/services/api_service.dart';
import 'package:cogniteam_app/services/user_service.dart'; // Import UserService
import 'package:cogniteam_app/services/chat_group_service.dart'; // Import ChatGroupService

// Provider for FirebaseAuth instance
final firebaseAuthProvider = Provider<fb_auth.FirebaseAuth>((ref) {
  return fb_auth.FirebaseAuth.instance;
});

// Provider for ApiService instance (handles async initialization)
final apiServiceProvider = FutureProvider<ApiService>((ref) async {
  return ApiService.getInstance();
});

// Provider for AuthService instance
// Depends on firebaseAuthProvider and apiServiceProvider
final authServiceProvider = Provider<AuthService>((ref) {
  final firebaseAuth = ref.watch(firebaseAuthProvider);
  // apiServiceProvider is a FutureProvider, so we need to handle its state.
  // This setup assumes AuthService constructor needs a resolved ApiService.
  // A common way is to have the dependent provider (like authServiceProvider)
  // also be a FutureProvider or handle the AsyncValue from apiServiceProvider.
  // For simplicity, if ApiService is critical for AuthService construction,
  // authServiceProvider could itself be a FutureProvider or throw if ApiService not ready.

  // Let's assume for now that authServiceProvider will be requested by UI/logic
  // that also handles the loading state of apiServiceProvider, or we make authServiceProvider a FutureProvider.
  // Simpler approach for now: try to read apiService. This might not be robust if read too early.
  final apiServiceAsyncValue = ref.watch(apiServiceProvider);

  // This provider creates AuthService. It assumes that ApiService will be ready
  // when AuthService methods are called, because AuthStateNotifier (which uses AuthService)
  // awaits apiServiceProvider.future in its _init method.
  // This setup can be fragile if AuthService is used elsewhere without ensuring ApiService is ready.
  // A FutureProvider for authServiceProvider would be more robust.
  // However, for use with AuthStateNotifier that handles async init, this can work.
  final apiService = ref
      .watch(apiServiceProvider)
      .value; // Get the value, assuming it's loaded by consumer
  if (apiService == null) {
    // This case should ideally be prevented by consumers awaiting apiServiceProvider.
    // Or, authServiceProvider should be a FutureProvider.
    throw StateError(
        "ApiService not yet available. AuthServiceProvider cannot be created. Ensure ApiServiceProvider is loaded before accessing this.");
  }
  return AuthService(firebaseAuth, apiService);
});

// Provider for UserService instance
final userServiceProvider = Provider<UserService>((ref) {
  final apiService = ref.watch(apiServiceProvider).value;
  if (apiService == null) {
    throw StateError(
        "ApiService not yet available for UserService. Ensure ApiServiceProvider is loaded.");
  }
  return UserService(apiService);
});

// Provider for ChatGroupService instance
final chatGroupServiceProvider = Provider<ChatGroupService>((ref) {
  final apiService = ref.watch(apiServiceProvider).value;
  if (apiService == null) {
    throw StateError(
        "ApiService not yet available for ChatGroupService. Ensure ApiServiceProvider is loaded.");
  }
  return ChatGroupService(apiService);
});

// This provider gives us the stream of Firebase auth state changes.
// It will only provide the stream once authServiceProvider is successfully created.
final authStateChangesProvider = StreamProvider<fb_auth.User?>((ref) {
  // Watching a FutureProvider like authServiceProvider directly in another provider
  // that isn't itself async can be tricky.
  // The `ref.watch(authServiceProvider)` will give AsyncValue.
  // If authServiceProvider is made a FutureProvider:
  // final authServiceAsync = ref.watch(authServiceProviderFutureProvider);
  // return authServiceAsync.when(
  //   data: (authService) => authService.authStateChanges,
  //   loading: () => Stream.empty(), // Or some other handling
  //   error: (e,s) => Stream.error(e,s),
  // );
  // For now, assuming authServiceProvider is synchronous and ApiService is handled by AuthStateNotifier's init
  final authService = ref
      .watch(authServiceProvider); // This might throw if ApiService not ready
  return authService.authStateChanges;
});

// Manages the application's authentication state, including the AppUser profile.
class AuthStateNotifier extends StateNotifier<AsyncValue<AppUser?>> {
  final Ref _ref; // Use Ref for modern Riverpod
  fb_auth.User? _firebaseUser; // Keep track of Firebase user

  // Subscription to Firebase auth state changes
  // StreamSubscription<fb_auth.User?>? _authStateChangesSubscription;

  AuthStateNotifier(this._ref) : super(const AsyncValue.loading()) {
    _init();
  }

  Future<void> _init() async {
    print("AuthStateNotifier: Starting _init()");

    // Wait for ApiService to be ready first.
    // This is crucial because AuthService depends on it.
    // This ensures that when authServiceProvider is read below, it gets a valid ApiService.
    print("AuthStateNotifier: Waiting for ApiService to be ready...");
    await _ref.read(apiServiceProvider.future);
    print("AuthStateNotifier: ApiService is ready");

    // Now it's safe to get AuthService
    final authService = _ref.read(authServiceProvider);
    print("AuthStateNotifier: AuthService obtained");

    // Listen to Firebase auth state changes
    // _authStateChangesSubscription = authService.authStateChanges.listen((fb_auth.User? user) async {
    //   _firebaseUser = user;
    //   if (user == null) {
    //     state = const AsyncValue.data(null); // Logged out
    //   } else {
    //     // User is logged in to Firebase, try to fetch AppUser profile from backend
    //     try {
    //       final appUser = await authService.getCurrentAppUser();
    //       state = AsyncValue.data(appUser);
    //     } catch (e, stack) {
    //       print("Error fetching AppUser profile on auth change: $e");
    //       state = AsyncValue.error(e, stack);
    //       // Optionally sign out from Firebase if backend profile is inaccessible
    //       // await authService.signOut();
    //     }
    //   }
    // });
    _firebaseUser = authService.currentUser;
    print(
        "AuthStateNotifier: Firebase current user: ${_firebaseUser?.uid ?? 'null'}");

    if (_firebaseUser == null) {
      print("AuthStateNotifier: No Firebase user found, setting state to null");
      state = const AsyncValue.data(null);
    } else {
      print(
          "AuthStateNotifier: Firebase user found, fetching AppUser profile...");
      await _fetchAppUserProfile(authService, _firebaseUser!);
    }
  }

  Future<void> _fetchAppUserProfile(
      AuthService authService, fb_auth.User firebaseUser) async {
    print(
        "AuthStateNotifier: _fetchAppUserProfile called for user: ${firebaseUser.uid}");
    try {
      state = const AsyncValue.loading(); // Indicate loading profile
      print("AuthStateNotifier: Calling authService.getCurrentAppUser()...");
      final appUser = await authService.getCurrentAppUser(); // Uses /auth/me
      print(
          "AuthStateNotifier: getCurrentAppUser() completed, result: ${appUser?.userId ?? 'null'}");
      if (appUser != null) {
        state = AsyncValue.data(appUser);
        print("AuthStateNotifier: AppUser profile loaded successfully");
      } else {
        // This means user is authenticated with Firebase, but backend profile is missing or inaccessible.
        // This is a critical state. Sign out from Firebase to reset.
        print(
            "AuthStateNotifier: AppUser profile is null, signing out from Firebase");
        await authService.signOut(); // This authService instance is from _init
        state = const AsyncValue.data(null); // Reflect signed out state
        print(
            "Signed out Firebase user because backend profile was not found/accessible via /auth/me.");
      }
    } catch (e, stack) {
      print("AuthStateNotifier: Error fetching AppUser profile: $e");
      print("AuthStateNotifier: Stack trace: $stack");
      state = AsyncValue.error(e, stack);
      // Potentially sign out from Firebase if critical error
      // await authService.signOut(); // This authService instance is from _init
    }
  }

  Future<void> updateUserProfile(UserProfileUpdateData updateData) async {
    final userService = _ref.read(userServiceProvider);
    final currentAppUser = state.value; // Get current user data if available
    if (currentAppUser == null) {
      state = AsyncValue.error(
          "User not logged in, cannot update profile.", StackTrace.current);
      return;
    }

    try {
      state = const AsyncValue.loading(); // Or a specific "updating" state
      final updatedUser = await userService.updateUserProfile(updateData);
      state = AsyncValue.data(
          updatedUser); // Update state with the new user profile
    } catch (e, stack) {
      // Revert to previous state or keep showing error, with old data if possible
      state = AsyncValue.error(e, stack);
      // To revert to previous state: state = AsyncValue.data(currentAppUser); followed by error display.
      // For simplicity, we show error. UI should handle this gracefully.
      rethrow;
    }
  }

  Future<String?> fetchUserAgentPrompt() async {
    final userService = _ref.read(userServiceProvider);
    try {
      // This method doesn't change the main AppUser state directly,
      // as the prompt is part of AppUser. It's for fetching it on demand if needed.
      // The AppUser state should already have the latest prompt after login/update.
      final prompt = await userService.getUserAgentPrompt();
      // Optionally update the prompt in the current AppUser state if it differs,
      // though ideally backend ensures AppUser model is always consistent.
      if (state.hasValue &&
          state.value != null &&
          state.value!.prompt != prompt) {
        state = AsyncValue.data(state.value!.copyWith(prompt: prompt));
      }
      return prompt;
    } catch (e) {
      // Handle error, e.g., by logging or showing a message via another mechanism
      print("Error fetching user agent prompt: $e");
      return null; // Or rethrow if the caller should handle it
    }
  }

  Future<void> signUp(UserCreationData userCreationData) async {
    final authService =
        _ref.read(authServiceProvider); // Use _ref passed in constructor
    try {
      print(
          "AuthStateNotifier: Starting signUp for email: ${userCreationData.email}");
      state = const AsyncValue.loading();
      final appUser =
          await authService.signUp(userCreationData: userCreationData);
      print(
          "AuthStateNotifier: signUp completed successfully for user: ${appUser.userId}");
      // After successful signup, Firebase auth state listener should pick up the new user
      // and trigger profile fetch. Or, we can set it directly.
      _firebaseUser = authService.currentUser; // Update current Firebase user
      state = AsyncValue.data(appUser);
      print("AuthStateNotifier: State updated with new user profile");
    } catch (e, stack) {
      print("AuthStateNotifier: signUp error: $e");
      print("AuthStateNotifier: signUp stack trace: $stack");
      state = AsyncValue.error(e, stack);
      // Rethrow to allow UI to catch and display specific error
      rethrow;
    }
  }

  Future<void> signInWithEmailAndPassword(String email, String password) async {
    final authService = _ref.read(authServiceProvider); // Use _ref
    try {
      state = const AsyncValue.loading();
      final appUser = await authService.signInWithEmailAndPassword(
          email: email, password: password);
      // Auth state listener should handle the rest, or set directly:
      _firebaseUser = authService.currentUser;
      state = AsyncValue.data(appUser);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }

  Future<void> signOut() async {
    final authService = _ref.read(authServiceProvider); // Use _ref
    try {
      state = const AsyncValue.loading();
      await authService.signOut();
      // Auth state listener will set state to AsyncData(null)
      _firebaseUser = null;
      state = const AsyncValue.data(null); // Explicitly set to signed out
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }

  // Call this on app start or when needed to refresh/ensure profile is loaded
  Future<void> refreshUserProfile() async {
    final authService = _ref.read(authServiceProvider); // Use _ref
    final fbUser = authService.currentUser;
    if (fbUser != null) {
      await _fetchAppUserProfile(
          authService, fbUser); // authService instance is passed here
    } else {
      state = const AsyncValue.data(null); // No Firebase user, so no profile
    }
  }

  // @override
  // void dispose() {
  //   _authStateChangesSubscription?.cancel();
  //   super.dispose();
  // }
}

// The StateNotifierProvider for AuthState
final authStateNotifierProvider =
    StateNotifierProvider<AuthStateNotifier, AsyncValue<AppUser?>>((ref) {
  // Pass the ref to AuthStateNotifier's constructor.
  // The _init method within AuthStateNotifier will use this ref to read other providers.
  return AuthStateNotifier(ref);
});

// A simpler provider that just exposes the current AppUser? from the AuthStateNotifier
final appUserProvider = Provider<AppUser?>((ref) {
  final authState = ref.watch(authStateNotifierProvider);
  return authState.asData?.value;
});

// Exposes the current Firebase User
final firebaseUserProvider = Provider<fb_auth.User?>((ref) {
  // This relies on the AuthStateNotifier to keep track of _firebaseUser,
  // or more directly, watch the authStateChangesProvider.
  // For direct Firebase user:
  final authState = ref.watch(authStateChangesProvider);
  return authState.asData?.value;
});
