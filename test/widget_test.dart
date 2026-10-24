import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:together_expenses/main.dart';
import 'package:together_expenses/ledger.dart';

void main() {
  test('equal splits preserve cents and balances sum to zero', () {
    final shares = equalSplit(100, ['a', 'b', 'c']);
    expect(shares, {'a': 34, 'b': 33, 'c': 33});
    final net = balances(
      [
        {'payer': 'a', 'cents': 100, 'shares': shares},
      ],
      ['a', 'b', 'c'],
    );
    expect(net, {'a': 66, 'b': -33, 'c': -33});
    expect(net.values.reduce((a, b) => a + b), 0);
  });
  test('money parser rejects invalid precision and nonpositive values', () {
    expect(parseMoney('12.05'), 1205);
    for (final bad in ['0', '-1', '1.234', 'NaN', '1e3']) {
      expect(() => parseMoney(bad), throwsFormatException);
    }
  });
  testWidgets('personal expense appears after saving', (tester) async {
    await tester.pumpWidget(const ExpenseApp());
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Add expense'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), 'Coffee');
    await tester.enterText(find.byType(TextField).at(1), '4.50');
    await tester.tap(find.text('Save expense'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Coffee'), findsOneWidget);
    expect(find.text('\$4.50'), findsNWidgets(2));
    await tester.pumpWidget(const SizedBox());
  });
}
