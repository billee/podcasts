// lib/services/contact_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:kapwa_companion_basic/models/ofw_contact.dart';
import 'package:logging/logging.dart';

class ContactService {
  static final Logger _logger = Logger('ContactService');
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Method to add a family contact
  static Future<void> addFamilyContact(
      String userId, OFWContact contact) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('family_contacts')
          .doc(contact.id)
          .set(contact.toMap());
      _logger.info('Contact added: ${contact.id} for user $userId');
    } catch (e) {
      _logger.severe('Error adding contact: $e');
      rethrow;
    }
  }

  // Method to delete a family contact
  static Future<void> deleteFamilyContact(
      String userId, String contactId) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('family_contacts')
          .doc(contactId)
          .delete();
      _logger.info('Contact deleted: $contactId for user $userId');
    } catch (e) {
      _logger.severe('Error deleting contact: $e');
      rethrow;
    }
  }

  // You might have other methods here, e.g., getContactDetails, updateContact, etc.
}

// This extension provides the stream for real-time updates
extension ContactServiceStream on ContactService {
  static Stream<List<OFWContact>> getFamilyContactsStream(String userId) {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('family_contacts')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => OFWContact.fromMap(doc.data(), doc.id))
            .toList());
  }
}
