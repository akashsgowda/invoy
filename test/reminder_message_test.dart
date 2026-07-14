import 'package:flutter_test/flutter_test.dart';
import 'package:invoy/models.dart';
import 'package:invoy/screens/detail.dart';

void main() {
  tearDown(() {
    Prefs.bizName.value = '';
    Prefs.yourName.value = '';
  });

  test('payment reminder message uses balance due and sender', () {
    Prefs.bizName.value = 'Example Studio';

    final inv = Invoice(
      id: 'reminder-test',
      num: 'TEST-INV-077',
      date: DateTime(2026, 6, 1),
      termDays: 30,
      gst: 0,
      status: Status.pending,
      client: Customer(name: 'Example Client Studio'),
      items: [LineItem(id: '1', desc: 'Design', qty: 1, rate: 1000)],
      payments: [
        Payment(amount: 250, date: DateTime(2026, 6, 12), mode: PayMode.upi),
      ],
    );

    final message = paymentReminderMessage(inv);

    expect(message, contains('Hi Example Client Studio'));
    expect(message, contains('invoice TEST-INV-077'));
    expect(message, contains('Balance due: ₹750.00'));
    expect(message, contains('Due date: 1 Jul 2026'));
    expect(message, contains('Thank you,\nExample Studio'));
  });

  test('payment reminder never renders a blank invoice number', () {
    final inv = Invoice(
      id: 'draft-reminder-test',
      num: '',
      date: DateTime(2026, 6, 1),
      termDays: 30,
      gst: 0,
      status: Status.pending,
      items: [LineItem(id: '1', desc: 'Design', qty: 1, rate: 1000)],
    );

    expect(paymentReminderMessage(inv), contains('invoice Draft'));
  });
}
