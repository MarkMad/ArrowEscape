import 'package:arrowescape/core/constants.dart';
import 'package:arrowescape/data/level_generator/level_generator.dart';
import 'package:arrowescape/data/level_generator/solver.dart';
import 'package:arrowescape/data/models/arrow.dart';
import 'package:arrowescape/data/models/level.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LevelGenerator', () {
    test('is deterministic for a given level number', () {
      for (final levelNumber in [1, 5, 44, 213, 600]) {
        final a = LevelGenerator.generateLevel(levelNumber);
        final b = LevelGenerator.generateLevel(levelNumber);
        expect(a.toJson(), b.toJson(),
            reason: 'level $levelNumber should generate identical output');
      }
    });

    test('generates a solvable level for a range of level numbers', () {
      for (var levelNumber = 1; levelNumber <= 160; levelNumber += 7) {
        final level = LevelGenerator.generateLevel(levelNumber);
        final solution = LevelSolver.solve(level, LevelSolver.maxStates);
        expect(solution, isNotNull,
            reason: 'level $levelNumber should be solvable');
        expect(solution!.length, level.arrows.length,
            reason: 'level $levelNumber solution should consume every arrow');
      }
    });

    test('keeps every arrow path and orphan dot within the grid bounds', () {
      for (var levelNumber = 1; levelNumber <= 120; levelNumber += 7) {
        final level = LevelGenerator.generateLevel(levelNumber);
        for (final arrow in level.arrows) {
          for (final pt in arrow.path) {
            expect(pt[0], inInclusiveRange(0, level.gridSize - 1),
                reason: 'level $levelNumber row $pt');
            expect(pt[1], inInclusiveRange(0, level.gridSize - 1),
                reason: 'level $levelNumber col $pt');
          }
        }
        for (final dot in level.orphanDots) {
          expect(dot.row, inInclusiveRange(0, level.gridSize - 1),
              reason: 'level $levelNumber dot row');
          expect(dot.col, inInclusiveRange(0, level.gridSize - 1),
              reason: 'level $levelNumber dot col');
        }
      }
    });

    test('never places two arrows or arrows and dots on the same cell', () {
      for (var levelNumber = 1; levelNumber <= 120; levelNumber += 7) {
        final level = LevelGenerator.generateLevel(levelNumber);
        final occupied = <String>{};
        for (final arrow in level.arrows) {
          for (final pt in arrow.path) {
            final key = '${pt[0]},${pt[1]}';
            expect(occupied.add(key), isTrue,
                reason: 'level $levelNumber cell $key occupied twice');
          }
        }
        for (final dot in level.orphanDots) {
          expect(occupied.contains(dot.key), isFalse,
              reason: 'level $levelNumber orphan dot overlaps an arrow at '
                  '${dot.key}');
        }
      }
    });

    test('matches the documented grid size for each level', () {
      for (var levelNumber = 1; levelNumber <= 150; levelNumber += 11) {
        final level = LevelGenerator.generateLevel(levelNumber);
        final expected = AppConstants.handcraftedGridSizes[levelNumber] ??
            AppConstants.gridSizeForLevel(levelNumber);
        expect(level.gridSize, expected,
            reason: 'level $levelNumber grid size mismatch');
      }
    });
  });

  group('LevelSolver', () {
    test('solves a single straight arrow that exits the grid', () {
      final level = LevelModel(
        levelNumber: 1,
        gridSize: 3,
        arrows: [
          ArrowModel(
            id: 'a',
            row: 1,
            col: 0,
            direction: ArrowDirection.right,
            path: [
              [1, 0],
              [1, 1],
              [1, 2],
            ],
          ),
        ],
        maskShape: MaskShape.square,
      );

      final solution = LevelSolver.solve(level);
      expect(solution, isNotNull);
      expect(solution, ['a']);
    });

    test('redirects an arrow through an orphan dot', () {
      // Arrow starts at the bottom-middle facing up, but an orphan dot at
      // [1,1] turns it; the dot must be consumable so it can exit.
      final level = LevelModel(
        levelNumber: 2,
        gridSize: 3,
        arrows: [
          ArrowModel(
            id: 'a',
            row: 2,
            col: 1,
            direction: ArrowDirection.up,
            path: [
              [2, 1],
              [1, 1],
            ],
          ),
        ],
        orphanDots: [
          OrphanDot(row: 1, col: 1, type: OrphanDotType.down),
        ],
        maskShape: MaskShape.square,
      );

      final solution = LevelSolver.solve(level);
      expect(solution, isNotNull);
    });

    test('rejects a mutually blocked pair of arrows (deadlock)', () {
      // Arrow 'a' at [0,1] faces down into 'b' at [1,1], which faces up into
      // 'a'. Neither can exit first, so the level is unsolvable.
      final level = LevelModel(
        levelNumber: 4,
        gridSize: 3,
        arrows: [
          ArrowModel(
            id: 'a',
            row: 0,
            col: 1,
            direction: ArrowDirection.down,
            path: [
              [0, 1],
            ],
          ),
          ArrowModel(
            id: 'b',
            row: 1,
            col: 1,
            direction: ArrowDirection.up,
            path: [
              [1, 1],
            ],
          ),
        ],
        maskShape: MaskShape.square,
      );

      expect(LevelSolver.solve(level), isNull);
    });
  });
}
