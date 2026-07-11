import 'package:flutter_test/flutter_test.dart';
import 'package:invoy/models.dart';

void main() {
  test('invoice numbers are financial-year scoped and at most 16 characters',
      () {
    expect(financialYearCode(DateTime(2026, 3, 31)), '25-26');
    expect(financialYearCode(DateTime(2026, 4, 1)), '26-27');

    final first = buildInvoiceNumber('Invoice', DateTime(2026, 4, 1), 1);
    final large = buildInvoiceNumber(
      'Very long prefix',
      DateTime(2026, 4, 1),
      99999999,
    );

    expect(first, 'INVOI-26-27-001');
    expect(first.length, lessThanOrEqualTo(kMaxInvoiceNumberLength));
    expect(large.length, lessThanOrEqualTo(kMaxInvoiceNumberLength));
    expect(large, endsWith('-26-27-99999999'));
  });

  test('GST state helpers infer intrastate and interstate tax correctly', () {
    expect(gstStateCode('Karnataka'), '29');
    expect(gstStateCode('Karnataka (29)'), '29');
    expect(gstStateCode('Tamil Nadu'), '33');
    expect(gstStateWithCode('Karnataka'), 'Karnataka (29)');
    expect(gstStateWithCode('Karnataka (29)'), 'Karnataka (29)');
    expect(splitGstForStates('Karnataka', 'Karnataka'), isTrue);
    expect(splitGstForStates('Karnataka', 'Tamil Nadu'), isFalse);
    expect(gstinMatchesState('29ABCDE1234F1Z5', 'Karnataka'), isTrue);
    expect(gstinMatchesState('33ABCDE1234F1Z5', 'Karnataka'), isFalse);
  });

  test('delivery address survives invoice persistence mapping', () {
    final invoice = Invoice(
      id: 'delivery-test',
      num: 'INV-26-27-001',
      deliveryAddress: 'Warehouse 4, Bengaluru',
    );

    final restored = Invoice.fromMap(invoice.toMap());
    expect(restored.deliveryAddress, 'Warehouse 4, Bengaluru');
  });
}
