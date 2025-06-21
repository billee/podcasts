// lib/models/ofw_contact.dart
class OFWContact {
  final String id; // Unique ID for signaling
  final String name;
  final String phone;
  final String specialization; // e.g., "Caregiver", "Construction Worker"
  final String? profileImage; // URL to profile image, can be null

  OFWContact({
    required this.id,
    required this.name,
    required this.phone,
    this.specialization = '', // Default to empty string
    this.profileImage,
  });

  // You might want a factory constructor for JSON deserialization later
  factory OFWContact.fromJson(Map<String, dynamic> json) {
    return OFWContact(
      id: json['id'] as String,
      name: json['name'] as String,
      phone: json['phone'] as String,
      specialization: json['specialization'] as String? ?? '',
      profileImage: json['profileImage'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'specialization': specialization,
      'profileImage': profileImage,
    };
  }
}
