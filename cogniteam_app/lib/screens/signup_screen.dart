import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cogniteam_app/models/user.dart';
import 'package:cogniteam_app/providers/auth_provider.dart';
import 'package:go_router/go_router.dart'; // For navigation
import 'package:cogniteam_app/navigation/app_router.dart'; // For route names

class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key});

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  final _sexController =
      TextEditingController(); // Consider DropdownButtonFormField
  final _birthDateController = TextEditingController(); // Consider DatePicker

  // MBTI and Company details - can be added progressively
  // For now, keeping it simple

  bool _isLoading = false;

  Future<void> _submitForm() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      try {
        // Basic date parsing, ensure YYYY-MM-DD or handle appropriately
        DateTime? birthDate;
        try {
          birthDate = DateTime.parse(_birthDateController.text);
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Invalid date format. Please use YYYY-MM-DD.')),
          );
          setState(() => _isLoading = false);
          return;
        }

        final userCreationData = UserCreationData(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
          name: _nameController.text.trim(),
          sex: _sexController.text.trim(), // TODO: Use a selection widget
          birthDate: birthDate,
          // mbti, company, etc., can be added here
        );

        await ref
            .read(authStateNotifierProvider.notifier)
            .signUp(userCreationData);

        // GoRouter's redirect logic should handle navigation to home upon successful signup and login.
        // If not automatically redirecting, can manually push:
        // if (mounted) context.go(AppRoutes.home);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Signup failed: ${e.toString()}')),
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
    _nameController.dispose();
    _sexController.dispose();
    _birthDateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Listen to auth state for errors (e.g., if signup process sets an error)
    ref.listen<AsyncValue<AppUser?>>(authStateNotifierProvider, (_, state) {
      if (state is AsyncError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${state.error}')),
        );
      }
      // Successful signup will trigger redirect via GoRouter based on auth state change.
    });

    return Scaffold(
      appBar: AppBar(title: const Text('Sign Up')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: <Widget>[
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Full Name'),
                validator: (value) =>
                    value!.isEmpty ? 'Please enter your name' : null,
              ),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: 'Email'),
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value!.isEmpty) return 'Please enter your email';
                  if (!value.contains('@')) return 'Please enter a valid email';
                  return null;
                },
              ),
              TextFormField(
                controller: _passwordController,
                decoration: const InputDecoration(labelText: 'Password'),
                obscureText: true,
                validator: (value) => value!.length < 6
                    ? 'Password must be at least 6 characters'
                    : null,
              ),
              TextFormField(
                controller: _sexController,
                decoration: const InputDecoration(
                    labelText: 'Sex (e.g., Male, Female, Other)'),
                validator: (value) =>
                    value!.isEmpty ? 'Please enter your sex' : null,
              ),
              TextFormField(
                controller: _birthDateController,
                decoration:
                    const InputDecoration(labelText: 'Birth Date (YYYY-MM-DD)'),
                keyboardType: TextInputType.datetime,
                validator: (value) {
                  if (value!.isEmpty) return 'Please enter your birth date';
                  try {
                    DateTime.parse(value); // Simple validation for format
                    return null;
                  } catch (e) {
                    return 'Invalid date format (use YYYY-MM-DD)';
                  }
                },
                onTap: () async {
                  // Optionally show date picker
                  FocusScope.of(context)
                      .requestFocus(FocusNode()); // Hide keyboard
                  DateTime? pickedDate = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now(),
                      firstDate: DateTime(1900),
                      lastDate: DateTime.now());
                  if (pickedDate != null) {
                    _birthDateController.text =
                        pickedDate.toIso8601String().split('T').first;
                  }
                },
              ),
              const SizedBox(height: 20),
              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton(
                      onPressed: _submitForm,
                      child: const Text('Sign Up'),
                    ),
              TextButton(
                onPressed: () => context.go(AppRoutes.login),
                child: const Text('Already have an account? Login'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
