import '../models/time_log.dart';

// Velocity = how long things actually take compared to what you guessed.
//
// Every finished task gives a ratio: actual / estimate. If you guessed 30 min
// and it took 42, that's 1.4. Velocity is a running average of those ratios,
// so 1.0 means your guesses are right and 1.4 means things take 40% longer.
//
// I used an exponential moving average (new = 0.3 * ratio + 0.7 * old) so
// recent tasks count the most but one weird day doesn't wreck it. It's also
// clamped between 0.5 and 3.0, and ratios above 5 or below 0.2 get ignored,
// because those are almost always a timer someone forgot to stop.
//
// The planner doesn't use velocity until there are 3 good logs. Before that
// it just uses 1.0.

/// Velocity before any logs: assume estimates are right.
const double startingVelocity = 1.0;

/// Lowest velocity allowed (clamping).
const double minVelocity = 0.5;

/// Highest velocity allowed (clamping).
const double maxVelocity = 3.0;

/// How much each new log counts in the moving average (the "alpha").
const double velocityAlpha = 0.3;

/// Ratios below this are treated as broken timers and ignored.
const double minValidRatio = 0.2;

/// Ratios above this are treated as broken timers and ignored.
const double maxValidRatio = 5.0;

/// Velocity only changes the plan after this many valid logs.
const int logsNeededToApply = 3;

/// No task is ever planned shorter than this, whatever the velocity.
const int minAdjustedMinutes = 5;

/// Velocities from [spotOnLow] to [spotOnHigh] (inclusive) are described
/// as "spot on".
const double spotOnLow = 0.95;

/// See [spotOnLow].
const double spotOnHigh = 1.05;

/// Estimate used in the example sentence ("a 30 min task is planned as...").
const int _exampleEstimateMin = 30;

/// The result of replaying every time log.
class VelocityState {
  const VelocityState({required this.velocity, required this.validLogCount});

  /// The moving average after all valid logs.
  final double velocity;

  /// How many logs counted (outliers and logs without an estimate don't).
  final int validLogCount;
}

/// How long one task took compared to its estimate: actual / estimate.
/// Returns NaN (which [isValidRatio] rejects) if the estimate is 0 or less,
/// since there's nothing to compare against.
double ratio(TimeLog log) {
  if (log.estimateMin <= 0) return double.nan;
  return log.actualMin / log.estimateMin;
}

/// Whether a ratio should count toward velocity. Ratios above 5 or below
/// 0.2 are probably a forgotten timer, so they're ignored.
bool isValidRatio(double r) =>
    r.isFinite && r >= minValidRatio && r <= maxValidRatio;

/// One step of the moving average: moves [oldV] 30% of the way toward the
/// new ratio [r], then clamps the result to 0.5 - 3.0.
double updateVelocity(double oldV, double r) {
  final v = velocityAlpha * r + (1 - velocityAlpha) * oldV;
  return v.clamp(minVelocity, maxVelocity);
}

/// Works out velocity from scratch by replaying [logs] oldest to newest,
/// skipping invalid ones. Replaying (instead of updating a stored number)
/// means undoing a completion is just "remove the log and replay".
VelocityState computeFromLogs(List<TimeLog> logs) {
  final sorted = List<TimeLog>.of(logs)
    ..sort((a, b) => a.loggedAt.compareTo(b.loggedAt));

  var v = startingVelocity;
  var count = 0;
  for (final log in sorted) {
    final r = ratio(log);
    if (!isValidRatio(r)) continue;
    v = updateVelocity(v, r);
    count++;
  }
  return VelocityState(velocity: v, validLogCount: count);
}

/// The velocity the planner should actually use: 1.0 until there are
/// [logsNeededToApply] valid logs, then the learned [velocity].
double appliedVelocity(double velocity, int validLogCount) =>
    validLogCount < logsNeededToApply ? startingVelocity : velocity;

/// An estimate stretched (or shrunk) by velocity, rounded to the nearest
/// minute and never under 5 minutes. 30 min at 1.4x = 42 min.
int adjustedMinutes(int estimateMin, double appliedV) {
  final minutes = (estimateMin * appliedV).round();
  return minutes < minAdjustedMinutes ? minAdjustedMinutes : minutes;
}

/// A plain-language sentence about velocity for the UI, like "You usually
/// take 1.4× your estimates, so a 30 min task is planned as 42 min."
String velocityMessage(double appliedV, int validLogCount) {
  if (validLogCount < logsNeededToApply) {
    return 'Log $logsNeededToApply tasks to unlock smart estimates '
        '($validLogCount/$logsNeededToApply)';
  }
  if (appliedV >= spotOnLow && appliedV <= spotOnHigh) {
    return 'Your estimates are spot on.';
  }
  final planned = adjustedMinutes(_exampleEstimateMin, appliedV);
  return 'You usually take ${appliedV.toStringAsFixed(1)}× your estimates, '
      'so a $_exampleEstimateMin min task is planned as $planned min.';
}

/// Short velocity text for the Today header: a big value and a small label,
/// like ("1.4×", "pace") or ("2/3", "logs to unlock").
({String value, String label}) velocityBadge(
  double appliedV,
  int validLogCount,
) {
  if (validLogCount < logsNeededToApply) {
    return (
      value: '$validLogCount/$logsNeededToApply',
      label: 'logs to unlock',
    );
  }
  return (value: '${appliedV.toStringAsFixed(1)}×', label: 'pace');
}
