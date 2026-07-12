import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:url_launcher/url_launcher.dart';
import 'models.dart';
import 'theme.dart';
import 'widgets.dart';

// ─── Colors ──────────────────────────────────────────────────────

const _black = PdfColor.fromInt(0xFF111111);
const _white = PdfColor.fromInt(0xFFFFFFFF);
const _grey5 = PdfColor.fromInt(0xFF888888);
const _grey1 = PdfColor.fromInt(0xFFE8E8E8);
const _grey05 = PdfColor.fromInt(0xFFF5F5F5);

class _PdfFontSet {
  const _PdfFontSet({
    required this.sans,
    required this.sansBold,
    required this.serif,
    required this.serifBold,
    required this.mono,
    required this.monoBold,
    required this.fallbacks,
  });

  final pw.Font sans;
  final pw.Font sansBold;
  final pw.Font serif;
  final pw.Font serifBold;
  final pw.Font mono;
  final pw.Font monoBold;
  final List<pw.Font> fallbacks;
}

Future<_PdfFontSet>? _pdfFontSet;

Future<pw.Font> _loadPdfFont(String name) async =>
    pw.Font.ttf(await rootBundle.load('assets/fonts/$name'));

Future<_PdfFontSet> _loadPdfFonts() => _pdfFontSet ??= () async {
      final fonts = await Future.wait([
        _loadPdfFont('NotoSans-Regular.ttf'),
        _loadPdfFont('NotoSans-Bold.ttf'),
        _loadPdfFont('NotoSerif-Regular.ttf'),
        _loadPdfFont('NotoSerif-Bold.ttf'),
        _loadPdfFont('NotoSansMono-Regular.ttf'),
        _loadPdfFont('NotoSansMono-Bold.ttf'),
        _loadPdfFont('NotoSansDevanagari-Regular.ttf'),
        _loadPdfFont('NotoSansBengali-Regular.ttf'),
        _loadPdfFont('NotoSansGujarati-Regular.ttf'),
        _loadPdfFont('NotoSansGurmukhi-Regular.ttf'),
        _loadPdfFont('NotoSansKannada-Regular.ttf'),
        _loadPdfFont('NotoSansMalayalam-Regular.ttf'),
        _loadPdfFont('NotoSansOriya-Regular.ttf'),
        _loadPdfFont('NotoSansTamil-Regular.ttf'),
        _loadPdfFont('NotoSansTelugu-Regular.ttf'),
      ]);
      return _PdfFontSet(
        sans: fonts[0],
        sansBold: fonts[1],
        serif: fonts[2],
        serifBold: fonts[3],
        mono: fonts[4],
        monoBold: fonts[5],
        fallbacks: fonts.sublist(6),
      );
    }();

// ════════════════════════════════════════════════════════════════
// BUILD PDF
// ════════════════════════════════════════════════════════════════

Future<Uint8List> buildPdf(Invoice inv) async {
  final doc = pw.Document();
  final tpl = tplOf(inv.template);
  final fonts = await _loadPdfFonts();
  final regular = switch (tpl.name) {
    'Classic' => fonts.serif,
    'Compact' => fonts.mono,
    _ => fonts.sans,
  };
  final bold = switch (tpl.name) {
    'Classic' => fonts.serifBold,
    'Compact' => fonts.monoBold,
    _ => fonts.sansBold,
  };
  final theme = pw.ThemeData.withFont(
    base: regular,
    bold: bold,
    fontFallback: fonts.fallbacks,
  );
  final primary = _pdfColor(tpl.primary);
  final accent = _pdfColor(tpl.accent);
  final sender = Prefs.bizName.value.isNotEmpty
      ? Prefs.bizName.value
      : Prefs.yourName.value.isNotEmpty
          ? Prefs.yourName.value
          : 'Invoice';

  if (tpl.name == 'GST Invoice') {
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(30, 32, 30, 28),
        theme: theme,
        build: (_) => _gstInvoiceLayout(inv, sender, regular, bold),
        footer: (context) => _documentFooter(context, inv, regular, bold),
      ),
    );
    return doc.save();
  }

  if (tpl.name == 'Classic') {
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(42, 36, 42, 28),
        theme: theme,
        build: (_) =>
            _classicLayout(inv, sender, regular, bold, primary, accent),
        footer: (context) => _documentFooter(context, inv, regular, bold),
      ),
    );
    return doc.save();
  }

  if (tpl.name == 'Minimal') {
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(42, 40, 42, 28),
        theme: theme,
        build: (_) =>
            _minimalLayout(inv, sender, regular, bold, primary, accent),
        footer: (context) => _documentFooter(context, inv, regular, bold),
      ),
    );
    return doc.save();
  }

  if (tpl.name == 'Ledger') {
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(36, 32, 36, 28),
        theme: theme,
        build: (_) =>
            _ledgerLayout(inv, sender, regular, bold, primary, accent),
        footer: (context) => _documentFooter(context, inv, regular, bold),
      ),
    );
    return doc.save();
  }

  if (tpl.name == 'Compact') {
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(82, 28, 82, 24),
        theme: theme,
        build: (_) =>
            _compactLayout(inv, sender, regular, bold, primary, accent),
        footer: (context) =>
            _documentFooter(context, inv, regular, bold, compact: true),
      ),
    );
    return doc.save();
  }

  // Fallback to Minimal
  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(42, 40, 42, 28),
      theme: theme,
      build: (_) => _minimalLayout(inv, sender, regular, bold, primary, accent),
      footer: (context) => _documentFooter(context, inv, regular, bold),
    ),
  );
  return doc.save();
}

Future<Uint8List> buildReceiptPdf(Invoice inv) async {
  final doc = pw.Document();
  final fonts = await _loadPdfFonts();
  final regular = fonts.sans;
  final bold = fonts.sansBold;
  final theme = pw.ThemeData.withFont(
    base: regular,
    bold: bold,
    fontFallback: fonts.fallbacks,
  );
  final sender = Prefs.bizName.value.isNotEmpty
      ? Prefs.bizName.value
      : Prefs.yourName.value.isNotEmpty
          ? Prefs.yourName.value
          : 'Invoy';
  final payments = inv.payments;

  doc.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(42, 42, 42, 36),
      theme: theme,
      build: (_) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      sender,
                      style: pw.TextStyle(
                        font: bold,
                        fontSize: 18,
                        color: _black,
                      ),
                    ),
                    if (Prefs.gstNum.value.trim().isNotEmpty) ...[
                      pw.SizedBox(height: 4),
                      pw.Text(
                        'GSTIN: ${Prefs.gstNum.value.trim()}',
                        style: pw.TextStyle(
                          font: regular,
                          fontSize: 9,
                          color: _grey5,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text(
                    'PAYMENT RECEIPT',
                    style: pw.TextStyle(
                      font: bold,
                      fontSize: 20,
                      color: _black,
                    ),
                  ),
                  pw.SizedBox(height: 5),
                  pw.Text(
                    inv.displayNumber,
                    style: pw.TextStyle(
                      font: regular,
                      fontSize: 10,
                      color: _grey5,
                    ),
                  ),
                ],
              ),
            ],
          ),
          pw.SizedBox(height: 20),
          pw.Container(height: 1.2, color: _black),
          pw.SizedBox(height: 22),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: _gstBox(
                  'Received from',
                  [
                    inv.client.name.isNotEmpty
                        ? inv.client.name
                        : 'Unnamed Client',
                    if (inv.client.address.isNotEmpty) inv.client.address,
                    if (_deliveryAddress(inv) != null)
                      'Delivery: ${_deliveryAddress(inv)}',
                    if (inv.client.gstin.isNotEmpty)
                      'GSTIN: ${inv.client.gstin}',
                  ],
                  regular,
                  bold,
                ),
              ),
              pw.SizedBox(width: 14),
              pw.Expanded(
                child: _gstBox(
                  'Against invoice',
                  [
                    'Invoice no: ${inv.displayNumber}',
                    'Invoice date: ${fDate(inv.date)}',
                    'Invoice total: ${_pdfAmt(inv.total)}',
                    'Paid so far: ${_pdfAmt(inv.paidAmt)}',
                    'Balance due: ${_pdfAmt(inv.balance)}',
                  ],
                  regular,
                  bold,
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 24),
          pw.Table(
            border: pw.TableBorder.all(color: _grey1, width: 0.6),
            columnWidths: const {
              0: pw.FlexColumnWidth(2),
              1: pw.FlexColumnWidth(2),
              2: pw.FlexColumnWidth(2),
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: _grey05),
                children: _gstCells(
                  ['Date', 'Mode', 'Amount'],
                  bold,
                  header: true,
                ),
              ),
              if (payments.isEmpty)
                pw.TableRow(
                  children: [
                    _gstCell('-', regular, align: pw.TextAlign.center),
                    _gstCell(
                      'No payments recorded',
                      regular,
                      align: pw.TextAlign.center,
                    ),
                    _gstCell('-', regular, align: pw.TextAlign.right),
                  ],
                )
              else
                ...payments.map(
                  (p) => pw.TableRow(
                    children: [
                      _gstCell(
                        fDate(p.date),
                        regular,
                        align: pw.TextAlign.center,
                      ),
                      _gstCell(
                        _paymentModeLabel(p.mode),
                        regular,
                        align: pw.TextAlign.center,
                      ),
                      _gstCell(
                        _pdfAmt(p.amount),
                        bold,
                        align: pw.TextAlign.right,
                      ),
                    ],
                  ),
                ),
            ],
          ),
          pw.SizedBox(height: 20),
          pw.SizedBox(width: 240, child: _gstTotals(inv, regular, bold)),
          pw.Spacer(),
          _signatureLine(sender, regular, bold),
        ],
      ),
    ),
  );

  return doc.save();
}

List<pw.Widget> _gstInvoiceLayout(
  Invoice inv,
  String sender,
  pw.Font regular,
  pw.Font bold,
) =>
    [
      pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(
            child: _businessIdentity(
              sender,
              regular,
              bold,
              titleSize: 18,
            ),
          ),
          pw.SizedBox(width: 30),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text(
                'TAX INVOICE',
                style: pw.TextStyle(
                  font: bold,
                  fontSize: 22,
                  color: _black,
                  letterSpacing: 1.2,
                ),
              ),
              pw.SizedBox(height: 6),
              pw.Text(
                'ORIGINAL FOR RECIPIENT',
                style: pw.TextStyle(
                  font: bold,
                  fontSize: 7.5,
                  color: _grey5,
                  letterSpacing: 1.1,
                ),
              ),
            ],
          ),
        ],
      ),
      pw.SizedBox(height: 16),
      pw.Container(height: 2, color: _black),
      pw.Container(
        padding: const pw.EdgeInsets.symmetric(vertical: 10),
        decoration: const pw.BoxDecoration(
          border: pw.Border(bottom: pw.BorderSide(color: _grey1, width: 0.7)),
        ),
        child: pw.Row(
          children: [
            pw.Expanded(
                child: _inlineMeta(
              'Invoice no',
              inv.displayNumber,
              regular,
              bold,
            )),
            pw.Expanded(
              child:
                  _inlineMeta('Invoice date', fDate(inv.date), regular, bold),
            ),
            pw.Expanded(
              child: _inlineMeta('Due date', fDate(inv.due), regular, bold),
            ),
            pw.Expanded(
              child: _inlineMeta(
                'Place of supply',
                _placeOfSupply(inv),
                regular,
                bold,
              ),
            ),
          ],
        ),
      ),
      pw.SizedBox(height: 22),
      pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(
            child: _gstInfoColumn(
              'Bill to',
              [
                inv.client.name.isNotEmpty ? inv.client.name : 'Unnamed Client',
                if (inv.client.address.isNotEmpty) inv.client.address,
                if (inv.client.state.isNotEmpty)
                  'State: ${gstStateWithCode(inv.client.state)}',
                if (inv.client.gstin.isNotEmpty) 'GSTIN: ${inv.client.gstin}',
                if (inv.client.email.isNotEmpty) inv.client.email,
                if (inv.client.phone.isNotEmpty) inv.client.phone,
                if (_deliveryAddress(inv) != null)
                  'Delivery: ${_deliveryAddress(inv)}',
              ],
              regular,
              bold,
            ),
          ),
          pw.SizedBox(width: 42),
          pw.Expanded(
            child: _gstInfoColumn(
              'Supply details',
              [
                'Tax type: ${inv.splitGst ? 'CGST + SGST' : 'IGST'}',
                'Place of supply: ${_placeOfSupply(inv)}',
                'Reverse charge: ${inv.reverseCharge ? 'Yes' : 'No'}',
                'Payment terms: ${inv.termDays == 0 ? 'Due on receipt' : 'Net ${inv.termDays}'}',
              ],
              regular,
              bold,
            ),
          ),
        ],
      ),
      pw.SizedBox(height: 20),
      _gstItemTable(inv, regular, bold),
      pw.SizedBox(height: 22),
      pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'Notes',
                  style: pw.TextStyle(font: bold, color: _black, fontSize: 10),
                ),
                pw.SizedBox(height: 5),
                pw.Text(
                  inv.notes.isNotEmpty
                      ? inv.notes
                      : 'Thank you for your business.',
                  style: pw.TextStyle(
                    font: regular,
                    color: _grey5,
                    fontSize: 9,
                    height: 1.35,
                  ),
                ),
                _paymentHistoryPdf(inv, regular, bold),
                _upiQrBlock(inv, regular, bold),
              ],
            ),
          ),
          pw.SizedBox(width: 36),
          pw.SizedBox(width: 220, child: _gstTotals(inv, regular, bold)),
        ],
      ),
      pw.SizedBox(height: 26),
      _signatureLine(sender, regular, bold),
      pw.SizedBox(height: 12),
    ];

pw.Widget _gstInfoColumn(
  String title,
  List<String> lines,
  pw.Font regular,
  pw.Font bold,
) =>
    pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          title.toUpperCase(),
          style: pw.TextStyle(
            font: bold,
            fontSize: 8,
            color: _grey5,
            letterSpacing: 0.8,
          ),
        ),
        pw.SizedBox(height: 8),
        ...lines.where((line) => line.trim().isNotEmpty).map(
              (line) => pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 3),
                child: pw.Text(
                  line,
                  style: pw.TextStyle(
                    font: regular,
                    fontSize: 9,
                    color: _black,
                    height: 1.25,
                  ),
                  maxLines: 2,
                  overflow: pw.TextOverflow.clip,
                ),
              ),
            ),
      ],
    );

pw.Widget _gstBox(
  String title,
  List<String> lines,
  pw.Font regular,
  pw.Font bold,
) =>
    pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: _grey05,
        border: pw.Border.all(color: _grey1, width: 0.8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            title.toUpperCase(),
            style: pw.TextStyle(font: bold, fontSize: 8, color: _grey5),
          ),
          pw.SizedBox(height: 7),
          ...lines.where((l) => l.trim().isNotEmpty).map(
                (line) => pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 3),
                  child: pw.Text(
                    line,
                    style:
                        pw.TextStyle(font: regular, fontSize: 9, color: _black),
                    maxLines: 2,
                    overflow: pw.TextOverflow.clip,
                  ),
                ),
              ),
        ],
      ),
    );

pw.Widget _gstItemTable(Invoice inv, pw.Font regular, pw.Font bold) {
  final tax2Label = inv.splitGst ? 'SGST' : 'IGST';
  return pw.Table(
    border: const pw.TableBorder(
      top: pw.BorderSide(color: _black, width: 0.8),
      bottom: pw.BorderSide(color: _black, width: 0.8),
      horizontalInside: pw.BorderSide(color: _grey1, width: 0.55),
    ),
    columnWidths: const {
      0: pw.FlexColumnWidth(2.5),
      1: pw.FixedColumnWidth(48),
      2: pw.FixedColumnWidth(48),
      3: pw.FixedColumnWidth(60),
      4: pw.FixedColumnWidth(38),
      5: pw.FixedColumnWidth(54),
      6: pw.FixedColumnWidth(54),
      7: pw.FixedColumnWidth(62),
    },
    children: [
      pw.TableRow(
        decoration: const pw.BoxDecoration(color: _black),
        children: _gstCells(
          [
            'Item',
            'HSN/SAC',
            'Qty',
            'Taxable',
            'GST %',
            'CGST',
            tax2Label,
            'Total',
          ],
          bold,
          header: true,
          headerText: _white,
        ),
      ),
      if (inv.items.isEmpty)
        pw.TableRow(
          children: [
            _gstCell('No items', regular),
            _gstCell('-', regular, align: pw.TextAlign.center),
            _gstCell('-', regular, align: pw.TextAlign.center),
            _gstCell('-', regular, align: pw.TextAlign.right),
            _gstCell('-', regular, align: pw.TextAlign.center),
            _gstCell('-', regular, align: pw.TextAlign.right),
            _gstCell('-', regular, align: pw.TextAlign.right),
            _gstCell('-', regular, align: pw.TextAlign.right),
          ],
        )
      else
        ...inv.items.map((item) {
          final taxable = inv.taxableFor(item);
          final tax = inv.taxFor(item);
          final cgst = inv.splitGst
              ? double.parse((tax / 2).toStringAsFixed(2))
              : 0.0;
          final tax2 = inv.splitGst
              ? double.parse((tax - cgst).toStringAsFixed(2))
              : tax;
          final lineTotal = taxable + tax;
          return pw.TableRow(
            children: [
              _gstCell(item.desc, regular),
              _gstCell(
                item.hsnSac.isEmpty ? '-' : item.hsnSac,
                regular,
                align: pw.TextAlign.center,
              ),
              _gstCell(
                '${_qty(item.qty)} ${item.unit}',
                regular,
                align: pw.TextAlign.center,
              ),
              _gstCell(_pdfAmt(taxable), regular, align: pw.TextAlign.right),
              _gstCell(
                _pctPdf(inv.taxRateFor(item)),
                regular,
                align: pw.TextAlign.center,
              ),
              _gstCell(
                cgst == 0 ? '-' : _pdfAmt(cgst),
                regular,
                align: pw.TextAlign.right,
              ),
              _gstCell(_pdfAmt(tax2), regular, align: pw.TextAlign.right),
              _gstCell(_pdfAmt(lineTotal), bold, align: pw.TextAlign.right),
            ],
          );
        }),
    ],
  );
}

List<pw.Widget> _gstCells(
  List<String> labels,
  pw.Font font, {
  bool header = false,
  PdfColor? headerText,
}) =>
    labels
        .map(
          (label) => _gstCell(
            label,
            font,
            header: header,
            color: header ? headerText : null,
            align: label == 'Item' ? pw.TextAlign.left : pw.TextAlign.center,
          ),
        )
        .toList();

pw.Widget _gstCell(
  String text,
  pw.Font font, {
  bool header = false,
  pw.TextAlign align = pw.TextAlign.left,
  PdfColor? color,
}) =>
    pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 7),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(
          font: font,
          fontSize: header ? 7.5 : 8,
          color: color ?? (header ? _grey5 : _black),
        ),
      ),
    );

pw.Widget _gstTotals(Invoice inv, pw.Font regular, pw.Font bold) => pw.Column(
      children: [
        _totalRow('Taxable value', _pdfAmt(inv.taxableSub), regular, bold),
        if (inv.discountAmount > 0) ...[
          pw.SizedBox(height: 5),
          _totalRow(
            'Discount',
            '-${_pdfAmt(inv.discountAmount)}',
            regular,
            bold,
            sub: true,
          ),
        ],
        if (inv.splitGst && inv.gst > 0) ...[
          pw.SizedBox(height: 5),
          _totalRow('CGST', _pdfAmt(inv.cgst), regular, bold, sub: true),
          pw.SizedBox(height: 4),
          _totalRow('SGST', _pdfAmt(inv.sgst), regular, bold, sub: true),
        ] else if (inv.gst > 0) ...[
          pw.SizedBox(height: 5),
          _totalRow('IGST', _pdfAmt(inv.igst), regular, bold, sub: true),
        ],
        pw.SizedBox(height: 5),
        _totalRow('Total GST', _pdfAmt(inv.tax), regular, bold, sub: true),
        pw.SizedBox(height: 8),
        pw.Container(height: 1, color: _grey1),
        pw.SizedBox(height: 8),
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(vertical: 10),
          decoration: const pw.BoxDecoration(
            border: pw.Border(
              top: pw.BorderSide(color: _black, width: 1.1),
              bottom: pw.BorderSide(color: _black, width: 1.1),
            ),
          ),
          child: _totalRow('Invoice total', _pdfAmt(inv.total), regular, bold),
        ),
        if (inv.paidAmt > 0) ...[
          pw.SizedBox(height: 7),
          _totalRow('Paid', _pdfAmt(inv.paidAmt), regular, bold, sub: true),
          if (inv.balance > 0) ...[
            pw.SizedBox(height: 5),
            _totalRow('Balance due', _pdfAmt(inv.balance), regular, bold),
          ],
        ],
      ],
    );

List<pw.Widget> _classicLayout(
  Invoice inv,
  String sender,
  pw.Font regular,
  pw.Font bold,
  PdfColor primary,
  PdfColor accent,
) =>
    [
      pw.Center(
        child: pw.Column(
          children: [
            pw.Text(
              sender,
              style: pw.TextStyle(font: bold, fontSize: 23, color: primary),
            ),
            if (Prefs.bizAddress.value.trim().isNotEmpty) ...[
              pw.SizedBox(height: 4),
              pw.Text(
                Prefs.bizAddress.value.trim(),
                textAlign: pw.TextAlign.center,
                style: pw.TextStyle(font: regular, fontSize: 9, color: _grey5),
              ),
            ],
            if (Prefs.gstNum.value.trim().isNotEmpty) ...[
              pw.SizedBox(height: 3),
              pw.Text(
                'GSTIN ${Prefs.gstNum.value.trim()}',
                style: pw.TextStyle(font: bold, fontSize: 8.5, color: _black),
              ),
            ],
          ],
        ),
      ),
      pw.SizedBox(height: 18),
      pw.Container(height: 1.4, color: primary),
      pw.SizedBox(height: 3),
      pw.Container(height: 0.5, color: accent),
      pw.SizedBox(height: 22),
      pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(
            child: pw.Text(
              _documentTitle(inv),
              style: pw.TextStyle(
                font: bold,
                fontSize: 28,
                color: _black,
                letterSpacing: 1,
              ),
            ),
          ),
          pw.SizedBox(
            width: 220,
            child: _invoiceMetaList(inv, regular, bold),
          ),
        ],
      ),
      pw.SizedBox(height: 26),
      pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(child: _clientMini(inv, regular, bold)),
          if (inv.gst > 0) ...[
            pw.SizedBox(width: 46),
            pw.SizedBox(
              width: 205,
              child: _taxContextBlock(inv, regular, bold),
            ),
          ],
        ],
      ),
      pw.SizedBox(height: 28),
      _professionalItemTable(inv, regular, bold),
      pw.SizedBox(height: 22),
      pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(child: _notesMini(inv, regular, bold)),
          pw.SizedBox(width: 36),
          pw.SizedBox(
            width: 220,
            child: _totalsMinimal(inv, regular, bold),
          ),
        ],
      ),
      pw.SizedBox(height: 30),
      _signatureLine(sender, regular, bold),
    ];

List<pw.Widget> _minimalLayout(
  Invoice inv,
  String sender,
  pw.Font regular,
  pw.Font bold,
  PdfColor primary,
  PdfColor accent,
) =>
    [
      pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(
            child: _businessIdentity(
              sender,
              regular,
              bold,
              titleSize: 15,
            ),
          ),
          pw.SizedBox(width: 24),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text(
                _documentTitle(inv),
                style: pw.TextStyle(
                  font: bold,
                  fontSize: 10,
                  color: primary,
                  letterSpacing: 1.6,
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                inv.displayNumber,
                style: pw.TextStyle(
                  font: regular,
                  fontSize: 10,
                  color: _grey5,
                ),
              ),
            ],
          ),
        ],
      ),
      pw.SizedBox(height: 38),
      pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.end,
        children: [
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  inv.balance > 0 ? 'AMOUNT DUE' : 'INVOICE TOTAL',
                  style: pw.TextStyle(
                    font: bold,
                    fontSize: 8,
                    color: _grey5,
                    letterSpacing: 1.1,
                  ),
                ),
                pw.SizedBox(height: 7),
                pw.Text(
                  _pdfAmt(inv.balance > 0 ? inv.balance : inv.total),
                  style: pw.TextStyle(font: bold, fontSize: 30, color: _black),
                ),
              ],
            ),
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text(
                inv.statusLabel.toUpperCase(),
                style: pw.TextStyle(font: bold, fontSize: 8.5, color: _black),
              ),
              pw.SizedBox(height: 5),
              pw.Text(
                'Due ${fDate(inv.due)}',
                style: pw.TextStyle(font: regular, fontSize: 9, color: _grey5),
              ),
            ],
          ),
        ],
      ),
      pw.SizedBox(height: 20),
      pw.Container(height: 1, color: accent),
      pw.SizedBox(height: 24),
      pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(child: _clientMini(inv, regular, bold)),
          pw.SizedBox(width: 46),
          pw.SizedBox(
            width: 205,
            child: _invoiceMetaList(inv, regular, bold),
          ),
        ],
      ),
      if (inv.gst > 0) ...[
        pw.SizedBox(height: 18),
        pw.Row(
          children: [
            pw.Expanded(
              child: _inlineMeta(
                'Tax',
                inv.splitGst ? 'CGST + SGST' : 'IGST',
                regular,
                bold,
              ),
            ),
            pw.Expanded(
              child: _inlineMeta(
                'Place of supply',
                _placeOfSupply(inv),
                regular,
                bold,
              ),
            ),
            pw.Expanded(
              child: _inlineMeta(
                'Reverse charge',
                inv.reverseCharge ? 'Yes' : 'No',
                regular,
                bold,
              ),
            ),
          ],
        ),
      ],
      pw.SizedBox(height: 30),
      _minimalItemTable(inv, regular, bold),
      pw.SizedBox(height: 28),
      pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(child: _notesMini(inv, regular, bold)),
          pw.SizedBox(width: 52),
          pw.SizedBox(
            width: 210,
            child: _totalsMinimal(inv, regular, bold),
          ),
        ],
      ),
      pw.SizedBox(height: 26),
      _signatureLine(sender, regular, bold),
    ];

List<pw.Widget> _ledgerLayout(
  Invoice inv,
  String sender,
  pw.Font regular,
  pw.Font bold,
  PdfColor primary,
  PdfColor accent,
) =>
    [
      pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'BILLING LEDGER',
                  style: pw.TextStyle(
                    font: bold,
                    fontSize: 8,
                    color: _grey5,
                    letterSpacing: 1.2,
                  ),
                ),
                pw.SizedBox(height: 8),
                _businessIdentity(
                  sender,
                  regular,
                  bold,
                  titleSize: 21,
                ),
              ],
            ),
          ),
          pw.SizedBox(width: 26),
          _balancePanel(inv, regular, bold, primary),
        ],
      ),
      pw.SizedBox(height: 22),
      _invoiceMetaStrip(inv, regular, bold),
      pw.SizedBox(height: 26),
      pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            width: 3,
            height: 88,
            decoration: pw.BoxDecoration(
              color: accent,
              borderRadius: pw.BorderRadius.circular(2),
            ),
          ),
          pw.SizedBox(width: 14),
          pw.Expanded(child: _clientMini(inv, regular, bold)),
          if (inv.gst > 0) ...[
            pw.SizedBox(width: 42),
            pw.SizedBox(
              width: 210,
              child: _taxContextBlock(inv, regular, bold),
            ),
          ],
        ],
      ),
      pw.SizedBox(height: 28),
      _ledgerItemTable(inv, regular, bold, accent),
      pw.SizedBox(height: 26),
      pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(child: _notesMini(inv, regular, bold)),
          pw.SizedBox(width: 46),
          pw.SizedBox(
            width: 222,
            child: _totalsMinimal(inv, regular, bold),
          ),
        ],
      ),
      pw.SizedBox(height: 26),
      _signatureLine(sender, regular, bold),
    ];

List<pw.Widget> _compactLayout(
  Invoice inv,
  String sender,
  pw.Font regular,
  pw.Font bold,
  PdfColor primary,
  PdfColor accent,
) =>
    [
      pw.Center(
        child: pw.Column(
          children: [
            pw.Text(
              sender.toUpperCase(),
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(font: bold, fontSize: 17, color: _black),
            ),
            if (Prefs.bizAddress.value.trim().isNotEmpty) ...[
              pw.SizedBox(height: 4),
              pw.Text(
                Prefs.bizAddress.value.trim(),
                textAlign: pw.TextAlign.center,
                style:
                    pw.TextStyle(font: regular, fontSize: 7.5, color: _grey5),
              ),
            ],
            if (Prefs.gstNum.value.trim().isNotEmpty) ...[
              pw.SizedBox(height: 3),
              pw.Text(
                'GSTIN ${Prefs.gstNum.value.trim()}',
                style: pw.TextStyle(font: bold, fontSize: 7.5, color: _black),
              ),
            ],
          ],
        ),
      ),
      pw.SizedBox(height: 10),
      _receiptRule(regular),
      pw.SizedBox(height: 8),
      pw.Center(
        child: pw.Text(
          _documentTitle(inv),
          style: pw.TextStyle(
            font: bold,
            fontSize: 11,
            color: primary,
            letterSpacing: 1.5,
          ),
        ),
      ),
      pw.SizedBox(height: 10),
      _compactInvoiceMeta(inv, regular, bold),
      pw.SizedBox(height: 8),
      _receiptRule(regular),
      pw.SizedBox(height: 10),
      _compactPartyTable(inv, regular, bold, accent),
      pw.SizedBox(height: 10),
      _receiptRule(regular),
      pw.SizedBox(height: 8),
      _compactItemTable(inv, regular, bold, accent),
      pw.SizedBox(height: 8),
      _receiptRule(regular),
      pw.SizedBox(height: 9),
      _totalsMinimal(inv, regular, bold),
      if (inv.notes.trim().isNotEmpty) ...[
        pw.SizedBox(height: 12),
        pw.Text(
          'NOTE',
          style: pw.TextStyle(font: bold, fontSize: 7.5, color: _black),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          inv.notes.trim(),
          style: pw.TextStyle(
            font: regular,
            fontSize: 7.5,
            color: _grey5,
            height: 1.3,
          ),
        ),
      ],
      _paymentHistoryPdf(inv, regular, bold, compact: true),
      _upiQrBlock(inv, regular, bold, size: 58, compact: true),
      pw.SizedBox(height: 18),
      _receiptRule(regular),
      pw.SizedBox(height: 10),
      pw.Center(
        child: pw.Column(
          children: [
            _signatureMark(width: 110, height: 28),
            pw.Container(width: 130, height: 1, color: _grey1),
            pw.SizedBox(height: 5),
            pw.Text(
              'AUTHORISED SIGNATORY',
              style: pw.TextStyle(font: bold, fontSize: 7.5, color: _black),
            ),
            pw.SizedBox(height: 3),
            pw.Text(
              sender,
              style: pw.TextStyle(font: regular, fontSize: 7, color: _grey5),
            ),
            pw.SizedBox(height: 8),
            pw.Text(
              'THANK YOU',
              style: pw.TextStyle(
                font: bold,
                fontSize: 8,
                color: _black,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
      ),
    ];

pw.Widget _receiptRule(pw.Font regular) => pw.Text(
      '--------------------------------------------------------',
      maxLines: 1,
      textAlign: pw.TextAlign.center,
      style: pw.TextStyle(font: regular, fontSize: 7.5, color: _grey5),
    );

String _documentTitle(Invoice inv) => inv.gst > 0 ? 'TAX INVOICE' : 'INVOICE';

pw.Widget _businessIdentity(
  String sender,
  pw.Font regular,
  pw.Font bold, {
  double titleSize = 18,
  bool compact = false,
}) {
  final address = Prefs.bizAddress.value.trim();
  final state = Prefs.bizState.value.trim();
  final gstin = Prefs.gstNum.value.trim();
  final double detailSize = compact ? 8 : 8.5;
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Text(
        sender,
        style: pw.TextStyle(font: bold, fontSize: titleSize, color: _black),
      ),
      if (address.isNotEmpty) ...[
        pw.SizedBox(height: 4),
        pw.Text(
          address,
          style: pw.TextStyle(
            font: regular,
            fontSize: detailSize,
            color: _grey5,
          ),
        ),
      ],
      if (state.isNotEmpty) ...[
        pw.SizedBox(height: 2),
        pw.Text(
          'State: ${gstStateWithCode(state)}',
          style: pw.TextStyle(
            font: regular,
            fontSize: detailSize,
            color: _grey5,
          ),
        ),
      ],
      if (gstin.isNotEmpty) ...[
        pw.SizedBox(height: 2),
        pw.Text(
          'GSTIN: $gstin',
          style: pw.TextStyle(
            font: bold,
            fontSize: detailSize,
            color: _black,
          ),
        ),
      ],
    ],
  );
}

pw.Widget _invoiceMetaList(
  Invoice inv,
  pw.Font regular,
  pw.Font bold,
) =>
    pw.Column(
      children: [
        _metaRow('Invoice no', inv.displayNumber, regular, bold),
        pw.SizedBox(height: 7),
        _metaRow('Issue date', fDate(inv.date), regular, bold),
        pw.SizedBox(height: 7),
        _metaRow('Due date', fDate(inv.due), regular, bold),
        pw.SizedBox(height: 7),
        _metaRow(
          'Terms',
          inv.termDays == 0 ? 'Due on receipt' : 'Net ${inv.termDays}',
          regular,
          bold,
        ),
      ],
    );

pw.Widget _taxContextBlock(
  Invoice inv,
  pw.Font regular,
  pw.Font bold,
) =>
    pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'TAX DETAILS',
          style: pw.TextStyle(font: bold, fontSize: 8, color: _grey5),
        ),
        pw.SizedBox(height: 7),
        _metaRow(
          'Type',
          inv.splitGst ? 'CGST + SGST' : 'IGST',
          regular,
          bold,
        ),
        pw.SizedBox(height: 6),
        _metaRow('Place', _placeOfSupply(inv), regular, bold),
        pw.SizedBox(height: 6),
        _metaRow(
          'Reverse charge',
          inv.reverseCharge ? 'Yes' : 'No',
          regular,
          bold,
        ),
      ],
    );

pw.Widget _inlineMeta(
  String label,
  String value,
  pw.Font regular,
  pw.Font bold,
) =>
    pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          label,
          style: pw.TextStyle(font: regular, fontSize: 7.5, color: _grey5),
        ),
        pw.SizedBox(height: 3),
        pw.Text(
          value,
          style: pw.TextStyle(font: bold, fontSize: 8.5, color: _black),
        ),
      ],
    );

pw.Widget _invoiceMetaStrip(
  Invoice inv,
  pw.Font regular,
  pw.Font bold,
) =>
    pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 10),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          top: pw.BorderSide(color: _grey1),
          bottom: pw.BorderSide(color: _grey1),
        ),
      ),
      child: pw.Row(
        children: [
          pw.Expanded(
            child: _inlineMeta(
              'Invoice no',
              inv.displayNumber,
              regular,
              bold,
            ),
          ),
          pw.Expanded(
            child: _inlineMeta('Issue date', fDate(inv.date), regular, bold),
          ),
          pw.Expanded(
            child: _inlineMeta('Due date', fDate(inv.due), regular, bold),
          ),
          pw.Expanded(
            child: _inlineMeta(
              'Terms',
              inv.termDays == 0 ? 'Due on receipt' : 'Net ${inv.termDays}',
              regular,
              bold,
            ),
          ),
        ],
      ),
    );

pw.Widget _balancePanel(
  Invoice inv,
  pw.Font regular,
  pw.Font bold,
  PdfColor fill,
) =>
    pw.Container(
      width: 190,
      padding: const pw.EdgeInsets.fromLTRB(16, 13, 16, 14),
      decoration: pw.BoxDecoration(
        color: fill,
        borderRadius: pw.BorderRadius.circular(14),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.end,
        children: [
          pw.Text(
            inv.balance > 0 ? 'BALANCE DUE' : 'STATUS',
            style: pw.TextStyle(
              font: regular,
              fontSize: 7.5,
              color: _grey1,
              letterSpacing: 0.8,
            ),
          ),
          pw.SizedBox(height: 5),
          pw.Text(
            inv.balance > 0 ? _pdfAmt(inv.balance) : 'PAID IN FULL',
            textAlign: pw.TextAlign.right,
            style: pw.TextStyle(font: bold, fontSize: 16, color: _white),
          ),
        ],
      ),
    );

pw.Widget _professionalItemTable(
  Invoice inv,
  pw.Font regular,
  pw.Font bold, {
  PdfColor headerFill = _white,
  PdfColor headerText = _grey5,
}) =>
    pw.Table(
      border: const pw.TableBorder(
        top: pw.BorderSide(color: _grey1, width: 0.8),
        bottom: pw.BorderSide(color: _grey1, width: 0.8),
        horizontalInside: pw.BorderSide(color: _grey1, width: 0.6),
      ),
      columnWidths: const {
        0: pw.FlexColumnWidth(4),
        1: pw.FixedColumnWidth(62),
        2: pw.FixedColumnWidth(78),
        3: pw.FixedColumnWidth(86),
      },
      children: [
        pw.TableRow(
          decoration: pw.BoxDecoration(color: headerFill),
          children: [
            _professionalCell(
              'Item & description',
              bold,
              color: headerText,
              header: true,
            ),
            _professionalCell(
              'Qty',
              bold,
              color: headerText,
              header: true,
              align: pw.TextAlign.center,
            ),
            _professionalCell(
              'Rate',
              bold,
              color: headerText,
              header: true,
              align: pw.TextAlign.right,
            ),
            _professionalCell(
              'Amount',
              bold,
              color: headerText,
              header: true,
              align: pw.TextAlign.right,
            ),
          ],
        ),
        if (inv.items.isEmpty)
          pw.TableRow(
            children: [
              _professionalCell('No items', regular, color: _grey5),
              _professionalCell('-', regular, align: pw.TextAlign.center),
              _professionalCell('-', regular, align: pw.TextAlign.right),
              _professionalCell('-', regular, align: pw.TextAlign.right),
            ],
          )
        else
          ...inv.items.map(
            (item) => pw.TableRow(
              children: [
                pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(
                      horizontal: 10, vertical: 10),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        item.desc,
                        style: pw.TextStyle(
                          font: bold,
                          fontSize: 9.5,
                          color: _black,
                        ),
                      ),
                      if (_itemTaxMeta(inv, item).isNotEmpty) ...[
                        pw.SizedBox(height: 3),
                        pw.Text(
                          _itemTaxMeta(inv, item),
                          style: pw.TextStyle(
                            font: regular,
                            fontSize: 7.5,
                            color: _grey5,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                _professionalCell(
                  '${_qty(item.qty)} ${item.unit}',
                  regular,
                  align: pw.TextAlign.center,
                ),
                _professionalCell(
                  _pdfAmt(item.rate),
                  regular,
                  align: pw.TextAlign.right,
                ),
                _professionalCell(
                  _pdfAmt(item.total),
                  bold,
                  align: pw.TextAlign.right,
                ),
              ],
            ),
          ),
      ],
    );

pw.Widget _minimalItemTable(
  Invoice inv,
  pw.Font regular,
  pw.Font bold,
) =>
    pw.Table(
      border: const pw.TableBorder(
        top: pw.BorderSide(color: _grey1, width: 0.7),
        bottom: pw.BorderSide(color: _grey1, width: 0.7),
        horizontalInside: pw.BorderSide(color: _grey1, width: 0.55),
      ),
      columnWidths: const {
        0: pw.FlexColumnWidth(),
        1: pw.FixedColumnWidth(112),
      },
      children: [
        pw.TableRow(
          children: [
            _professionalCell(
              'Description',
              bold,
              color: _grey5,
              header: true,
            ),
            _professionalCell(
              'Amount',
              bold,
              color: _grey5,
              header: true,
              align: pw.TextAlign.right,
            ),
          ],
        ),
        if (inv.items.isEmpty)
          pw.TableRow(
            children: [
              _professionalCell('No items', regular, color: _grey5),
              _professionalCell('-', regular, align: pw.TextAlign.right),
            ],
          )
        else
          ...inv.items.map(
            (item) => pw.TableRow(
              children: [
                pw.Padding(
                  padding: const pw.EdgeInsets.fromLTRB(10, 13, 10, 13),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        item.desc,
                        style: pw.TextStyle(
                          font: bold,
                          fontSize: 10,
                          color: _black,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        '${_qty(item.qty)} ${item.unit} x ${_pdfAmt(item.rate)}'
                        '${_itemTaxMeta(inv, item).isEmpty ? '' : '  |  ${_itemTaxMeta(inv, item)}'}',
                        style: pw.TextStyle(
                          font: regular,
                          fontSize: 7.5,
                          color: _grey5,
                        ),
                      ),
                    ],
                  ),
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.fromLTRB(10, 15, 10, 13),
                  child: pw.Text(
                    _pdfAmt(item.total),
                    textAlign: pw.TextAlign.right,
                    style: pw.TextStyle(
                      font: bold,
                      fontSize: 10,
                      color: _black,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );

pw.Widget _ledgerItemTable(
  Invoice inv,
  pw.Font regular,
  pw.Font bold,
  PdfColor accent,
) =>
    pw.Table(
      border: const pw.TableBorder(
        top: pw.BorderSide(color: _black, width: 1),
        bottom: pw.BorderSide(color: _black, width: 1),
        horizontalInside: pw.BorderSide(color: _grey1, width: 0.55),
      ),
      columnWidths: const {
        0: pw.FixedColumnWidth(38),
        1: pw.FlexColumnWidth(),
        2: pw.FixedColumnWidth(82),
        3: pw.FixedColumnWidth(82),
        4: pw.FixedColumnWidth(94),
      },
      children: [
        pw.TableRow(
          children: [
            _professionalCell('#', bold, color: _grey5, header: true),
            _professionalCell(
              'Entry',
              bold,
              color: _grey5,
              header: true,
            ),
            _professionalCell(
              'Taxable',
              bold,
              color: _grey5,
              header: true,
              align: pw.TextAlign.right,
            ),
            _professionalCell(
              'Tax',
              bold,
              color: _grey5,
              header: true,
              align: pw.TextAlign.right,
            ),
            _professionalCell(
              'Total',
              bold,
              color: _grey5,
              header: true,
              align: pw.TextAlign.right,
            ),
          ],
        ),
        if (inv.items.isEmpty)
          pw.TableRow(
            children: [
              _professionalCell('-', regular, color: _grey5),
              _professionalCell('No entries', regular, color: _grey5),
              _professionalCell('-', regular, align: pw.TextAlign.right),
              _professionalCell('-', regular, align: pw.TextAlign.right),
              _professionalCell('-', regular, align: pw.TextAlign.right),
            ],
          )
        else
          ...inv.items.asMap().entries.map((entry) {
            final item = entry.value;
            final tax = inv.taxFor(item);
            return pw.TableRow(
              children: [
                pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(vertical: 11),
                  child: pw.Center(
                    child: pw.Container(
                      width: 20,
                      height: 20,
                      decoration: pw.BoxDecoration(
                        color: accent,
                        shape: pw.BoxShape.circle,
                      ),
                      alignment: pw.Alignment.center,
                      child: pw.Text(
                        '${entry.key + 1}',
                        style: pw.TextStyle(
                          font: bold,
                          fontSize: 7.5,
                          color: _black,
                        ),
                      ),
                    ),
                  ),
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.fromLTRB(8, 10, 8, 10),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        item.desc,
                        style: pw.TextStyle(
                          font: bold,
                          fontSize: 9.5,
                          color: _black,
                        ),
                      ),
                      pw.SizedBox(height: 3),
                      pw.Text(
                        '${_qty(item.qty)} ${item.unit} x ${_pdfAmt(item.rate)}'
                        '${item.hsnSac.trim().isEmpty ? '' : '  |  HSN/SAC ${item.hsnSac.trim()}'}',
                        style: pw.TextStyle(
                          font: regular,
                          fontSize: 7.3,
                          color: _grey5,
                        ),
                      ),
                    ],
                  ),
                ),
                _professionalCell(
                  _pdfAmt(item.total),
                  regular,
                  align: pw.TextAlign.right,
                ),
                _professionalCell(
                  _pdfAmt(tax),
                  regular,
                  align: pw.TextAlign.right,
                ),
                _professionalCell(
                  _pdfAmt(item.total + tax),
                  bold,
                  align: pw.TextAlign.right,
                ),
              ],
            );
          }),
      ],
    );

pw.Widget _professionalCell(
  String text,
  pw.Font font, {
  pw.TextAlign align = pw.TextAlign.left,
  PdfColor color = _black,
  bool header = false,
}) =>
    pw.Padding(
      padding: pw.EdgeInsets.symmetric(
        horizontal: 10,
        vertical: header ? 8 : 10,
      ),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(
          font: font,
          fontSize: header ? 8.5 : 9,
          color: color,
        ),
      ),
    );

String _itemTaxMeta(Invoice inv, LineItem item) {
  final parts = <String>[];
  if (item.hsnSac.trim().isNotEmpty) {
    parts.add('HSN/SAC ${item.hsnSac.trim()}');
  }
  final rate = inv.taxRateFor(item);
  if (rate > 0) parts.add('GST ${_pctPdf(rate)}%');
  return parts.join('  |  ');
}

pw.Widget _signatureLine(
  String sender,
  pw.Font regular,
  pw.Font bold, {
  bool compact = false,
}) {
  return pw.Row(
    mainAxisAlignment: pw.MainAxisAlignment.end,
    children: [
      pw.Container(
        width: compact ? 150 : 170,
        child: pw.Column(
          children: [
            _signatureMark(
              width: compact ? 100 : 120,
              height: compact ? 24 : 30,
            ),
            pw.Container(height: 1, color: _grey1),
            pw.SizedBox(height: 5),
            pw.Text(
              'Authorised Signatory',
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(font: bold, fontSize: 8.5, color: _black),
            ),
            pw.SizedBox(height: 2),
            pw.Text(
              sender,
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(font: regular, fontSize: 7.5, color: _grey5),
            ),
          ],
        ),
      ),
    ],
  );
}

pw.Widget _signatureMark({required double width, required double height}) {
  final signature = _uploadedSignatureImage();
  return pw.SizedBox(
    width: width,
    height: height,
    child: signature == null
        ? pw.SizedBox()
        : pw.Image(signature, fit: pw.BoxFit.contain),
  );
}

pw.Widget _compactInvoiceMeta(
  Invoice inv,
  pw.Font regular,
  pw.Font bold,
) =>
    pw.Table(
      columnWidths: const {
        0: pw.FlexColumnWidth(),
        1: pw.FlexColumnWidth(),
      },
      children: [
        _compactMetaRow('Invoice no', inv.displayNumber, regular, bold),
        _compactMetaRow('Date', fDate(inv.date), regular, bold),
        _compactMetaRow('Due date', fDate(inv.due), regular, bold),
      ],
    );

pw.TableRow _compactMetaRow(
  String label,
  String value,
  pw.Font regular,
  pw.Font bold,
) =>
    pw.TableRow(
      children: [
        _compactCell(label, regular, color: _grey5),
        _compactCell(value, bold, align: pw.TextAlign.right),
      ],
    );

pw.Widget _compactPartyTable(
  Invoice inv,
  pw.Font regular,
  pw.Font bold,
  PdfColor fill,
) =>
    pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _compactInfoBlock(
          'BILL TO',
          [
            inv.client.name.isEmpty ? 'Unnamed Client' : inv.client.name,
            if (inv.client.address.isNotEmpty) inv.client.address,
            if (inv.client.state.isNotEmpty)
              'State: ${gstStateWithCode(inv.client.state)}',
            if (inv.client.gstin.isNotEmpty) 'GSTIN: ${inv.client.gstin}',
            if (inv.client.email.isNotEmpty) inv.client.email,
            if (_deliveryAddress(inv) != null)
              'Delivery: ${_deliveryAddress(inv)}',
          ],
          regular,
          bold,
          fill,
        ),
        pw.SizedBox(height: 9),
        _compactInfoBlock(
          inv.gst > 0 ? 'SUPPLY' : 'TERMS',
          [
            'Terms: ${inv.termDays == 0 ? 'Due on receipt' : 'Net ${inv.termDays}'}',
            if (inv.gst > 0) 'Tax: ${inv.splitGst ? 'CGST + SGST' : 'IGST'}',
            if (inv.gst > 0) 'Place: ${_placeOfSupply(inv)}',
            if (inv.gst > 0)
              'Reverse charge: ${inv.reverseCharge ? 'Yes' : 'No'}',
          ],
          regular,
          bold,
          fill,
        ),
      ],
    );

pw.Widget _compactInfoBlock(
  String title,
  List<String> lines,
  pw.Font regular,
  pw.Font bold,
  PdfColor fill,
) =>
    pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          title,
          style: pw.TextStyle(
            font: bold,
            fontSize: 7.5,
            color: _black,
            letterSpacing: 0.8,
          ),
        ),
        pw.SizedBox(height: 5),
        ...lines.where((line) => line.trim().isNotEmpty).map(
              (line) => pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 3),
                child: pw.Text(
                  line,
                  style: pw.TextStyle(
                    font: regular,
                    fontSize: 7.5,
                    color: _black,
                    height: 1.2,
                  ),
                ),
              ),
            ),
        pw.Container(
          width: 28,
          height: 1.2,
          margin: const pw.EdgeInsets.only(top: 2),
          decoration: pw.BoxDecoration(
            color: fill,
            borderRadius: pw.BorderRadius.circular(1),
          ),
        ),
      ],
    );

pw.Widget _compactItemTable(
  Invoice inv,
  pw.Font regular,
  pw.Font bold,
  PdfColor fill,
) =>
    pw.Table(
      border: const pw.TableBorder(
        top: pw.BorderSide(color: _black, width: 0.8),
        bottom: pw.BorderSide(color: _black, width: 0.8),
        horizontalInside: pw.BorderSide(color: _grey1, width: 0.5),
      ),
      columnWidths: const {
        0: pw.FlexColumnWidth(),
        1: pw.FixedColumnWidth(118),
        2: pw.FixedColumnWidth(84),
      },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: _white),
          children: [
            _compactCell('ITEM', bold, header: true),
            _compactCell(
              'QTY x RATE',
              bold,
              header: true,
              align: pw.TextAlign.right,
            ),
            _compactCell(
              'AMOUNT',
              bold,
              header: true,
              align: pw.TextAlign.right,
            ),
          ],
        ),
        if (inv.items.isEmpty)
          pw.TableRow(
            children: [
              _compactCell('No items', regular, color: _grey5),
              _compactCell('-', regular, align: pw.TextAlign.right),
              _compactCell('-', regular, align: pw.TextAlign.right),
            ],
          )
        else
          ...inv.items.map(
            (item) => pw.TableRow(
              children: [
                pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 8,
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        item.desc,
                        style: pw.TextStyle(
                          font: bold,
                          fontSize: 7.8,
                          color: _black,
                        ),
                      ),
                      if (_itemTaxMeta(inv, item).isNotEmpty) ...[
                        pw.SizedBox(height: 3),
                        pw.Text(
                          _itemTaxMeta(inv, item),
                          style: pw.TextStyle(
                            font: regular,
                            fontSize: 6.6,
                            color: _grey5,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 7,
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        '${_qty(item.qty)} ${item.unit}',
                        textAlign: pw.TextAlign.right,
                        style: pw.TextStyle(
                          font: regular,
                          fontSize: 7.5,
                          color: _black,
                        ),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        'x ${_pdfAmt(item.rate)}',
                        textAlign: pw.TextAlign.right,
                        style: pw.TextStyle(
                          font: regular,
                          fontSize: 6.8,
                          color: _grey5,
                        ),
                      ),
                    ],
                  ),
                ),
                _compactCell(
                  _pdfAmt(item.total),
                  bold,
                  align: pw.TextAlign.right,
                ),
              ],
            ),
          ),
      ],
    );

pw.Widget _compactCell(
  String text,
  pw.Font font, {
  pw.TextAlign align = pw.TextAlign.left,
  PdfColor color = _black,
  bool header = false,
}) =>
    pw.Padding(
      padding: pw.EdgeInsets.symmetric(
        horizontal: 6,
        vertical: header ? 6 : 7,
      ),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(
          font: font,
          fontSize: header ? 7.5 : 8,
          color: color,
        ),
      ),
    );

pw.Widget _documentFooter(
  pw.Context context,
  Invoice inv,
  pw.Font regular,
  pw.Font bold, {
  bool compact = false,
}) =>
    pw.Container(
      margin: pw.EdgeInsets.only(top: compact ? 8 : 12),
      padding: pw.EdgeInsets.only(top: compact ? 6 : 8),
      decoration: const pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(color: _grey1, width: 0.7)),
      ),
      child: pw.Row(
        children: [
          pw.Expanded(
            child: pw.Text(
              '${inv.displayNumber} - ${fDate(inv.date)}',
              style: pw.TextStyle(
                font: regular,
                fontSize: compact ? 7 : 7.5,
                color: _grey5,
              ),
            ),
          ),
          pw.Text(
            'Page ${context.pageNumber} of ${context.pagesCount}',
            style: pw.TextStyle(
              font: bold,
              fontSize: compact ? 7 : 7.5,
              color: _grey5,
            ),
          ),
        ],
      ),
    );

pw.Widget _clientMini(Invoice inv, pw.Font regular, pw.Font bold) => pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Bill to',
          style: pw.TextStyle(font: regular, color: _grey5, fontSize: 9),
        ),
        pw.SizedBox(height: 5),
        pw.Text(
          inv.client.name.isNotEmpty ? inv.client.name : 'Unnamed Client',
          style: pw.TextStyle(font: bold, color: _black, fontSize: 14),
        ),
        if (inv.client.address.isNotEmpty) ...[
          pw.SizedBox(height: 3),
          pw.Text(
            inv.client.address,
            style: pw.TextStyle(font: regular, color: _grey5, fontSize: 9),
          ),
        ],
        if (inv.client.state.isNotEmpty) ...[
          pw.SizedBox(height: 3),
          pw.Text(
            'State: ${gstStateWithCode(inv.client.state)}',
            style: pw.TextStyle(font: regular, color: _grey5, fontSize: 9),
          ),
        ],
        if (inv.client.gstin.isNotEmpty) ...[
          pw.SizedBox(height: 3),
          pw.Text(
            'GSTIN ${inv.client.gstin}',
            style: pw.TextStyle(font: regular, color: _grey5, fontSize: 9),
          ),
        ],
        if (inv.client.email.isNotEmpty) ...[
          pw.SizedBox(height: 3),
          pw.Text(
            inv.client.email,
            style: pw.TextStyle(font: regular, color: _grey5, fontSize: 9),
          ),
        ],
        if (inv.client.phone.isNotEmpty) ...[
          pw.SizedBox(height: 3),
          pw.Text(
            inv.client.phone,
            style: pw.TextStyle(font: regular, color: _grey5, fontSize: 9),
          ),
        ],
        if (_deliveryAddress(inv) != null) ...[
          pw.SizedBox(height: 3),
          pw.Text(
            'Delivery: ${_deliveryAddress(inv)}',
            style: pw.TextStyle(font: regular, color: _grey5, fontSize: 9),
          ),
        ],
      ],
    );

pw.Widget _metaRow(String label, String value, pw.Font regular, pw.Font bold) =>
    pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(
          label,
          style: pw.TextStyle(font: regular, color: _grey5, fontSize: 9),
        ),
        pw.Text(
          value,
          style: pw.TextStyle(font: bold, color: _black, fontSize: 9),
        ),
      ],
    );

pw.Widget _notesMini(Invoice inv, pw.Font regular, pw.Font bold) => pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Notes',
          style: pw.TextStyle(font: bold, color: _black, fontSize: 10),
        ),
        pw.SizedBox(height: 5),
        pw.Text(
          inv.notes.isNotEmpty ? inv.notes : 'Thank you for your business.',
          style: pw.TextStyle(font: regular, color: _grey5, fontSize: 9),
        ),
        _paymentHistoryPdf(inv, regular, bold),
        _upiQrBlock(inv, regular, bold),
      ],
    );

pw.Widget _paymentHistoryPdf(
  Invoice inv,
  pw.Font regular,
  pw.Font bold, {
  bool compact = false,
}) {
  if (inv.payments.isEmpty) return pw.SizedBox();
  final payments = inv.payments.take(compact ? 3 : 4).toList();
  final extra = inv.payments.length - payments.length;
  return pw.Padding(
    padding: pw.EdgeInsets.only(top: compact ? 8 : 12),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          compact ? 'PAYMENTS' : 'Payments',
          style: pw.TextStyle(
            font: bold,
            color: _black,
            fontSize: compact ? 7.5 : 9,
          ),
        ),
        pw.SizedBox(height: compact ? 4 : 6),
        ...payments.map(
          (p) => pw.Padding(
            padding: pw.EdgeInsets.only(bottom: compact ? 3 : 4),
            child: pw.Row(
              children: [
                pw.Expanded(
                  child: pw.Text(
                    '${fDate(p.date)} - ${_paymentModeLabel(p.mode)}',
                    style: pw.TextStyle(
                      font: regular,
                      color: _grey5,
                      fontSize: compact ? 7 : 8,
                    ),
                  ),
                ),
                pw.SizedBox(width: 8),
                pw.Text(
                  _pdfAmt(p.amount),
                  textAlign: pw.TextAlign.right,
                  style: pw.TextStyle(
                    font: bold,
                    color: _black,
                    fontSize: compact ? 7 : 8,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (extra > 0)
          pw.Text(
            '$extra more payment${extra == 1 ? '' : 's'} recorded',
            style: pw.TextStyle(
              font: regular,
              color: _grey5,
              fontSize: compact ? 7 : 8,
            ),
          ),
      ],
    ),
  );
}

pw.Widget _totalsMinimal(
  Invoice inv,
  pw.Font regular,
  pw.Font bold, {
  PdfColor? accent,
}) =>
    pw.Column(
      children: [
        _totalRow('Subtotal', _pdfAmt(inv.sub), regular, bold),
        if (inv.discountAmount > 0) ...[
          pw.SizedBox(height: 6),
          _totalRow(
            'Discount',
            '-${_pdfAmt(inv.discountAmount)}',
            regular,
            bold,
            sub: true,
          ),
        ],
        if (inv.splitGst && inv.gst > 0) ...[
          pw.SizedBox(height: 6),
          _totalRow(
            _pdfTaxBreakupLabel(inv, 'CGST'),
            _pdfAmt(inv.cgst),
            regular,
            bold,
            sub: true,
          ),
          pw.SizedBox(height: 4),
          _totalRow(
            _pdfTaxBreakupLabel(inv, 'SGST'),
            _pdfAmt(inv.sgst),
            regular,
            bold,
            sub: true,
          ),
        ] else if (inv.gst > 0) ...[
          pw.SizedBox(height: 6),
          _totalRow(
            _pdfTaxBreakupLabel(inv, 'IGST'),
            _pdfAmt(inv.igst),
            regular,
            bold,
            sub: true,
          ),
        ],
        pw.SizedBox(height: 10),
        pw.Container(height: 1, color: accent ?? _grey1),
        pw.SizedBox(height: 10),
        accent == null
            ? _totalRow('Invoice total', _pdfAmt(inv.total), regular, bold)
            : pw.Container(
                padding:
                    const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                color: accent,
                child: _totalRow(
                  'Invoice total',
                  _pdfAmt(inv.total),
                  regular,
                  bold,
                ),
              ),
        if (inv.paidAmt > 0) ...[
          pw.SizedBox(height: 8),
          _totalRow('Paid', _pdfAmt(inv.paidAmt), regular, bold, sub: true),
          if (inv.balance > 0) ...[
            pw.SizedBox(height: 6),
            _totalRow('Balance due', _pdfAmt(inv.balance), regular, bold),
          ],
        ],
      ],
    );

// ─── Helpers ─────────────────────────────────────────────────────

PdfColor _pdfColor(Color c) => PdfColor.fromInt(c.toARGB32());

String _pdfAmt(double value) {
  final text = amtUi(value.abs(), maxChars: 20);
  return value < 0 ? '-$text' : text;
}

@visibleForTesting
String pdfAmountForTesting(double value) => _pdfAmt(value);

String _qty(double value) {
  if (value == value.roundToDouble()) return value.toInt().toString();
  return value.toStringAsFixed(2).replaceFirst(RegExp(r'\.?0+$'), '');
}

String _pctPdf(double value) {
  if (value == value.roundToDouble()) return value.toStringAsFixed(0);
  return value.toStringAsFixed(1);
}

String _pdfTaxBreakupLabel(Invoice inv, String label) {
  final rates = inv.items
      .map(inv.taxRateFor)
      .where((rate) => rate > 0)
      .map((rate) => rate.toStringAsFixed(3))
      .toSet();
  if (rates.length != 1) return label;
  final rate = double.parse(rates.first);
  final shown = label == 'IGST' ? rate : rate / 2;
  return '$label (${_pctPdf(shown)}%)';
}

String _placeOfSupply(Invoice inv) {
  if (inv.placeOfSupply.trim().isNotEmpty) {
    return gstStateWithCode(inv.placeOfSupply.trim());
  }
  if (inv.client.state.trim().isNotEmpty) {
    return gstStateWithCode(inv.client.state.trim());
  }
  return 'Not set';
}

String? _deliveryAddress(Invoice inv) {
  final delivery = inv.deliveryAddress.trim();
  if (delivery.isEmpty || delivery == inv.client.address.trim()) return null;
  return delivery;
}

String _paymentModeLabel(PayMode mode) => switch (mode) {
      PayMode.upi => 'UPI',
      PayMode.bank => 'Bank',
      PayMode.cash => 'Cash',
      PayMode.cheque => 'Cheque',
    };

@visibleForTesting
String? upiPaymentUriForInvoice(Invoice inv) {
  if (!Prefs.showUpiQr) return null;
  final upi = Prefs.upiId.value.trim();
  if (upi.isEmpty ||
      !isValidUpiId(upi) ||
      inv.displayStatus == Status.draft ||
      inv.items.isEmpty ||
      inv.balance <= 0) {
    return null;
  }
  final payee = Prefs.bizName.value.trim().isNotEmpty
      ? Prefs.bizName.value.trim()
      : Prefs.yourName.value.trim();
  return Uri(
    scheme: 'upi',
    host: 'pay',
    queryParameters: {
      'pa': upi,
      if (payee.isNotEmpty) 'pn': payee,
      'am': inv.balance.toStringAsFixed(2),
      'cu': 'INR',
      'tn': inv.displayNumber,
    },
  ).toString();
}

pw.Widget _upiQrBlock(
  Invoice inv,
  pw.Font regular,
  pw.Font bold, {
  double size = 68,
  bool compact = false,
}) {
  if (!Prefs.showUpiQr ||
      inv.displayStatus == Status.draft ||
      inv.items.isEmpty ||
      inv.balance <= 0) {
    return pw.SizedBox();
  }
  final uploaded = _uploadedUpiQrImage();
  final uri = upiPaymentUriForInvoice(inv);
  if (uploaded == null && uri == null) return pw.SizedBox();
  final upi = Prefs.upiId.value.trim();
  final qrLabel = upi.isNotEmpty && isValidUpiId(upi) ? upi : 'Uploaded UPI QR';
  return pw.Padding(
    padding: pw.EdgeInsets.only(top: compact ? 7 : 10),
    child: pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Container(
          width: size,
          height: size,
          padding: const pw.EdgeInsets.all(5),
          decoration: pw.BoxDecoration(
            color: _white,
            border: pw.Border.all(color: _grey1, width: 0.8),
            borderRadius: pw.BorderRadius.circular(8),
          ),
          child: uploaded != null
              ? pw.Image(uploaded, fit: pw.BoxFit.contain)
              : pw.BarcodeWidget(
                  barcode: pw.Barcode.qrCode(),
                  data: uri!,
                  drawText: false,
                  color: _black,
                ),
        ),
        pw.SizedBox(width: compact ? 8 : 10),
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'UPI payment QR',
                style: pw.TextStyle(font: bold, color: _black, fontSize: 9),
              ),
              pw.SizedBox(height: 3),
              pw.Text(
                qrLabel,
                style: pw.TextStyle(
                  font: regular,
                  color: _grey5,
                  fontSize: compact ? 7 : 8,
                ),
              ),
              pw.SizedBox(height: 3),
              pw.Text(
                'Amount ${_pdfAmt(inv.balance)}',
                style: pw.TextStyle(
                  font: regular,
                  color: _grey5,
                  fontSize: compact ? 7 : 8,
                ),
              ),
              pw.SizedBox(height: 3),
              pw.Text(
                'Payment only - not an IRP e-invoice QR',
                style: pw.TextStyle(
                  font: regular,
                  color: _grey5,
                  fontSize: compact ? 6 : 7,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

pw.MemoryImage? _uploadedUpiQrImage() {
  final data = Prefs.upiQrImage.value.trim();
  if (data.isEmpty) return null;
  try {
    final bytes = base64Decode(data);
    if (!isSupportedRasterImage(bytes)) return null;
    return pw.MemoryImage(bytes);
  } catch (_) {
    return null;
  }
}

pw.MemoryImage? _uploadedSignatureImage() {
  final data = Prefs.signatureImage.value.trim();
  if (data.isEmpty) return null;
  try {
    final bytes = base64Decode(data);
    if (!isSupportedRasterImage(bytes)) return null;
    return pw.MemoryImage(bytes);
  } catch (_) {
    return null;
  }
}

pw.Widget _totalRow(
  String label,
  String value,
  pw.Font regular,
  pw.Font bold, {
  bool sub = false,
  PdfColor? color,
}) =>
    pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(
          label,
          style: pw.TextStyle(
            font: sub ? regular : bold,
            fontSize: sub ? 10 : 11,
            color: color ?? (sub ? _grey5 : _black),
          ),
        ),
        pw.Text(
          value,
          style: pw.TextStyle(
            font: sub ? regular : bold,
            fontSize: sub ? 10 : 11,
            color: color ?? (sub ? _grey5 : _black),
          ),
        ),
      ],
    );

// ─── Share & Download Helpers ────────────────────────────────────

Future<void> sharePdf(Invoice inv) async {
  final bytes = await buildPdf(inv).timeout(const Duration(seconds: 10));
  final filename =
      '${inv.displayNumber.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_')}.pdf';
  await Printing.sharePdf(
    bytes: bytes,
    filename: filename,
  ).timeout(const Duration(seconds: 20));
}

Future<void> shareReceiptPdf(Invoice inv) async {
  final bytes = await buildReceiptPdf(inv).timeout(const Duration(seconds: 10));
  final filename =
      '${inv.displayNumber.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_')}_receipt.pdf';
  await Printing.sharePdf(
    bytes: bytes,
    filename: filename,
  ).timeout(const Duration(seconds: 20));
}

/// Opens WhatsApp directly with a pre-filled invoice message.
/// Priority: whatsapp:// deep link → wa.me web link → system PDF share.
Future<void> shareWhatsApp(BuildContext context, Invoice inv) async {
  // ── Build message ──
  final clientName = inv.client.name.isNotEmpty ? inv.client.name : 'there';
  final dueText = inv.termDays == 0 ? 'today' : 'in ${inv.termDays} days';
  final message = 'Hi $clientName,\n\n'
      'Please find your invoice *${inv.displayNumber}* for *${amt(inv.total)}*, '
      'due $dueText.\n\n'
      '${inv.notes.isNotEmpty ? '${inv.notes}\n\n' : ''}'
      'Thank you.';
  final encoded = Uri.encodeComponent(message);

  // ── Normalize phone to international format ──
  var phone = inv.client.phone.trim().replaceAll(RegExp(r'[\s\-\(\)\+]'), '');
  if (phone.startsWith('0') && phone.length == 11) {
    phone = '91${phone.substring(1)}';
  } else if (phone.length == 10) {
    phone = '91$phone';
  }

  // 1. Try whatsapp:// deep link (opens WA directly, Android & iOS)
  if (phone.isNotEmpty) {
    final waUri = Uri.parse('whatsapp://send?phone=$phone&text=$encoded');
    if (await canLaunchUrl(waUri)) {
      await launchUrl(waUri);
      return;
    }
  }

  // 2. Fallback: wa.me web link (works without phone too)
  final waWebUri = Uri.parse(
    phone.isNotEmpty
        ? 'https://wa.me/$phone?text=$encoded'
        : 'https://wa.me/?text=$encoded',
  );
  if (await canLaunchUrl(waWebUri)) {
    await launchUrl(waWebUri, mode: LaunchMode.externalApplication);
    return;
  }

  // 3. Last resort: system share sheet with PDF
  await sharePdf(inv);
}

/// Opens the native file picker and saves an already-rendered PDF.
Future<String?> savePdfBytes(Uint8List bytes, String invoiceNumber) async {
  final filename =
      '${invoiceNumber.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_')}.pdf';
  return FilePicker.saveFile(
    dialogTitle: 'Save invoice PDF',
    fileName: filename,
    type: FileType.custom,
    allowedExtensions: const ['pdf'],
    bytes: bytes,
  );
}

Future<String?> downloadPdf(Invoice inv) async {
  final bytes = await buildPdf(inv);
  return savePdfBytes(bytes, inv.displayNumber);
}
