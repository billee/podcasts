// lib/services/contact_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:kapwa_companion_basic/models/ofw_contact.dart';

class ContactService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get user's family contacts
  static Future<List<OFWContact>> getFamilyContacts(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('family_contacts')
          .get();

      // Use .fromMap now that it's correctly defined and matches Firestore structure
      return snapshot.docs
          .map((doc) => OFWContact.fromMap(doc.data(), doc.id))
          .toList();
    } catch (e) {
      print('Error getting family contacts: $e');
      return [];
    }
  }

  // Add a family member
  static Future<void> addFamilyContact(
      String userId, OFWContact contact) async {
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('family_contacts')
        .doc(contact.id)
        .set({
      'name': contact.name,
      'relationship': contact.relationship, // Now correctly accessed
      'phoneNumber': contact.phoneNumber,   // Now correctly accessed
      'profileImage': contact.profileImage,
      'languages': contact.languages,       // Now correctly accessed
      'status': contact.status,             // Now correctly accessed
      'phone': contact.phone, // Also include the original 'phone' field if it's still relevant
      'specialization': contact.specialization,
      'isOnline': contact.isOnline, // Also store online status, though it's typically dynamic
    });
  }

  // Update online status (this method already looks correct)
  static Future<void> updateOnlineStatus(String userId, bool isOnline) async {
    await _firestore.collection('users').doc(userId).update({
      'isOnline': isOnline,
      'lastSeen': isOnline ? null : FieldValue.serverTimestamp(),
    });
  }
}
