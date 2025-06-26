import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cogniteam_app/providers/auth_provider.dart';
import 'package:cogniteam_app/models/user.dart';
import 'package:cogniteam_app/services/user_service.dart'; // For UserProfileUpdateData

class EditMyAgentScreen extends ConsumerStatefulWidget {
  const EditMyAgentScreen({super.key});

  @override
  ConsumerState<EditMyAgentScreen> createState() => _EditMyAgentScreenState();
}

class _EditMyAgentScreenState extends ConsumerState<EditMyAgentScreen> {
  final _formKey = GlobalKey<FormState>();

  // Controllers for form fields
  late TextEditingController _nameController;
  late TextEditingController _sexController;
  late TextEditingController _birthDateController;
  late TextEditingController _mbtiController;
  late TextEditingController _companyController;
  late TextEditingController _divisionController;
  late TextEditingController _departmentController;
  late TextEditingController _sectionController;
  late TextEditingController _roleController;

  String? _currentPrompt;
  bool _isLoading = false;
  bool _isFetchingPrompt = false;

  @override
  void initState() {
    super.initState();
    // Initialize controllers
    _nameController = TextEditingController();
    _sexController = TextEditingController();
    _birthDateController = TextEditingController();
    _mbtiController = TextEditingController();
    _companyController = TextEditingController();
    _divisionController = TextEditingController();
    _departmentController = TextEditingController();
    _sectionController = TextEditingController();
    _roleController = TextEditingController();

    // Load initial data from the current user profile
    final appUser = ref.read(appUserProvider);
    if (appUser != null) {
      _populateFormFields(appUser);
      _currentPrompt = appUser.prompt; // Initial prompt from AppUser state
    } else {
      // If user data is not available (should not happen if screen is protected)
      // Potentially fetch it or show error. For now, assume it's available.
      print(
          "EditMyAgentScreen: AppUser is null, form may not populate correctly.");
    }
    // Optionally fetch fresh prompt if needed, though AppUser should be up-to-date
    // _fetchPrompt();
  }

  void _populateFormFields(AppUser user) {
    _nameController.text = user.name;
    _sexController.text = user.sex;
    _birthDateController.text =
        user.birthDate.toIso8601String().split('T').first;
    _mbtiController.text = user.mbti ?? '';
    _companyController.text = user.company ?? '';
    _divisionController.text = user.division ?? '';
    _departmentController.text = user.department ?? '';
    _sectionController.text = user.section ?? '';
    _roleController.text = user.role ?? '';
  }

  Future<void> _fetchPrompt() async {
    setState(() => _isFetchingPrompt = true);
    try {
      final prompt = await ref
          .read(authStateNotifierProvider.notifier)
          .fetchUserAgentPrompt();
      if (mounted) {
        setState(() {
          _currentPrompt = prompt;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to fetch prompt: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isFetchingPrompt = false);
      }
    }
  }

  Future<void> _submitUpdate() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      try {
        DateTime? birthDate;
        if (_birthDateController.text.isNotEmpty) {
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
        }

        final updateData = UserProfileUpdateData(
          name: _nameController.text.trim(),
          sex: _sexController.text.trim(),
          birthDate: birthDate,
          mbti: _mbtiController.text.trim().isEmpty
              ? null
              : _mbtiController.text.trim(),
          company: _companyController.text.trim().isEmpty
              ? null
              : _companyController.text.trim(),
          division: _divisionController.text.trim().isEmpty
              ? null
              : _divisionController.text.trim(),
          department: _departmentController.text.trim().isEmpty
              ? null
              : _departmentController.text.trim(),
          section: _sectionController.text.trim().isEmpty
              ? null
              : _sectionController.text.trim(),
          role: _roleController.text.trim().isEmpty
              ? null
              : _roleController.text.trim(),
        );

        await ref
            .read(authStateNotifierProvider.notifier)
            .updateUserProfile(updateData);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text(
                    'Profile updated successfully! Prompt may have been regenerated.')),
          );
          // Refresh prompt display after update
          final updatedUser = ref.read(appUserProvider);
          if (updatedUser != null) {
            _currentPrompt = updatedUser.prompt;
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Profile update failed: ${e.toString()}')),
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
    _nameController.dispose();
    _sexController.dispose();
    _birthDateController.dispose();
    _mbtiController.dispose();
    _companyController.dispose();
    _divisionController.dispose();
    _departmentController.dispose();
    _sectionController.dispose();
    _roleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Listen to AppUser provider to auto-update form if state changes externally (e.g. after login)
    // This might be redundant if screen is only accessed when user is loaded, but good for robustness.
    ref.listen<AppUser?>(appUserProvider, (previousUser, newUser) {
      if (newUser != null && mounted) {
        _populateFormFields(newUser);
        setState(() {
          _currentPrompt = newUser.prompt;
        });
      }
    });

    final appUser =
        ref.watch(appUserProvider); // For initial build and prompt display

    return Scaffold(
      appBar: AppBar(title: const Text('Edit My Agent Profile')),
      body: appUser == null
          ? const Center(child: Text("Loading user data or not logged in..."))
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: ListView(
                  children: <Widget>[
                    Text("User ID: ${appUser.userId}",
                        style: Theme.of(context).textTheme.bodySmall),
                    Text("Email: ${appUser.email}",
                        style: Theme.of(context).textTheme.bodySmall),
                    const SizedBox(height: 10),
                    TextFormField(
                        controller: _nameController,
                        decoration:
                            const InputDecoration(labelText: 'Full Name'),
                        validator: (v) => v!.isEmpty ? 'Required' : null),
                    TextFormField(
                        controller: _sexController,
                        decoration: const InputDecoration(labelText: 'Sex'),
                        validator: (v) => v!.isEmpty ? 'Required' : null),
                    TextFormField(
                      controller: _birthDateController,
                      decoration: const InputDecoration(
                          labelText: 'Birth Date (YYYY-MM-DD)'),
                      keyboardType: TextInputType.datetime,
                      validator: (v) {
                        if (v!.isEmpty) return 'Required';
                        try {
                          DateTime.parse(v);
                          return null;
                        } catch (e) {
                          return 'Invalid date';
                        }
                      },
                      onTap: () async {
                        FocusScope.of(context).requestFocus(FocusNode());
                        DateTime? picked = await showDatePicker(
                            context: context,
                            initialDate:
                                DateTime.tryParse(_birthDateController.text) ??
                                    DateTime.now(),
                            firstDate: DateTime(1900),
                            lastDate: DateTime.now());
                        if (picked != null)
                          _birthDateController.text =
                              picked.toIso8601String().split('T').first;
                      },
                    ),
                    TextFormField(
                        controller: _mbtiController,
                        decoration: const InputDecoration(
                            labelText: 'MBTI (Optional)')),
                    TextFormField(
                        controller: _companyController,
                        decoration: const InputDecoration(
                            labelText: 'Company (Optional)')),
                    TextFormField(
                        controller: _divisionController,
                        decoration: const InputDecoration(
                            labelText: 'Division (Optional)')),
                    TextFormField(
                        controller: _departmentController,
                        decoration: const InputDecoration(
                            labelText: 'Department (Optional)')),
                    TextFormField(
                        controller: _sectionController,
                        decoration: const InputDecoration(
                            labelText: 'Section/Team (Optional)')),
                    TextFormField(
                        controller: _roleController,
                        decoration: const InputDecoration(
                            labelText: 'Role (Optional)')),
                    const SizedBox(height: 20),
                    _isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : ElevatedButton(
                            onPressed: _submitUpdate,
                            child: const Text('Update Profile')),
                    const SizedBox(height: 20),
                    const Divider(),
                    Text("Current Agent Prompt:",
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    _isFetchingPrompt
                        ? const Center(child: CircularProgressIndicator())
                        : Container(
                            padding: const EdgeInsets.all(8.0),
                            color: Colors.grey[200],
                            child: Text(_currentPrompt ??
                                "Prompt not available or not generated yet."),
                          ),
                    TextButton(
                        onPressed: _fetchPrompt,
                        child: const Text("Refresh Prompt Display")),
                  ],
                ),
              ),
            ),
    );
  }
}
