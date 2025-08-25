// lib/services/daily_audio_selection_service.dart

import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:logging/logging.dart';
import 'package:kapwa_companion_basic/core/config.dart';

class DailyAudioSelectionService {
  static final Logger _logger = Logger('DailyAudioSelectionService');
  
  /// Get daily random selection of audio files for trial users
  /// Returns a list of randomly selected audio files that refreshes daily
  static Future<List<String>> getDailyRandomSelection({
    required List<String> allAudioFiles,
    required String audioType, // 'podcast' or 'story'
    required int selectionLimit,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final today = _getTodayDateString();
      final cacheKey = 'daily_${audioType}_selection_$today';
      final dateKey = 'daily_${audioType}_date';
      
      // Check if we have a cached selection for today
      final cachedSelection = prefs.getStringList(cacheKey);
      final cachedDate = prefs.getString(dateKey);
      
      if (cachedSelection != null && cachedDate == today && cachedSelection.isNotEmpty) {
        _logger.info('Using cached daily $audioType selection for $today: ${cachedSelection.length} items');
        return cachedSelection;
      }
      
      // Generate new random selection for today
      final randomSelection = _generateRandomSelection(allAudioFiles, selectionLimit);
      
      // Cache the selection for today
      await prefs.setStringList(cacheKey, randomSelection);
      await prefs.setString(dateKey, today);
      
      // Clean up old cache entries (keep only today's)
      await _cleanupOldCacheEntries(prefs, audioType, today);
      
      _logger.info('Generated new daily $audioType selection for $today: ${randomSelection.length} items');
      return randomSelection;
      
    } catch (e) {
      _logger.severe('Error getting daily random selection for $audioType: $e');
      // Fallback to simple random selection without caching
      return _generateRandomSelection(allAudioFiles, selectionLimit);
    }
  }
  
  /// Generate a random selection from the available audio files
  static List<String> _generateRandomSelection(List<String> allFiles, int limit) {
    if (allFiles.isEmpty) return [];
    
    final random = Random();
    final shuffled = List<String>.from(allFiles);
    shuffled.shuffle(random);
    
    // Take up to the limit, but not more than available files
    final selectionCount = limit.clamp(0, shuffled.length);
    return shuffled.take(selectionCount).toList();
  }
  
  /// Get today's date as a string for caching purposes
  static String _getTodayDateString() {
    final now = AppConfig.currentDateTime;
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }
  
  /// Clean up old cache entries to prevent storage bloat
  static Future<void> _cleanupOldCacheEntries(SharedPreferences prefs, String audioType, String today) async {
    try {
      final keys = prefs.getKeys();
      final keysToRemove = keys.where((key) => 
        key.startsWith('daily_${audioType}_selection_') && 
        !key.endsWith(today)
      ).toList();
      
      for (final key in keysToRemove) {
        await prefs.remove(key);
      }
      
      if (keysToRemove.isNotEmpty) {
        _logger.info('Cleaned up ${keysToRemove.length} old cache entries for $audioType');
      }
    } catch (e) {
      _logger.warning('Error cleaning up old cache entries: $e');
    }
  }
  
  /// Force refresh the daily selection (useful for testing or manual refresh)
  static Future<List<String>> forceRefreshDailySelection({
    required List<String> allAudioFiles,
    required String audioType,
    required int selectionLimit,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final today = _getTodayDateString();
      final cacheKey = 'daily_${audioType}_selection_$today';
      final dateKey = 'daily_${audioType}_date';
      
      // Remove existing cache
      await prefs.remove(cacheKey);
      await prefs.remove(dateKey);
      
      _logger.info('Forced refresh of daily $audioType selection');
      
      // Generate new selection
      return await getDailyRandomSelection(
        allAudioFiles: allAudioFiles,
        audioType: audioType,
        selectionLimit: selectionLimit,
      );
    } catch (e) {
      _logger.severe('Error forcing refresh of daily selection: $e');
      return _generateRandomSelection(allAudioFiles, selectionLimit);
    }
  }
  
  /// Get info about current daily selection (for debugging/admin purposes)
  static Future<Map<String, dynamic>> getDailySelectionInfo(String audioType) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final today = _getTodayDateString();
      final cacheKey = 'daily_${audioType}_selection_$today';
      final dateKey = 'daily_${audioType}_date';
      
      final cachedSelection = prefs.getStringList(cacheKey);
      final cachedDate = prefs.getString(dateKey);
      
      return {
        'audioType': audioType,
        'today': today,
        'cachedDate': cachedDate,
        'hasCache': cachedSelection != null,
        'selectionCount': cachedSelection?.length ?? 0,
        'selection': cachedSelection ?? [],
      };
    } catch (e) {
      _logger.severe('Error getting daily selection info: $e');
      return {
        'audioType': audioType,
        'error': e.toString(),
      };
    }
  }
}