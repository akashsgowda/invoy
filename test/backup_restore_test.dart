import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:invoy/data_export.dart';
import 'package:invoy/models.dart';

void main() {
  tearDown(() {
    Prefs.lastBackupAt.value = '';
  });

  test('backup json preview restores invoices clients and prefs', () {
    final invoice = Invoice(
      id: 'inv-1',
      num: 'TEST-INV-042',
      client: Customer(
        name: 'Example Studio',
        email: 'billing@example.com',
        phone: '0000000000',
      ),
      items: [LineItem(id: 'item-1', desc: 'Design work', qty: 2, rate: 1500)],
      payments: [
        Payment(amount: 1000, date: DateTime(2026, 6, 20), mode: PayMode.upi),
      ],
      gst: 18,
      discountValue: 10,
      discountIsPercent: true,
      status: Status.pending,
      createdAt: DateTime(2026, 6, 20),
    );

    final content = jsonEncode({
      'app': 'Invoy',
      'version': 1,
      'createdAt': '2026-06-20T10:00:00.000',
      'prefs': {
        'themeMode': 'dark',
        'defaultTemplate': 'Classic',
        'lastBackupAt': '2026-06-20T11:00:00.000',
        'defaultGst': 18,
        'showUpiQr': false,
        'upiQrImage': 'abc123',
        'upiQrImageName': 'upi_qr.png',
        'splitGst': true,
      },
      'clients': [
        Customer(name: 'Example Studio', email: 'billing@example.com').toMap(),
      ],
      'invoices': [invoice.toMap()],
    });

    final preview = parseBackupJson(content, path: 'invoy_backup.json');

    expect(preview.invoiceCount, 1);
    expect(preview.clientCount, 1);
    expect(preview.prefs['themeMode'], 'dark');
    expect(preview.prefs['lastBackupAt'], '2026-06-20T11:00:00.000');
    expect(preview.prefs['showUpiQr'], false);
    expect(preview.prefs['upiQrImage'], 'abc123');
    expect(preview.prefs['upiQrImageName'], 'upi_qr.png');
    expect(preview.invoices.single.num, 'TEST-INV-042');
    expect(preview.invoices.single.total, 3186);
    expect(preview.invoices.single.paidAmt, 1000);
    expect(preview.clients.single.name, 'Example Studio');
  });

  test('backup payload writes the current backup timestamp', () {
    Prefs.lastBackupAt.value = '2026-06-19T09:00:00.000';
    final backedUpAt = DateTime(2026, 6, 20, 11, 30);

    final payload = createBackupPayload(backedUpAt: backedUpAt);
    final prefs = payload['prefs'] as Map<String, dynamic>;

    expect(prefs['lastBackupAt'], backedUpAt.toIso8601String());
  });
}
