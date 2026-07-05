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

  test('no GST disables item level tax rates', () {
    final inv = Invoice(
      id: 'gst-off-test',
      num: 'INV-GST',
      gst: 0,
      status: Status.pending,
      items: [
        LineItem(
          id: '1',
          desc: 'Work',
          qty: 1,
          rate: 1000,
          gstRate: 18,
        ),
      ],
    );

    expect(inv.tax, 0);
    expect(inv.total, 1000);
  });

  test('CGST and SGST split mixed item GST rates equally', () {
    final inv = Invoice(
      id: 'split-gst-test',
      num: 'INV-SPLIT',
      gst: 18,
      splitGst: true,
      items: [
        LineItem(id: '1', desc: 'Service', qty: 1, rate: 1000, gstRate: 18),
        LineItem(id: '2', desc: 'Goods', qty: 1, rate: 500, gstRate: 5),
      ],
    );

    expect(inv.taxableSub, 1500);
    expect(inv.tax, 205);
    expect(inv.cgst, 102.5);
    expect(inv.sgst, 102.5);
    expect(inv.igst, 0);
    expect(inv.total, 1705);
  });

  test('IGST uses the full tax amount for interstate invoices', () {
    final inv = Invoice(
      id: 'igst-test',
      num: 'INV-IGST',
      gst: 18,
      splitGst: false,
      items: [
        LineItem(id: '1', desc: 'Service', qty: 1, rate: 1000, gstRate: 18),
        LineItem(id: '2', desc: 'Goods', qty: 1, rate: 500, gstRate: 5),
      ],
    );

    expect(inv.tax, 205);
    expect(inv.cgst, 0);
    expect(inv.sgst, 0);
    expect(inv.igst, 205);
    expect(inv.total, 1705);
  });

  test('discount is shared across mixed tax items before GST', () {
    final inv = Invoice(
      id: 'discount-tax-test',
      num: 'INV-DISC',
      gst: 18,
      splitGst: true,
      discountValue: 200,
      items: [
        LineItem(id: '1', desc: 'Service', qty: 1, rate: 1000, gstRate: 18),
        LineItem(id: '2', desc: 'Goods', qty: 1, rate: 1000, gstRate: 5),
      ],
    );

    expect(inv.discountAmount, 200);
    expect(inv.taxableSub, 1800);
    expect(inv.taxableFor(inv.items[0]), 900);
    expect(inv.taxableFor(inv.items[1]), 900);
    expect(inv.tax, 207);
    expect(inv.cgst, 103.5);
    expect(inv.sgst, 103.5);
    expect(inv.total, 2007);
  });

  test('invoice from map accepts string and boolean tax flags', () {
    final inv = Invoice.fromMap({
      'id': 'from-map-test',
      'num': 'INV-MAP',
      'items':
          '[{"id":"1","desc":"Work","qty":"2","rate":"500","gstRate":"12"}]',
      'payments': '[]',
      'invoiceDate': DateTime(2026, 7, 1).millisecondsSinceEpoch.toString(),
      'createdAt': DateTime(2026, 7, 1).millisecondsSinceEpoch.toString(),
      'termDays': '15',
      'gst': '12',
      'discountValue': '10',
      'discountIsPercent': true,
      'splitGst': false,
      'reverseCharge': '1',
      'status': 'pending',
    });

    expect(inv.termDays, 15);
    expect(inv.discountIsPercent, isTrue);
    expect(inv.splitGst, isFalse);
    expect(inv.reverseCharge, isTrue);
    expect(inv.taxableSub, 900);
    expect(inv.igst, 108);
    expect(inv.total, 1008);
  });

  test('invoice copy keeps edit drafts separate from saved invoice', () {
    final saved = invoiceWithTotal(1000)
      ..client = Customer(name: 'Original Client')
      ..notes = 'Saved note';
    final draft = saved.copy()
      ..client.name = 'Edited Client'
      ..items.first.rate = 2000
      ..notes = 'Draft note';

    expect(saved.client.name, 'Original Client');
    expect(saved.items.first.rate, 1000);
    expect(saved.notes, 'Saved note');
    expect(draft.total, 2000);
  });

  test('invoice from map sanitizes invalid imported numeric values', () {
    final inv = Invoice.fromMap({
      'id': 'bad-import',
      'num': 'INV-BAD',
      'items':
          '[{"id":"1","desc":"Work","qty":"-2","rate":"-500","gstRate":"500"}]',
      'payments': '[{"amount":"-100","date":"0","mode":"cash"}]',
      'invoiceDate': DateTime(2026, 7, 1).millisecondsSinceEpoch,
      'termDays': '-30',
      'gst': '200',
      'status': 'pending',
    });

    expect(inv.items.single.qty, 1);
    expect(inv.items.single.rate, 0);
    expect(inv.taxRateFor(inv.items.single), 100);
    expect(inv.payments.single.amount, 0);
    expect(inv.termDays, 0);
  });

  test('generated ids stay unique during tight loops', () {
    final ids = List.generate(1000, (_) => uid()).toSet();

    expect(ids.length, 1000);
  });
}
