// lib/models/ofw_contact.dart
import 'package:cloud_firestore/cloud_firestore.dart'; // Import for Timestamp if needed in fromMap

class OFWContact {
  final String id;
  final String name;
  final String? phone; // Original phone, now optional
  final String specialization;
  final String? profileImage;
  final DateTime? lastSeen;
  final bool isOnline;

  // New fields added to match ContactService expectations
  final String? relationship;
  final String? phoneNumber; // Added explicitly to match service error
  final List<String>? languages;
  final String? status;

  OFWContact({
    required this.id,
    required this.name,
    this.phone, // Made optional
    required this.specialization,
    this.profileImage,
    this.lastSeen,
    this.isOnline = false,
    // Initialize new fields
    this.relationship,
    this.phoneNumber,
    this.languages,
    this.status,
  });

  // Convert from Firestore document
  factory OFWContact.fromMap(Map<String, dynamic> map, String id) {
    return OFWContact(
      id: id,
      name: map['name'] ?? '',
      phone: map['phone'], // Still support original 'phone' field
      specialization: map['specialization'] ?? '',
      profileImage: map['profileImage'],
      lastSeen: (map['lastSeen'] is Timestamp) ? (map['lastSeen'] as Timestamp).toDate() : null, // Handle Timestamp
      isOnline: map['isOnline'] ?? false,
      // Map new fields
      relationship: map['relationship'],
      phoneNumber: map['phoneNumber'],
      languages: (map['languages'] as List<dynamic>?)?.map((e) => e.toString()).toList(),
      status: map['status'],
    );
  }

  // Convert to Firestore document
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'phone': phone,
      'specialization': specialization,
      'profileImage': profileImage,
      'lastSeen': lastSeen,
      'isOnline': isOnline,
      // Include new fields
      'relationship': relationship,
      'phoneNumber': phoneNumber,
      'languages': languages,
      'status': status,
    };
  }

  OFWContact copyWith({
    String? id,
    String? name,
    String? phone,
    String? specialization,
    String? profileImage,
    DateTime? lastSeen,
    bool? isOnline,
    // Add new fields to copyWith
    String? relationship,
    String? phoneNumber,
    List<String>? languages,
    String? status,
  }) {
    return OFWContact(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      specialization: specialization ?? this.specialization,
      profileImage: profileImage ?? this.profileImage,
      lastSeen: lastSeen ?? this.lastSeen,
      isOnline: isOnline ?? this.isOnline,
      // Copy new fields
      relationship: relationship ?? this.relationship,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      languages: languages ?? this.languages,
      status: status ?? this.status,
    );
  }
}
