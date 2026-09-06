import 'package:arrowescape/core/app_themes.dart';
import 'package:arrowescape/data/models/arrow.dart';
import 'package:arrowescape/data/models/level.dart';
import 'package:arrowescape/game/game_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'timeout defers completion until continue and callbacks are idempotent',
    () {
      var completions = 0;
      var gameOvers = 0;
      final state = GameState(
        level: LevelModel(
          levelNumber: 1,
          gridSize: 3,
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
          ],
        ),
        theme: GameTheme.classic,
        onLevelComplete: () => completions++,
        onGameOver: () => gameOvers++,
        onLifeLost: () {},
      );
      addTearDown(state.dispose);
      state.handleArrowExitCompleted('a');
      expect(state.arrows, hasLength(1));
      state.tapArrow('a');
      state.forceGameOver();
      state.forceGameOver();
      state.handleArrowExitCompleted('a');
      expect(state.arrows, isEmpty);
      expect(state.isComplete, isFalse);
      expect(completions, 0);
      expect(gameOvers, 1);
      state.resumeFromTimeout();
      expect(state.isGameOver, isFalse);
      expect(state.isComplete, isTrue);
      expect(completions, 1);
      state.handleArrowExitCompleted('a');
      state.forceGameOver();
      expect(completions, 1);
      expect(gameOvers, 1);
      expect(state.isGameOver, isFalse);
    },
  );
}
