import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:invoy/models.dart';
import 'package:invoy/pdf_builder.dart';
import 'package:invoy/theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    Prefs.upiId.value = '';
    Prefs.upiQrImage.value = '';
    Prefs.upiQrImageName.value = '';
    Prefs.signatureImage.value = '';
    Prefs.signatureImageName.value = '';
    Prefs.bizName.value = '';
    Prefs.yourName.value = '';
    Prefs.bizAddress.value = '';
    Prefs.bizState.value = '';
    Prefs.gstNum.value = '';
    Prefs.showUpiQr = true;
  });

  test('builds every invoice template', () async {
    for (final template in kTemplates) {
      final invoice = Invoice(
        id: 'test-${template.name}',
        num: 'INV-TEST',
        template: template.name,
        client: Customer(
          name: 'Example Design Studio',
          email: 'billing@example.com',
          phone: '0000000000',
          address: 'Example City',
          gstin: '29ABCDE1234F1Z5',
        ),
        items: [
          LineItem(id: '1', desc: 'Brand kit', qty: 1, rate: 24500),
          LineItem(id: '2', desc: 'Landing page', qty: 1, rate: 18000),
        ],
        notes: 'Payment accepted by UPI or bank transfer.',
      );

      final bytes = await buildPdf(
        invoice,
      ).timeout(const Duration(seconds: 12));
      expect(bytes.length, greaterThan(1000), reason: template.name);
    }
  });

  test('builds invoice pdf with upi qr', () async {
    Prefs.upiId.value = 'merchant@exampleupi';
    Prefs.bizName.value = 'Example Studio';
    Prefs.showUpiQr = true;

    final invoice = Invoice(
      id: 'upi-test',
      num: 'INV-UPI',
      client: Customer(name: 'Example Client Studio'),
      items: [LineItem(id: '1', desc: 'Brand kit', qty: 1, rate: 24500)],
      status: Status.pending,
    );

    final bytes = await buildPdf(invoice).timeout(const Duration(seconds: 12));
    expect(bytes.length, greaterThan(1000));
  });

  test('builds invoice pdf with uploaded upi qr image', () async {
    Prefs.upiQrImage.value =
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==';
    Prefs.upiQrImageName.value = 'upi_qr.png';
    Prefs.showUpiQr = true;

    final invoice = Invoice(
      id: 'upi-image-test',
      num: 'INV-UPI-IMAGE',
      client: Customer(name: 'Example Client Studio'),
      items: [LineItem(id: '1', desc: 'Brand kit', qty: 1, rate: 24500)],
      status: Status.pending,
    );

    final bytes = await buildPdf(invoice).timeout(const Duration(seconds: 12));
    expect(bytes.length, greaterThan(1000));
  });

  test('invalid uploaded upi qr data is ignored safely', () async {
    Prefs.upiId.value = 'merchant@exampleupi';
    Prefs.upiQrImage.value = base64Encode('not an image'.codeUnits);
    Prefs.upiQrImageName.value = 'broken.png';
    Prefs.showUpiQr = true;

    final invoice = Invoice(
      id: 'broken-qr-test',
      num: 'INV-BROKEN-QR',
      client: Customer(name: 'Example Client Studio'),
      items: [LineItem(id: '1', desc: 'Brand kit', qty: 1, rate: 24500)],
      status: Status.pending,
    );

    final bytes = await buildPdf(invoice).timeout(const Duration(seconds: 12));
    expect(bytes.length, greaterThan(1000));
  });

  test('pdf amount text uses the Indian rupee glyph', () {
    expect(pdfAmountForTesting(1234.5), '₹1,234.50');
    expect(pdfAmountForTesting(-1234.5), '-₹1,234.50');
    expect(pdfAmountForTesting(923372036854.75), startsWith('₹'));
  });

  test('builds multilingual GST invoice with uploaded signature', () async {
    const image =
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==';
    Prefs.bizName.value = 'ಆಕಾಶ್ ಡಿಸೈನ್';
    Prefs.bizAddress.value = 'ಬೆಂಗಳೂರು, ಕರ್ನಾಟಕ';
    Prefs.bizState.value = 'Karnataka';
    Prefs.gstNum.value = '29ABCDE1234F1Z5';
    Prefs.signatureImage.value = image;
    Prefs.signatureImageName.value = 'signature.png';

    final invoice = Invoice(
      id: 'unicode-gst',
      num: 'INV-26-27-001',
      template: 'GST Invoice',
      client: Customer(
        name: 'नमूना ग्राहक',
        address: 'चेन्नई, தமிழ்நாடு',
        state: 'Tamil Nadu',
        gstin: '33ABCDE1234F1Z5',
      ),
      deliveryAddress: 'சென்னை விநியோக முகவரி',
      placeOfSupply: 'Tamil Nadu',
      splitGst: false,
      gst: 18,
      items: [
        LineItem(
          id: '1',
          desc: 'ವಿನ್ಯಾಸ ಸೇವೆ',
          hsnSac: '998391',
          qty: 1,
          rate: 24500,
          gstRate: 18,
        ),
      ],
      status: Status.pending,
    );

    final bytes = await buildPdf(invoice).timeout(const Duration(seconds: 15));
    expect(bytes.length, greaterThan(5000));
  });

  test('builds every template with long names huge values and payments',
      () async {
    Prefs.bizName.value = 'Example Professional Billing Services';
    Prefs.yourName.value = 'Example Owner';
    Prefs.gstNum.value = '29ABCDE1234F1Z5';
    Prefs.upiId.value = 'merchant.long@exampleupi';
    Prefs.showUpiQr = true;

    for (final template in kTemplates) {
      final invoice = Invoice(
        id: 'ugly-${template.name}',
        num: 'TEST-INV-LONG-0000001',
        template: template.name,
        client: Customer(
          name: 'Example Premium Construction And Interior Works',
          email: 'accounts.very.long.email@example-business-domain.co.in',
          phone: '0000000000',
          address:
              'No 000, 3rd Floor, Long Example Street, Example City 000000',
          gstin: '29ABCDE1234F1Z5',
        ),
        items: [
          LineItem(
            id: '1',
            desc:
                'Custom enterprise billing workflow consultation with a very long item description',
            qty: 1250,
            rate: 923372036854.75,
          ),
          LineItem(
            id: '2',
            desc: 'Implementation support and documentation',
            qty: 2,
            rate: 8750000,
          ),
        ],
        gst: 18,
        splitGst: true,
        status: Status.pending,
        notes:
            'Payment can be made by UPI or bank transfer. Please mention the invoice number while paying.',
        payments: [
          Payment(
            amount: 5000000,
            date: DateTime(2026, 6, 18),
            mode: PayMode.upi,
          ),
          Payment(
            amount: 2500000,
            date: DateTime(2026, 6, 19),
            mode: PayMode.bank,
          ),
        ],
      );

      final bytes = await buildPdf(
        invoice,
      ).timeout(const Duration(seconds: 12));
      expect(bytes.length, greaterThan(1000), reason: template.name);
    }
  });

  test('builds long multi-page invoices in every template', () async {
    Prefs.bizName.value = 'Example Professional Services';
    Prefs.bizAddress.value = 'Example Business Address';
    Prefs.bizState.value = 'Karnataka';
    Prefs.gstNum.value = '29ABCDE1234F1Z5';
    Prefs.showUpiQr = false;

    final items = List.generate(
      42,
      (index) => LineItem(
        id: 'line-$index',
        desc: 'Professional service line item ${index + 1}',
        hsnSac: '998391',
        unit: 'Hrs',
        qty: index.isEven ? 2 : 3,
        rate: 1250 + (index * 25),
        gstRate: index % 3 == 0 ? 12 : 18,
      ),
    );

    for (final template in kTemplates) {
      final invoice = Invoice(
        id: 'multipage-${template.name}',
        num: 'INV-MULTIPAGE-001',
        template: template.name,
        client: Customer(
          name: 'Example Client Private Limited',
          address: 'Example Client Address',
          state: 'Karnataka',
          gstin: '29AAACR5055K1Z2',
        ),
        items: items.map((item) => item.copy()).toList(),
        gst: 18,
        splitGst: true,
        status: Status.pending,
        placeOfSupply: 'Karnataka',
      );

      final bytes = await buildPdf(
        invoice,
      ).timeout(const Duration(seconds: 15));
      expect(bytes.length, greaterThan(5000), reason: template.name);
    }
  });
}
