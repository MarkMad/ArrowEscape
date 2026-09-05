import 'dart:convert';
import 'dart:io';

import 'package:arrowescape/data/level_generator/solver.dart';
import 'package:arrowescape/data/models/level.dart';
import 'package:arrowescape/data/repositories/level_repository.dart';
import 'package:arrowescape/data/repositories/progress_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

void main() {
  late Directory directory;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('arrowescape-cache-');
    Hive.init(directory.path);
  });
  tearDown(() async {
    await Hive.close();
    await directory.delete(recursive: true);
  });

  test(
    'generator upgrade invalidates old boards and preserves progress',
    () async {
      final progress = await ProgressRepository.create();
      await progress.setCurrentLevel(512);
      await progress.toggleHeartRemover();
      expect(await progress.unlockSkins('THANKYOU'), isTrue);
      progress.dispose();
      final box = await Hive.openBox('levelCache');
      await box.put('generator_version', LevelModel.currentVersion - 1);
      await box.put(
        'cached_level_512',
        jsonEncode(
          LevelModel(
            levelNumber: 512,
            gridSize: 3,
            arrows: [],
            version: LevelModel.currentVersion - 1,
          ).toJson(),
        ),
      );
      await Hive.close();

      final repository = await LevelRepository.create();
      expect(repository.isCached(512), isFalse);
      final restored = await ProgressRepository.create();
      expect(restored.currentLevel, 512);
      expect(restored.heartRemover, isTrue);
      expect(restored.skinsUnlocked, isTrue);
      restored.dispose();
    },
  );

  test(
    'async generation caches a solvable board for subsequent requests',
    () async {
      final repository = await LevelRepository.create();
      final level = await repository.getLevelAsync(512, preGenerateNext: false);
      expect(LevelSolver.solve(level), isNotNull);
      expect(repository.isCached(512), isTrue);
      final cached = await repository.getLevelAsync(
        512,
        preGenerateNext: false,
      );
      expect(identical(level, cached), isTrue);
      expect(level.version, LevelModel.currentVersion);
    },
  );
}
