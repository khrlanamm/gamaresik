const _kMonthsShort = [
  'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
  'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des',
];

/// Formats a 0..1 model confidence as a whole percentage.
String formatConfidence(double score) => '${(score * 100).round()}%';

/// Formats a timestamp as `12 Agu 2026, 09:45` in Indonesian short-month form.
///
/// A null date means the server timestamp has not resolved yet, which happens
/// briefly right after a write.
String formatScanDate(DateTime? date) {
  if (date == null) return 'Baru saja';
  final hh = date.hour.toString().padLeft(2, '0');
  final mm = date.minute.toString().padLeft(2, '0');
  return '${date.day} ${_kMonthsShort[date.month - 1]} ${date.year}, $hh:$mm';
}
