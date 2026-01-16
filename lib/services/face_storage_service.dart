import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class FaceStorageService {
  static const String _embeddingsKey = 'enrolled_face_embeddings';
  static const String _userNamesKey = 'enrolled_user_names';

  /// Enroll a new user with their face embedding
  Future<void> enrollUser(
    String userId,
    String userName,
    List<double> embedding,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Get existing embeddings and names
      final embeddingsJson = prefs.getString(_embeddingsKey) ?? '{}';
      final namesJson = prefs.getString(_userNamesKey) ?? '{}';

      Map<String, dynamic> embeddings = jsonDecode(embeddingsJson);
      Map<String, dynamic> names = jsonDecode(namesJson);

      // Store embedding as list
      embeddings[userId] = embedding;
      names[userId] = userName;

      // Save back to SharedPreferences
      await prefs.setString(_embeddingsKey, jsonEncode(embeddings));
      await prefs.setString(_userNamesKey, jsonEncode(names));

      print('User $userId ($userName) enrolled successfully');
    } catch (e) {
      print('Error enrolling user: $e');
      rethrow;
    }
  }

  /// Get enrolled user's embedding
  Future<List<double>?> getEnrolledUserEmbedding(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final embeddingsJson = prefs.getString(_embeddingsKey) ?? '{}';
      Map<String, dynamic> embeddings = jsonDecode(embeddingsJson);

      if (embeddings.containsKey(userId)) {
        return List<double>.from(embeddings[userId]);
      }
      return null;
    } catch (e) {
      print('Error getting user embedding: $e');
      return null;
    }
  }

  /// Get all enrolled users with their embeddings
  Future<Map<String, List<double>>> getAllEnrolledEmbeddings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final embeddingsJson = prefs.getString(_embeddingsKey) ?? '{}';
      Map<String, dynamic> embeddingsData = jsonDecode(embeddingsJson);

      Map<String, List<double>> embeddings = {};
      embeddingsData.forEach((userId, embeddingData) {
        embeddings[userId] = List<double>.from(embeddingData);
      });

      return embeddings;
    } catch (e) {
      print('Error getting all embeddings: $e');
      return {};
    }
  }

  /// Get all enrolled user IDs
  Future<List<String>> getAllEnrolledUserIds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final embeddingsJson = prefs.getString(_embeddingsKey) ?? '{}';
      Map<String, dynamic> embeddings = jsonDecode(embeddingsJson);
      return embeddings.keys.toList();
    } catch (e) {
      print('Error getting user IDs: $e');
      return [];
    }
  }

  /// Get user name by ID
  Future<String?> getUserName(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final namesJson = prefs.getString(_userNamesKey) ?? '{}';
      Map<String, dynamic> names = jsonDecode(namesJson);
      return names[userId];
    } catch (e) {
      print('Error getting user name: $e');
      return null;
    }
  }

  /// Get all user names with their IDs
  Future<Map<String, String>> getAllUserNames() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final namesJson = prefs.getString(_userNamesKey) ?? '{}';
      Map<String, dynamic> namesData = jsonDecode(namesJson);

      Map<String, String> names = {};
      namesData.forEach((userId, userName) {
        names[userId] = userName.toString();
      });

      return names;
    } catch (e) {
      print('Error getting all user names: $e');
      return {};
    }
  }

  /// Delete a user
  Future<bool> deleteUser(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final embeddingsJson = prefs.getString(_embeddingsKey) ?? '{}';
      final namesJson = prefs.getString(_userNamesKey) ?? '{}';

      Map<String, dynamic> embeddings = jsonDecode(embeddingsJson);
      Map<String, dynamic> names = jsonDecode(namesJson);

      embeddings.remove(userId);
      names.remove(userId);

      await prefs.setString(_embeddingsKey, jsonEncode(embeddings));
      await prefs.setString(_userNamesKey, jsonEncode(names));

      print('User $userId deleted successfully');
      return true;
    } catch (e) {
      print('Error deleting user: $e');
      return false;
    }
  }

  /// Clear all enrolled users
  Future<void> clearAllUsers() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_embeddingsKey);
    await prefs.remove(_userNamesKey);
    print('All users cleared');
  }

  /// Get count of enrolled users
  Future<int> getEnrolledUserCount() async {
    final userIds = await getAllEnrolledUserIds();
    return userIds.length;
  }
}
