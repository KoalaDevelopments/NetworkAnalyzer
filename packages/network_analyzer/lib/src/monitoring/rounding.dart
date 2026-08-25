/// The rounding rules applied to every reported measurement.
///
/// Values cross the channel in microseconds at full precision and are
/// rounded exactly once, here. Rounding on the native side would round twice,
/// differently, on two platforms — and the parity guarantee would quietly
/// stop being true.
library;

/// Rounds [value] to a tenth of a millisecond.
Duration roundToTenthMilli(Duration value) {
  const int step = 100; // microseconds in 0.1 ms
  final int rounded = ((value.inMicroseconds / step).round()) * step;
  return Duration(microseconds: rounded);
}

/// Rounds [value] to one decimal place, for a percentage.
double roundToTenth(double value) => (value * 10).round() / 10;
