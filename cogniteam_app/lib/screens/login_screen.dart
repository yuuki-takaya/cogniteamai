import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cogniteam_app/providers/auth_provider.dart';
import 'package:cogniteam_app/models/user.dart'; // For AppUser type in AsyncValue
import 'package:go_router/go_router.dart'; // For navigation
import 'package:cogniteam_app/navigation/app_router.dart'; // For route names
import 'package:firebase_auth/firebase_auth.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  Future<void> _submitForm() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      try {
        await ref
            .read(authStateNotifierProvider.notifier)
            .signInWithEmailAndPassword(
              _emailController.text.trim(),
              _passwordController.text.trim(),
            );
        // GoRouter's redirect logic should handle navigation to home upon successful login.
        // if (mounted) context.go(AppRoutes.home);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Login failed: ${e.toString()}')),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Listen to auth state for errors or successful login
    ref.listen<AsyncValue<AppUser?>>(authStateNotifierProvider, (_, state) {
      if (state is AsyncError) {
        // Avoid showing error if already handled by _submitForm's catch block
        // This listener is more for external state changes or if error wasn't shown by the action.
        // For now, let's comment it out to prevent double snackbars for login failures.
        // ScaffoldMessenger.of(context).showSnackBar(
        //   SnackBar(content: Text('Login error: ${state.error.toString()}')),
        // );
      }
      // Successful login will trigger redirect via GoRouter based on auth state change.
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('ログイン'),
        actions: [
          // Debug button to clear Firebase auth state
          IconButton(
            icon: const Icon(Icons.bug_report),
            onPressed: () async {
              try {
                await FirebaseAuth.instance.signOut();
                print("Debug: Firebase user signed out");
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Firebase認証をクリアしました')),
                );
              } catch (e) {
                print("Debug: Error signing out: $e");
              }
            },
            tooltip: 'Firebase認証をクリア（デバッグ用）',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: 'Email'),
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value == null || value.isEmpty)
                    return 'Please enter your email';
                  if (!value.contains('@')) return 'Please enter a valid email';
                  return null;
                },
              ),
              TextFormField(
                controller: _passwordController,
                decoration: const InputDecoration(labelText: 'Password'),
                obscureText: true,
                validator: (value) {
                  if (value == null || value.isEmpty)
                    return 'Please enter your password';
                  return null;
                },
              ),
              const SizedBox(height: 20),
              _isLoading
                  ? const CircularProgressIndicator()
                  : ElevatedButton(
                      onPressed: _submitForm,
                      child: const Text('Login'),
                    ),
              TextButton(
                onPressed: () => context.go(AppRoutes.signup),
                child: const Text('Don\'t have an account? Sign Up'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
