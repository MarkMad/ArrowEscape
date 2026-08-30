import 'dart:async';
import 'dart:convert';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import '../models/level.dart';
import '../level_generator/level_generator.dart';

@pragma('vm:entry-point')
void _generateLevelIsolateEntry(Map<String, dynamic> message) {
  final port = message['port'] as SendPort;
  try {
    final level = LevelGenerator.generateLevel(message['level'] as int);
    port.send(level);
  } catch (_) {
    port.send(null);
  }
}

/// Runs the generator in a short-lived isolate that is killed on timeout,
/// so slow generations don't pile up in the background.
Future<LevelModel?> _generateInIsolate(int levelNumber, Duration timeout) async {
  final port = ReceivePort();
  final errorPort = ReceivePort();
  Isolate? isolate;
  try {
    isolate = await Isolate.spawn(
      _generateLevelIsolateEntry,
      {'port': port.sendPort, 'level': levelNumber},
      errorsAreFatal: true,
      onError: errorPort.sendPort,
    );
    final result = await (port.first as Future<LevelModel?>)
        .timeout(timeout, onTimeout: () => null);
    return result;
  } catch (e) {
    debugPrint('Isolate generation failed for level $levelNumber: $e');
    return null;
  } finally {
    isolate?.kill(priority: Isolate.beforeNextEvent);
    port.close();
    errorPort.close();
  }
}

class LevelRepository {
  static const int cacheVersion = LevelModel.currentVersion;

  late Box _cacheBox;
  final Map<int, LevelModel> _cache = {};
  final Set<int> _generating = {};

  LevelRepository._();

  static Future<LevelRepository> create() async {
    final repo = LevelRepository._();
    await repo._init();
    return repo;
  }

  Future<void> _init() async {
    _cacheBox = await Hive.openBox('levelCache');
    final storedVersion = _cacheBox.get('generator_version');
    if (storedVersion != cacheVersion) {
      await _cacheBox.clear();
      await _cacheBox.put('generator_version', cacheVersion);
    }
  }

  LevelModel? _tryLoadCached(int levelNumber) {
    if (_cache.containsKey(levelNumber)) {
      final cached = _cache[levelNumber]!;
      if (cached.version == cacheVersion) return cached;
      _cache.remove(levelNumber);
    }

    final jsonStr = _cacheBox.get('cached_level_$levelNumber');
    if (jsonStr != null) {
      try {
        final decoded = jsonDecode(jsonStr);
        if (decoded is Map<String, dynamic>) {
          final level = LevelModel.fromJson(decoded);
          if (level.version == cacheVersion) {
            _cache[levelNumber] = level;
            return level;
          }
        }
      } catch (e) {
        debugPrint('Error decoding cached level: $e');
      }
      _cacheBox.delete('cached_level_$levelNumber');
    }
    return null;
  }

  LevelModel getLevel(int levelNumber) {
    final cached = _tryLoadCached(levelNumber);
    if (cached != null) return cached;

    final level = LevelGenerator.generateLevel(levelNumber);
    _cache[levelNumber] = level;
    _saveToDisk(levelNumber, level);
    return level;
  }

  Future<void> preGenerateAsync(int levelNumber) async {
    if (isCached(levelNumber)) return;
    if (_generating.contains(levelNumber)) return;
    _generating.add(levelNumber);

    try {
      final cached = _tryLoadCached(levelNumber);
      if (cached != null) return;

      final level = await _generateInIsolate(levelNumber, const Duration(seconds: 4));
      if (level != null) {
        _cache[levelNumber] = level;
        _saveToDisk(levelNumber, level);
      }
    } catch (e) {
      debugPrint('Async pre-generation error for level $levelNumber: $e');
    } finally {
      _generating.remove(levelNumber);
    }
  }

  Future<void> preGenerateRangeAsync(int from, int count) async {
    for (int i = from; i < from + count; i++) {
      unawaited(preGenerateAsync(i));
    }
  }

  Future<LevelModel> getLevelAsync(int levelNumber, {bool preGenerateNext = true}) async {
    if (preGenerateNext) {
      preGenerateRangeAsync(levelNumber + 1, 3);
    }

    final cached = _tryLoadCached(levelNumber);
    if (cached != null) return cached;

    try {
      final level = await _generateInIsolate(levelNumber, const Duration(seconds: 3));
      if (level == null) {
        debugPrint('Isolate generation failed/timed out, generating synchronously');
        return getLevel(levelNumber);
      }
      _cache[levelNumber] = level;
      _saveToDisk(levelNumber, level);
      return level;
    } catch (e) {
      debugPrint('Isolate generation failed/timed out, generating synchronously: $e');
      return getLevel(levelNumber);
    }
  }

  bool isCached(int levelNumber) {
    return _tryLoadCached(levelNumber) != null;
  }

  void _saveToDisk(int levelNumber, LevelModel level) {
    try {
      _cacheBox.put('cached_level_$levelNumber', jsonEncode(level.toJson()));
    } catch (e) {
      debugPrint('Error saving level to disk: $e');
    }
  }
}