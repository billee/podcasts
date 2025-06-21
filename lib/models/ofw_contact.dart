// lib/models/ofw_contact.dart
class OFWContact {
  final String id;
  final String name;
  final String relationship; // "Mother", "Father", "Sister", "Brother", etc.
  final String? profileImage;
  final bool isOnline;
  final String? lastSeen;
  final String phoneNumber; // WhatsApp uses phone numbers
  final List<String> languages;
  final String? status; // WhatsApp status message

  OFWContact({
    required this.id,
    required this.name,
    required this.relationship,
    this.profileImage,
    required this.isOnline,
    this.lastSeen,
    required this.phoneNumber,
    required this.languages,
    this.status,
  });

  factory OFWContact.fromJson(Map<String, dynamic> json) {
    return OFWContact(
      id: json['id'],
      name: json['name'],
      relationship: json['relationship'],
      profileImage: json['profileImage'],
      isOnline: json['isOnline'] ?? false,
      lastSeen: json['lastSeen'],
      phoneNumber: json['phoneNumber'],
      languages: List<String>.from(json['languages'] ?? []),
      status: json['status'],
    );
  }
}
