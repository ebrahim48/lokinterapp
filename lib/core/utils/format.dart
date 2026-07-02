// Small formatting helpers so we don't pull in intl just for a few strings.
const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

String shortDate(DateTime d) => '${_months[d.month - 1]} ${d.day}, ${d.year}';

String dayMonth(DateTime d) => '${d.day} ${_months[d.month - 1]}';

String kg(double value) {
  final s = value == value.roundToDouble() ? value.toInt().toString() : value.toString();
  return '$s kg';
}
