/// Monetary values are stored as integer cents, never floating-point balances.
int parseMoney(String value) {
  if (!RegExp(r'^\d+(\.\d{1,2})?$').hasMatch(value.trim())) {
    throw const FormatException('Enter an amount with at most two decimals.');
  }
  final parts = value.trim().split('.');
  final cents =
      int.parse(parts[0]) * 100 +
      (parts.length == 1 ? 0 : int.parse(parts[1].padRight(2, '0')));
  if (cents <= 0 || cents > 100000000) {
    throw const FormatException('Amount must be between 0.01 and 1,000,000.');
  }
  return cents;
}

Map<String, int> equalSplit(int cents, List<String> members) {
  if (members.isEmpty || cents <= 0) throw ArgumentError('Invalid split');
  return {
    for (var i = 0; i < members.length; i++)
      members[i]:
          cents ~/ members.length + (i < cents % members.length ? 1 : 0),
  };
}

Map<String, int> balances(
  List<Map<String, dynamic>> expenses,
  List<String> members,
) {
  final result = {for (final member in members) member: 0};
  for (final expense in expenses) {
    final payer = expense['payer'] as String;
    result[payer] = (result[payer] ?? 0) + (expense['cents'] as num).toInt();
    (expense['shares'] as Map).forEach((key, value) {
      result[key as String] = (result[key] ?? 0) - (value as num).toInt();
    });
  }
  return result;
}
