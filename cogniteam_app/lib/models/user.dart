import 'package:flutter/foundation.dart'; // For @required, or use 'meta' package

// Corresponds to UserResponse in the backend
class AppUser {
  final String userId; // Firebase UID
  final String email;
  final String name;
  final String sex;
  final DateTime birthDate; // Store as DateTime, convert from/to ISO string for API
  final String? mbti;
  final String? company;
  final String? division;
  final String? department;
  final String? section;
  final String? role;
  final String? prompt;

  AppUser({
    required this.userId,
    required this.email,
    required this.name,
    required this.sex,
    required this.birthDate,
    this.mbti,
    this.company,
    this.division,
    this.department,
    this.section,
    this.role,
    this.prompt,
  });

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      userId: json['user_id'] as String,
      email: json['email'] as String,
      name: json['name'] as String,
      sex: json['sex'] as String,
      birthDate: DateTime.parse(json['birth_date'] as String),
      mbti: json['mbti'] as String?,
      company: json['company'] as String?,
      division: json['division'] as String?,
      department: json['department'] as String?,
      section: json['section'] as String?,
      role: json['role'] as String?,
      prompt: json['prompt'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'email': email,
      'name': name,
      'sex': sex,
      'birth_date': birthDate.toIso8601String().split('T').first, // Send only YYYY-MM-DD
      'mbti': mbti,
      'company': company,
      'division': division,
      'department': department,
      'section': section,
      'role': role,
      'prompt': prompt,
    };
  }

  // For UserCreate model on signup (subset of fields, plus password)
  // Password is not part of this model, handled separately in forms/services.
  Map<String, dynamic> toJsonForSignup() {
     return {
      // 'email': email, // email is part of UserCreate, handled by auth_service
      'name': name,
      'sex': sex,
      'birth_date': birthDate.toIso8601String().split('T').first,
      'mbti': mbti,
      'company': company,
      'division': division,
      'department': department,
      'section': section,
      'role': role,
      // Prompt is generated backend, password is not sent in this map
    };
  }


  AppUser copyWith({
    String? userId,
    String? email,
    String? name,
    String? sex,
    DateTime? birthDate,
    String? mbti,
    String? company,
    String? division,
    String? department,
    String? section,
    String? role,
    String? prompt,
  }) {
    return AppUser(
      userId: userId ?? this.userId,
      email: email ?? this.email,
      name: name ?? this.name,
      sex: sex ?? this.sex,
      birthDate: birthDate ?? this.birthDate,
      mbti: mbti ?? this.mbti,
      company: company ?? this.company,
      division: division ?? this.division,
      department: department ?? this.department,
      section: section ?? this.section,
      role: role ?? this.role,
      prompt: prompt ?? this.prompt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppUser &&
          runtimeType == other.runtimeType &&
          userId == other.userId &&
          email == other.email;

  @override
  int get hashCode => userId.hashCode ^ email.hashCode;

  @override
  String toString() {
    return 'AppUser{userId: $userId, email: $email, name: $name}';
  }
}

// Model for what backend's /auth/signup endpoint expects (UserCreate)
// This is distinct from AppUser which is more like UserResponse
class UserCreationData {
  final String email;
  final String password; // Only for creation, not stored in AppUser
  final String name;
  final String sex;
  final DateTime birthDate;
  final String? mbti;
  final String? company;
  final String? division;
  final String? department;
  final String? section;
  final String? role;

  UserCreationData({
    required this.email,
    required this.password,
    required this.name,
    required this.sex,
    required this.birthDate,
    this.mbti,
    this.company,
    this.division,
    this.department,
    this.section,
    this.role,
  });

  Map<String, dynamic> toJson() {
    return {
      'email': email,
      'password': password,
      'name': name,
      'sex': sex,
      'birth_date': birthDate.toIso8601String().split('T').first, // YYYY-MM-DD
      'mbti': mbti,
      'company': company,
      'division': division,
      'department': department,
      'section': section,
      'role': role,
    };
  }
}
```
