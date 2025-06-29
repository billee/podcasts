class UserProfile {
  final String name;
  final String username;
  final String email;
  final String phoneNumber;
  final String workLocation;
  final String occupation;
  final String gender;
  final String language;
  final String educationalAttainment;
  final bool isMarried;
  final bool hasChildren;
  final int birthYear;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const UserProfile({
    required this.name,
    required this.username,
    this.email='',
    this.phoneNumber='',
    required this.workLocation,
    required this.occupation,
    required this.gender,
    required this.language,
    required this.educationalAttainment,
    required this.isMarried,
    required this.hasChildren,
    required this.birthYear,
    this.createdAt,
    this.updatedAt,
  });

  int get age => DateTime.now().year - birthYear;

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'username': username,
      'email': email,
      'phoneNumber': phoneNumber,
      'workLocation': workLocation,
      'occupation': occupation,
      'gender': gender,
      'language': language,
      'educationalAttainment': educationalAttainment,
      'isMarried': isMarried,
      'hasChildren': hasChildren,
      'birthYear': birthYear,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      name: json['name'] ?? '',
      username: json['username'] ?? '',
      email: json['email'] ?? '',
      phoneNumber: json['phoneNumber'] ?? '',
      workLocation: json['workLocation'] ?? '',
      occupation: json['occupation'] ?? '',
      gender: json['gender'] ?? '',
      language: json['language'] ?? 'english',
      educationalAttainment: json['educationalAttainment'] ?? '',
      isMarried: json['isMarried'] ?? false,
      hasChildren: json['hasChildren'] ?? false,
      birthYear: json['birthYear'] ?? DateTime.now().year - 25,
      createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt']) : null,
      updatedAt: json['updatedAt'] != null ? DateTime.parse(json['updatedAt']) : null,
    );
  }

  UserProfile copyWith({
    String? name,
    String? username, // Add this
    String? email,
    String? phoneNumber,
    String? workLocation,
    String? occupation,
    String? gender,
    String? language,
    String? educationalAttainment,
    bool? isMarried,
    bool? hasChildren,
    int? birthYear,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserProfile(
      name: name ?? this.name,
      username: username ?? this.username, // Add this
      email: email ?? this.email,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      workLocation: workLocation ?? this.workLocation,
      occupation: occupation ?? this.occupation,
      gender: gender ?? this.gender,
      language: language ?? this.language,
      educationalAttainment: educationalAttainment ?? this.educationalAttainment,
      isMarried: isMarried ?? this.isMarried,
      hasChildren: hasChildren ?? this.hasChildren,
      birthYear: birthYear ?? this.birthYear,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}