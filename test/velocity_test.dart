import 'package:daybreak/models/time_log.dart';
import 'package:daybreak/services/velocity.dart';
import 'package:flutter_test/flutter_test.dart';

var _logNumber = 0;

/// Logs are spaced a minute apart so their order is clear.
TimeLog makeLog(int estimateMin, int actualMin) {
  _logNumber++;
  return TimeLog(
    id: 'log-$_logNumber',
    taskId: 'task',
    estimateMin: estimateMin,
    actualMin: actualMin,
    loggedAt: DateTime(2026, 10, 26, 12, _logNumber),
  );
}

void main() {
  group('ratio and isValidRatio', () {
    test('ratio is actual / estimate', () {
      expect(ratio(makeLog(30, 45)), 1.5);
    });

    test('estimate of 0 or less is invalid', () {
      expect(isValidRatio(ratio(makeLog(0, 30))), isFalse);
      expect(isValidRatio(ratio(makeLog(-5, 30))), isFalse);
    });

    test('ratios above 5 or below 0.2 are invalid', () {
      expect(isValidRatio(5.0), isTrue);
      expect(isValidRatio(0.2), isTrue);
      expect(isValidRatio(5.01), isFalse);
      expect(isValidRatio(0.19), isFalse);
    });
  });

  group('updateVelocity', () {
    test('EMA: 0.3 * r + 0.7 * old', () {
      expect(updateVelocity(1.0, 2.0), closeTo(1.3, 1e-9));
      expect(updateVelocity(1.3, 1.0), closeTo(1.21, 1e-9));
    });

    test('clamps at 3.0', () {
      expect(updateVelocity(3.0, 5.0), 3.0);
    });

    test('clamps at 0.5', () {
      expect(updateVelocity(0.5, 0.2), 0.5);
    });
  });

  group('computeFromLogs', () {
    test('no logs = 1.0 with 0 counted', () {
      final state = computeFromLogs([]);
      expect(state.velocity, 1.0);
      expect(state.validLogCount, 0);
    });

    test('folds oldest to newest with known numbers', () {
      // r = 2.0 -> 1.3, r = 1.0 -> 1.21, r = 1.5 -> 1.297
      final logs = [makeLog(30, 60), makeLog(30, 30), makeLog(20, 30)];
      final state = computeFromLogs(logs.reversed.toList());
      expect(state.velocity, closeTo(1.297, 1e-9));
      expect(state.validLogCount, 3);
    });

    test('invalid ratios are skipped and not counted', () {
      final logs = [
        makeLog(30, 60), // valid, r = 2.0
        makeLog(10, 300), // r = 30, forgotten timer
        makeLog(60, 5), // r = 0.08
        makeLog(0, 20), // no estimate
      ];
      final state = computeFromLogs(logs);
      expect(state.velocity, closeTo(1.3, 1e-9));
      expect(state.validLogCount, 1);
    });
  });

  group('appliedVelocity', () {
    test('stays 1.0 until 3 valid logs', () {
      expect(appliedVelocity(1.8, 0), 1.0);
      expect(appliedVelocity(1.8, 2), 1.0);
      expect(appliedVelocity(1.8, 3), 1.8);
      expect(appliedVelocity(0.7, 10), 0.7);
    });
  });

  group('adjustedMinutes', () {
    test('rounds to the nearest minute', () {
      expect(adjustedMinutes(30, 1.4), 42);
      expect(adjustedMinutes(10, 1.25), 13);
      expect(adjustedMinutes(45, 1.0), 45);
    });

    test('never less than 5', () {
      expect(adjustedMinutes(5, 0.5), 5);
      expect(adjustedMinutes(1, 1.0), 5);
    });
  });

  group('velocityMessage', () {
    test('fewer than 3 logs', () {
      expect(
        velocityMessage(1.0, 0),
        'Log 3 tasks to unlock smart estimates (0/3)',
      );
      expect(
        velocityMessage(1.0, 2),
        'Log 3 tasks to unlock smart estimates (2/3)',
      );
    });

    test('slower than estimates', () {
      expect(
        velocityMessage(1.4, 5),
        'You usually take 1.4× your estimates, '
        'so a 30 min task is planned as 42 min.',
      );
    });

    test('faster than estimates', () {
      expect(
        velocityMessage(0.7, 5),
        'You usually take 0.7× your estimates, '
        'so a 30 min task is planned as 21 min.',
      );
    });

    test('spot on between 0.95 and 1.05', () {
      expect(velocityMessage(1.0, 3), 'Your estimates are spot on.');
      expect(velocityMessage(0.95, 3), 'Your estimates are spot on.');
      expect(velocityMessage(1.05, 3), 'Your estimates are spot on.');
      expect(velocityMessage(1.06, 3), startsWith('You usually take 1.1×'));
    });
  });
}
