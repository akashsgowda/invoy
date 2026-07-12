import 'package:flutter_test/flutter_test.dart';
import 'package:invoy/models.dart';
import 'package:invoy/pdf_builder.dart';

void main() {
  setUp(() {
    Prefs.showUpiQr = true;
    Prefs.upiId.value = 'merchant@exampleupi';
    Prefs.upiQrImage.value = '';
    Prefs.upiQrImageName.value = '';
    Prefs.bizName.value = 'Example Studio';
    Prefs.yourName.value = 'Example Owner';
  });

  tearDown(() {
    Prefs.showUpiQr = true;
    Prefs.upiId.value = '';
    Prefs.upiQrImage.value = '';
    Prefs.upiQrImageName.value = '';
    Prefs.bizName.value = '';
    Prefs.yourName.value = '';
  });

  Invoice invoice({double paid = 0}) => Invoice(
        id: 'upi-test',
        num: 'TEST-INV-050',
        gst: 0,
        status: paid >= 1000 ? Status.paid : Status.pending,
        items: [LineItem(id: '1', desc: 'Work', qty: 1, rate: 1000)],
        payments: paid > 0
            ? [
                Payment(
                  amount: paid,
                  date: DateTime(2026, 6, 20),
                  mode: PayMode.upi,
                ),
              ]
            : [],
      );

  test('upi qr link uses the invoice balance due', () {
    final link = upiPaymentUriForInvoice(invoice());
    final uri = Uri.parse(link!);

    expect(uri.scheme, 'upi');
    expect(uri.host, 'pay');
    expect(uri.queryParameters['pa'], 'merchant@exampleupi');
    expect(uri.queryParameters['pn'], 'Example Studio');
    expect(uri.queryParameters['am'], '1000.00');
    expect(uri.queryParameters['cu'], 'INR');
    expect(uri.queryParameters['tn'], 'TEST-INV-050');
  });

  test('partial payment qr asks for remaining balance only', () {
    final link = upiPaymentUriForInvoice(invoice(paid: 400));
    final uri = Uri.parse(link!);

    expect(uri.queryParameters['am'], '600.00');
  });

  test('full paid invoice has no upi qr link', () {
    expect(upiPaymentUriForInvoice(invoice(paid: 1000)), isNull);
  });

  test('legacy paid and draft invoices never show a payment QR', () {
    final legacyPaid = invoice()..status = Status.paid;
    final draft = invoice()..status = Status.draft;

    expect(upiPaymentUriForInvoice(legacyPaid), isNull);
    expect(upiPaymentUriForInvoice(draft), isNull);
  });

  test('upi qr link is hidden when disabled or upi id is missing', () {
    Prefs.showUpiQr = false;
    expect(upiPaymentUriForInvoice(invoice()), isNull);

    Prefs.showUpiQr = true;
    Prefs.upiId.value = '';
    expect(upiPaymentUriForInvoice(invoice()), isNull);
  });
}
