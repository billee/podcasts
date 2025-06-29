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

      return snapshot.docs
          .map((doc) => OFWContact.fromJson({...doc.data(), 'id': doc.id}))
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
      'relationship': contact.relationship,
      'phoneNumber': contact.phoneNumber,
      'profileImage': contact.profileImage,
      'languages': contact.languages,
      'status': contact.status,
    });
  }

  // Update online status
  static Future<void> updateOnlineStatus(String userId, bool isOnline) async {
    await _firestore.collection('users').doc(userId).update({
      'isOnline': isOnline,
      'lastSeen': isOnline ? null : FieldValue.serverTimestamp(),
    });
  }
}
