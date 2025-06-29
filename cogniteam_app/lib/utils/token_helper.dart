import 'package:firebase_auth/firebase_auth.dart' as fb_auth;

class TokenHelper {
  static final fb_auth.FirebaseAuth _firebaseAuth =
      fb_auth.FirebaseAuth.instance;

  /// 現在のユーザーのIDトークンを取得
  static Future<String?> getCurrentIdToken() async {
    try {
      final fb_auth.User? currentUser = _firebaseAuth.currentUser;
      if (currentUser == null) {
        print('No user is currently signed in');
        return null;
      }

      final String? idToken = await currentUser.getIdToken(true);
      if (idToken != null) {
        print('ID Token obtained successfully');
        print('Token starts with: ${idToken.substring(0, 20)}...');
        return idToken;
      } else {
        print('Failed to get ID token');
        return null;
      }
    } catch (e) {
      print('Error getting ID token: $e');
      return null;
    }
  }

  /// 指定されたユーザーでログインしてIDトークンを取得
  static Future<String?> getIdTokenForUser({
    required String email,
    required String password,
  }) async {
    try {
      // ログイン
      final fb_auth.UserCredential userCredential =
          await _firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final fb_auth.User? user = userCredential.user;
      if (user == null) {
        print('Login failed: User is null');
        return null;
      }

      // IDトークンを取得
      final String? idToken = await user.getIdToken(true);
      if (idToken != null) {
        print('ID Token obtained for user: ${user.email}');
        print('Token starts with: ${idToken.substring(0, 20)}...');
        return idToken;
      } else {
        print('Failed to get ID token');
        return null;
      }
    } catch (e) {
      print('Error during login and token retrieval: $e');
      return null;
    }
  }

  /// 現在のユーザー情報を表示
  static void printCurrentUserInfo() {
    final fb_auth.User? currentUser = _firebaseAuth.currentUser;
    if (currentUser != null) {
      print('Current user:');
      print('  UID: ${currentUser.uid}');
      print('  Email: ${currentUser.email}');
      print('  Display Name: ${currentUser.displayName}');
    } else {
      print('No user is currently signed in');
    }
  }
}
