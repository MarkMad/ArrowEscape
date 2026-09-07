import 'dart:io';
import 'package:arrowescape/core/app_themes.dart';
import 'package:arrowescape/data/models/arrow.dart';
import 'package:arrowescape/data/models/level.dart';
import 'package:arrowescape/data/repositories/progress_repository.dart';
import 'package:arrowescape/game/game_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

void main() {
  GameState board({bool assist = true}) => GameState(
    level: LevelModel(
      levelNumber: 1,
      gridSize: 5,
      arrows: [
        ArrowModel(
          id: 'a',
          row: 1,
          col: 1,
          direction: ArrowDirection.up,
          path: [
            [1, 1],
            [2, 1],
          ],
        ),
        ArrowModel(
          id: 'b',
          row: 1,
          col: 3,
          direction: ArrowDirection.up,
          path: [
            [1, 3],
            [2, 3],
          ],
        ),
      ],
    ),
    theme: GameTheme.classic,
    assistMode: assist,
    onLevelComplete: () {},
    onGameOver: () {},
    onLifeLost: () {},
  );
  test(
    'assist rejects ambiguity, occupied cells, diagonal taps and inactive arrows',
    () {
      final state = board();
      addTearDown(state.dispose);
      expect(state.assistedArrowAt(1, 0), 'a');
      expect(state.assistedArrowAt(2, 0), 'a');
      expect(state.assistedArrowAt(1, 2), isNull);
      expect(state.assistedArrowAt(1, 1), isNull);
      expect(state.assistedArrowAt(0, 0), isNull);
      expect(state.assistedArrowAt(-1, 1), isNull);
      expect(state.assistedArrowAt(5, 1), isNull);
      state.tapArrow('a');
      expect(state.assistedArrowAt(1, 0), isNull);
      expect(state.assistedArrowAt(1, 2), 'b');
      state.forceGameOver();
      expect(state.assistedArrowAt(1, 2), isNull);
    },
  );
  test('assist is inactive when disabled', () {
    final state = board(assist: false);
    addTearDown(state.dispose);
    expect(state.assistedArrowAt(1, 0), isNull);
  });
  test(
    'assist and rainbow persist without changing existing progress',
    () async {
      final directory = await Directory.systemTemp.createTemp('arrow-assist-');
      Hive.init(directory.path);
      try {
        final first = await ProgressRepository.create();
        expect(first.assistMode, isFalse);
        await first.setCurrentLevel(12);
        await first.toggleAssistMode();
        await first.unlockSkins('THANKYOU');
        await first.setTheme(GameTheme.rainbow);
        first.dispose();
        await Hive.close();
        final restored = await ProgressRepository.create();
        expect(restored.assistMode, isTrue);
        expect(restored.selectedTheme, GameTheme.rainbow);
        expect(restored.skinsUnlocked, isTrue);
        expect(restored.currentLevel, 12);
        expect(
          AppThemes.getThemeColors(
            restored.selectedTheme,
          ).arrowPalette!.toSet(),
          hasLength(7),
        );
        restored.dispose();
      } finally {
        await Hive.close();
        await directory.delete(recursive: true);
      }
    },
  );
}
