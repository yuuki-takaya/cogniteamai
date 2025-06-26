import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:cogniteam_app/models/user.dart'; // AppUser and UserCreationData
import 'package:cogniteam_app/services/api_service.dart';
import 'package:dio/dio.dart';

class AuthService {
  final fb_auth.FirebaseAuth _firebaseAuth;
  final ApiService _apiService;

  // Constructor now takes an ApiService instance.
  // The caller (e.g., a Riverpod provider) will be responsible for
  // obtaining the ApiService instance (which involves async initialization).
  AuthService(this._firebaseAuth, this._apiService);

  /// Provides a stream of the current Firebase Authentication user.
  /// Emits null if logged out, or a User object if logged in.
  Stream<fb_auth.User?> get authStateChanges =>
      _firebaseAuth.authStateChanges();

  /// Gets the current Firebase User object, or null if not logged in.
  fb_auth.User? get currentUser => _firebaseAuth.currentUser;

  /// Signs up a new user with Firebase Authentication and then registers them with the backend.
  Future<AppUser> signUp({
    required UserCreationData userCreationData,
  }) async {
    try {
      // 1. Create user with Firebase Authentication
      final fb_auth.UserCredential userCredential =
          await _firebaseAuth.createUserWithEmailAndPassword(
        email: userCreationData.email,
        password: userCreationData.password,
      );

      final fb_auth.User? firebaseUser = userCredential.user;
      if (firebaseUser == null) {
        throw Exception('Firebase user creation failed: User is null.');
      }

      // Update Firebase user's display name (optional, but good practice)
      await firebaseUser.updateDisplayName(userCreationData.name);

      // 2. Get ID token (force refresh to ensure it's not stale if user was just created)
      // Note: For newly created user, getIdToken might not be immediately available or might be stale.
      // It's generally reliable, but be aware of potential timing issues in some edge cases.
      // String idToken = await firebaseUser.getIdToken(true); // Force refresh

      // 3. Register user with your backend by sending UserCreationData (which includes email and password)
      // The backend will use the password to create the user in Firebase Auth again (idempotently if already exists)
      // or, more commonly, the backend's /signup would not re-create in Firebase Auth if client did it.
      // The current backend /signup expects UserCreate (which includes password).
      // This means backend will call Firebase Admin SDK's createUser.
      // If client already created, this could lead to "email already exists" on backend.
      //
      // Revised flow:
      // Client creates user in Firebase Auth.
      // Client gets ID token.
      // Client sends ID token AND profile data (UserCreationData minus password) to a backend "/register-profile" endpoint.
      // Backend verifies ID token, then saves profile data to Firestore, linking with UID from token.
      //
      // For now, sticking to the plan's backend /auth/signup which expects UserCreate.
      // This implies the client might not create the user in Firebase directly, OR the backend
      // signup needs to be idempotent / handle "already exists" by linking profile.
      //
      // Let's assume the current backend /auth/signup is the single point of Firebase user creation.
      // So, Flutter app *does not* call _firebaseAuth.createUserWithEmailAndPassword directly.
      // Instead, it calls backend /auth/signup, and then client signs in with the same credentials.
      // This simplifies backend logic but means client doesn't get immediate Firebase User object from signup.

      // **Corrected Flow based on Backend's current /auth/signup:**
      // 1. Client sends UserCreationData to backend's /auth/signup.
      // 2. Backend creates user in Firebase Auth & Firestore, returns AppUser profile.
      // 3. Client then uses email/password to sign in to Firebase Client SDK to get active session.

      // final api = await _safeApiService; // No longer needed
      final response = await _apiService.post(
        '/auth/signup', // Backend endpoint
        data: userCreationData.toJson(),
      );

      if (response.statusCode == 201 && response.data != null) {
        final AppUser appUser =
            AppUser.fromJson(response.data as Map<String, dynamic>);

        // 4. After successful backend registration, sign in the user on the client-side Firebase
        await _firebaseAuth.signInWithEmailAndPassword(
          email: userCreationData.email,
          password: userCreationData.password,
        );
        print(
            "Firebase client signed in successfully after backend registration.");
        return appUser;
      } else {
        throw Exception(
            'Backend user registration failed: ${response.statusMessage} ${response.data}');
      }
    } on fb_auth.FirebaseAuthException catch (e) {
      print("FirebaseAuthException during signup: ${e.code} - ${e.message}");
      throw Exception('Firebase signup error: ${e.message}');
    } on DioException catch (e) {
      print("DioException during backend signup: ${e.message}");
      final errorMsg =
          e.response?.data?['detail'] ?? e.message ?? "Signup failed";
      throw Exception('Backend signup error: $errorMsg');
    } catch (e) {
      print("Generic error during signup: $e");
      throw Exception('An unexpected error occurred during signup: $e');
    }
  }

  /// Signs in a user with Firebase Authentication and then fetches their profile from the backend.
  Future<AppUser> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      print(
          "AuthService: Starting signInWithEmailAndPassword for email: $email");

      // 1. Sign in with Firebase Authentication
      print("AuthService: Attempting Firebase sign in...");
      final fb_auth.UserCredential userCredential =
          await _firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final fb_auth.User? firebaseUser = userCredential.user;
      if (firebaseUser == null) {
        print("AuthService: Firebase sign-in failed: User is null");
        throw Exception('Firebase sign-in failed: User is null.');
      }

      print(
          "AuthService: Firebase sign-in successful. UID: ${firebaseUser.uid}");

      // 2. Get ID token
      print("AuthService: Getting ID token from Firebase...");
      final String? idTokenNullable =
          await firebaseUser.getIdToken(true); // Force refresh

      if (idTokenNullable == null) {
        print("AuthService: Failed to get ID token from Firebase");
        throw Exception('Failed to get ID token from Firebase');
      }
      final String idToken = idTokenNullable;
      print(
          "AuthService: ID token obtained successfully. Length: ${idToken.length}");
      print(
          "AuthService: ID token starts with: ${idToken.substring(0, 20)}...");

      // 3. Send ID token to backend's /auth/login to get full AppUser profile
      // final api = await _safeApiService; // No longer needed
      print("AuthService: Sending ID token to backend /auth/login...");
      final response = await _apiService.post(
        '/auth/login',
        data: {'id_token': idToken},
      );

      print(
          "AuthService: Backend response received. Status: ${response.statusCode}");
      if (response.statusCode == 200 && response.data != null) {
        print("AuthService: Backend login successful, parsing AppUser...");
        return AppUser.fromJson(response.data as Map<String, dynamic>);
      } else {
        print(
            "AuthService: Backend login failed. Status: ${response.statusCode}, Data: ${response.data}");
        // Attempt to sign out from Firebase if backend login fails to keep consistent state
        await _firebaseAuth.signOut();
        throw Exception(
            'Backend login failed: ${response.statusMessage} ${response.data}');
      }
    } on fb_auth.FirebaseAuthException catch (e) {
      print(
          "AuthService: FirebaseAuthException during signin: ${e.code} - ${e.message}");
      // Common codes: "invalid-email", "user-not-found", "wrong-password", "user-disabled"
      // "INVALID_LOGIN_CREDENTIALS" is common for wrong email/password with recent SDKs
      if (e.code == 'user-not-found' ||
          e.code == 'wrong-password' ||
          e.code.toUpperCase().contains('INVALID_LOGIN_CREDENTIALS')) {
        throw Exception('Invalid email or password.');
      }
      throw Exception('Firebase sign-in error: ${e.message}');
    } on DioException catch (e) {
      print("AuthService: DioException during backend login: ${e.message}");
      print(
          "AuthService: DioException response status: ${e.response?.statusCode}");
      print("AuthService: DioException response data: ${e.response?.data}");
      // Attempt to sign out from Firebase if backend login fails
      await _firebaseAuth.signOut();
      final errorMsg =
          e.response?.data?['detail'] ?? e.message ?? "Login failed";
      throw Exception('Backend login error: $errorMsg');
    } catch (e) {
      print("AuthService: Generic error during signin: $e");
      // Attempt to sign out from Firebase if backend login fails
      await _firebaseAuth.signOut();
      throw Exception('An unexpected error occurred during sign-in: $e');
    }
  }

  /// Signs out the current user from Firebase.
  Future<void> signOut() async {
    try {
      await _firebaseAuth.signOut();
      print("User signed out from Firebase.");
    } catch (e) {
      print("Error signing out from Firebase: $e");
      // Decide if this should throw or just log
      throw Exception('Error signing out: $e');
    }
  }

  /// Retrieves the current AppUser profile from the backend if a user is signed in.
  /// This would typically be called after initial login or on app startup if user is already signed in.
  Future<AppUser?> getCurrentAppUser() async {
    print("AuthService: getCurrentAppUser() called");
    final fb_auth.User? firebaseUser = _firebaseAuth.currentUser;
    if (firebaseUser == null) {
      print("AuthService: No Firebase user found, returning null");
      return null; // Not signed into Firebase
    }
    print("AuthService: Firebase user found: ${firebaseUser.uid}");
    try {
      final String? idTokenNullable =
          await firebaseUser.getIdToken(true); // Refresh token

      if (idTokenNullable == null) {
        print("AuthService: Failed to get ID token from Firebase");
        throw Exception('Failed to get ID token from Firebase');
      }
      final String idToken = idTokenNullable;
      print("AuthService: ID token obtained successfully");

      // final api = await _safeApiService; // No longer needed
      // Assuming backend has a "/auth/me" endpoint protected by get_current_user dependency
      print("AuthService: Making GET request to /auth/me");
      final response = await _apiService.get('/auth/me');
      print("AuthService: Response received: ${response.statusCode}");

      if (response.statusCode == 200 && response.data != null) {
        print("AuthService: Successfully parsed AppUser from response");
        return AppUser.fromJson(response.data as Map<String, dynamic>);
      } else {
        // If /auth/me fails, something is wrong (e.g., profile missing in backend despite Firebase auth)
        print(
            "AuthService: Failed to get user profile from backend /auth/me: ${response.statusCode}");
        await _firebaseAuth.signOut(); // Sign out to reset state
        return null;
      }
    } catch (e) {
      print("AuthService: Error fetching current app user from backend: $e");
      // Consider signing out if backend profile fetch fails critically
      // await _firebaseAuth.signOut();
      return null;
    }
  }
}
