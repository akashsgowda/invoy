import 'package:flutter_test/flutter_test.dart';
import 'package:invoy/models.dart';

void main() {
  Invoice invoiceWithTotal(double total) => Invoice(
        id: 'payment-test',
        num: 'INV-PAY',
        gst: 0,
        status: Status.pending,
        items: [LineItem(id: '1', desc: 'Work', qty: 1, rate: total)],
      );

  test('partial payment keeps invoice unpaid and shows part paid', () {
    final inv = invoiceWithTotal(1000);

    inv.payments.add(
      Payment(amount: 400, date: DateTime(2026, 6, 17), mode: PayMode.upi),
    );

    expect(inv.paidAmt, 400);
    expect(inv.balance, 600);
    expect(inv.isPartPaid, isTrue);
    expect(inv.displayStatus, Status.pending);
    expect(inv.statusLabel, 'Part paid');
  });

  test('paid status does not override an outstanding partial balance', () {
    final inv = invoiceWithTotal(1000)..status = Status.paid;

    inv.payments.add(
      Payment(amount: 400, date: DateTime(2026, 6, 17), mode: PayMode.upi),
    );

    expect(inv.balance, 600);
    expect(inv.displayStatus, Status.pending);
    expect(inv.statusLabel, 'Part paid');
  });

  test('stale paid status does not block overdue partial payment', () {
    final inv = invoiceWithTotal(1000)
      ..status = Status.paid
      ..date = DateTime(2026, 1, 1)
      ..termDays = 1;

    inv.payments.add(
      Payment(amount: 400, date: DateTime(2026, 1, 2), mode: PayMode.upi),
    );

    expect(inv.balance, 600);
    expect(inv.displayStatus, Status.overdue);
    expect(inv.statusLabel, 'Part overdue');
  });

  test('invoice becomes overdue after the due calendar day', () {
    final inv = invoiceWithTotal(1000)
      ..date = DateTime.now().subtract(const Duration(days: 1))
      ..termDays = 0;

    expect(inv.isOverdue, isTrue);
    expect(inv.displayStatus, Status.overdue);
  });

  test('invoice due today is not overdue yet', () {
    final inv = invoiceWithTotal(1000)
      ..date = DateTime.now()
      ..termDays = 0;

    expect(inv.isOverdue, isFalse);
    expect(inv.displayStatus, Status.pending);
    expect(inv.dueDateText, 'Due today');
  });

  test('full payment marks invoice paid', () {
    final inv = invoiceWithTotal(1000);

    inv.payments.add(
      Payment(amount: 1000, date: DateTime(2026, 6, 17), mode: PayMode.upi),
    );

    expect(inv.balance, 0);
    expect(inv.displayStatus, Status.paid);
    expect(inv.statusLabel, 'Paid');
  });

  test('invoice discount is applied before tax', () {
    final inv = invoiceWithTotal(1000)
      ..gst = 18
      ..discountValue = 10
      ..discountIsPercent = true;

    expect(inv.discountAmount, 100);
    expect(inv.taxableSub, 900);
    expect(inv.tax, 162);
    expect(inv.total, 1062);
  });

  test('flat discount cannot exceed subtotal', () {
    final inv = invoiceWithTotal(1000)
      ..gst = 18
      ..discountValue = 5000;

    expect(inv.discountAmount, 1000);
    expect(inv.taxableSub, 0);
    expect(inv.total, 0);
  });
}
