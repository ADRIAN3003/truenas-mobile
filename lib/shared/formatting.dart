/// `17179869184` → `16.0 GiB`
String formatBytes(num bytes) {
  const units = ['B', 'KiB', 'MiB', 'GiB', 'TiB', 'PiB'];
  var value = bytes.toDouble();
  var unit = 0;
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024;
    unit++;
  }
  return unit == 0 ? '$bytes B' : '${value.toStringAsFixed(1)} ${units[unit]}';
}

/// Bytes per second as bits per second, the way network speeds are quoted:
/// `125000` → `1.0 Mb/s`.
String formatBitRate(num bytesPerSecond) {
  const units = ['b/s', 'kb/s', 'Mb/s', 'Gb/s', 'Tb/s'];
  var value = bytesPerSecond * 8.0;
  var unit = 0;
  while (value >= 1000 && unit < units.length - 1) {
    value /= 1000;
    unit++;
  }
  return '${value.toStringAsFixed(unit == 0 ? 0 : 1)} ${units[unit]}';
}

/// `Duration(days: 3, hours: 4, minutes: 5)` → `3d 4h 5m`
String formatDuration(Duration duration) {
  final days = duration.inDays;
  final hours = duration.inHours % 24;
  final minutes = duration.inMinutes % 60;
  return [
    if (days > 0) '${days}d',
    if (days > 0 || hours > 0) '${hours}h',
    '${minutes}m',
  ].join(' ');
}
