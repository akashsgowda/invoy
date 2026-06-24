import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
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

// ════════════════════════════════════════════════════════════════
// BUILD PDF
// ════════════════════════════════════════════════════════════════

Future<Uint8List> buildPdf(Invoice inv) async {
  final doc = pw.Document();

  // Keep PDF generation offline-safe and instant.
  final regular = pw.Font.helvetica();
  final bold = pw.Font.helveticaBold();
  final theme = pw.ThemeData.withFont(base: regular, bold: bold);
  final tpl = tplOf(inv.template);
  final primary = _pdfColor(tpl.primary);
  const pageBg = _white;
  final accent = _pdfColor(tpl.accent);
  const soft = _grey05;
  final sender = Prefs.bizName.value.isNotEmpty
      ? Prefs.bizName.value
      : Prefs.yourName.value.isNotEmpty
          ? Prefs.yourName.value
          : 'Invoice';

  if (tpl.name == 'Minimal') {
    doc.addPage(pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.zero,
        theme: theme,
        build: (_) =>
            _minimalLayout(inv, sender, regular, bold, primary, accent)));
    return doc.save();
  }

  if (tpl.name == 'Ledger') {
    doc.addPage(pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.zero,
        theme: theme,
        build: (_) =>
            _ledgerLayout(inv, sender, regular, bold, primary, accent)));
    return doc.save();
  }

  if (tpl.name == 'Compact') {
    doc.addPage(pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.zero,
        theme: theme,
        build: (_) =>
            _compactLayout(inv, sender, regular, bold, primary, accent)));
    return doc.save();
  }

  doc.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: pw.EdgeInsets.zero,
      theme: theme,
      build: (_) => pw.Container(
            width: double.infinity,
            height: double.infinity,
            color: pageBg,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // ── Black header ──
                pw.Container(
                  width: double.infinity,
                  color: primary,
                  padding: const pw.EdgeInsets.fromLTRB(36, 28, 36, 28),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      pw.Text(sender,
                          style: pw.TextStyle(
                              font: bold, color: _white, fontSize: 18)),
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.end,
                        children: [
                          pw.Text('INVOICE',
                              style: pw.TextStyle(
                                  font: bold,
                                  color: _white,
                                  fontSize: 20,
                                  letterSpacing: 2)),
                          pw.SizedBox(height: 4),
                          pw.Text('#${inv.num}',
                              style: pw.TextStyle(
                                  font: regular, color: _grey5, fontSize: 11)),
                        ],
                      ),
                    ],
                  ),
                ),

                pw.Container(height: 2, color: accent),

                // ── Client + invoice info ──
                pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.fromLTRB(36, 28, 36, 28),
                  child: pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Expanded(
                          child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('Invoice To:',
                              style: pw.TextStyle(
                                  font: regular, color: _grey5, fontSize: 10)),
                          pw.SizedBox(height: 5),
                          pw.Text(
                              inv.client.name.isNotEmpty
                                  ? inv.client.name
                                  : 'Unnamed Client',
                              style: pw.TextStyle(
                                  font: bold, fontSize: 16, color: _black)),
                          if (inv.client.email.isNotEmpty) ...[
                            pw.SizedBox(height: 3),
                            pw.Text(inv.client.email,
                                style: pw.TextStyle(
                                    font: regular,
                                    fontSize: 10,
                                    color: _grey5)),
                          ],
                          if (inv.client.address.isNotEmpty) ...[
                            pw.SizedBox(height: 3),
                            pw.Text(inv.client.address,
                                style: pw.TextStyle(
                                    font: regular,
                                    fontSize: 10,
                                    color: _grey5)),
                          ],
                          if (inv.client.gstin.isNotEmpty) ...[
                            pw.SizedBox(height: 3),
                            pw.Text('GSTIN: ${inv.client.gstin}',
                                style: pw.TextStyle(
                                    font: regular, fontSize: 9, color: _grey5)),
                          ],
                        ],
                      )),
                      pw.SizedBox(width: 40),
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          _infoRow(
                              'Invoice Date:', fDate(inv.date), regular, bold),
                          pw.SizedBox(height: 8),
                          _infoRow('Due Date:', fDate(inv.due), regular, bold),
                          pw.SizedBox(height: 8),
                          _infoRow(
                              'Terms:',
                              inv.termDays == 0
                                  ? 'Due on receipt'
                                  : 'Net ${inv.termDays}',
                              regular,
                              bold),
                          if (Prefs.yourName.value.isNotEmpty) ...[
                            pw.SizedBox(height: 8),
                            _infoRow(
                                'From:', Prefs.yourName.value, regular, bold),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),

                pw.Container(height: 1, color: _grey1),

                // ── Items table ──
                pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 36),
                  child: pw.Column(children: [
                    // Header row
                    pw.Container(
                      color: primary,
                      padding: const pw.EdgeInsets.symmetric(
                          horizontal: 14, vertical: 11),
                      child: pw.Row(children: [
                        pw.Expanded(
                            flex: 5,
                            child: pw.Text('Item',
                                style: pw.TextStyle(
                                    font: bold, color: _white, fontSize: 10))),
                        pw.SizedBox(
                            width: 60,
                            child: pw.Text('Quantity',
                                textAlign: pw.TextAlign.center,
                                style: pw.TextStyle(
                                    font: bold, color: _white, fontSize: 10))),
                        pw.SizedBox(
                            width: 70,
                            child: pw.Text('Price',
                                textAlign: pw.TextAlign.right,
                                style: pw.TextStyle(
                                    font: bold, color: _white, fontSize: 10))),
                        pw.SizedBox(
                            width: 70,
                            child: pw.Text('Total',
                                textAlign: pw.TextAlign.right,
                                style: pw.TextStyle(
                                    font: bold, color: _white, fontSize: 10))),
                      ]),
                    ),

                    // Items
                    ...inv.items.asMap().entries.map((e) {
                      final item = e.value;
                      final bg = e.key.isEven ? pageBg : soft;
                      return pw.Container(
                        color: bg,
                        padding: const pw.EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        child: pw.Row(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Expanded(
                                  flex: 5,
                                  child: pw.Text(item.desc,
                                      style: pw.TextStyle(
                                          font: bold,
                                          fontSize: 11,
                                          color: _black))),
                              pw.SizedBox(
                                  width: 60,
                                  child: pw.Text(
                                      item.qty % 1 == 0
                                          ? item.qty.toInt().toString()
                                          : item.qty.toStringAsFixed(1),
                                      textAlign: pw.TextAlign.center,
                                      style: pw.TextStyle(
                                          font: regular,
                                          fontSize: 11,
                                          color: _black))),
                              pw.SizedBox(
                                  width: 70,
                                  child: pw.Text(_pdfAmt(item.rate),
                                      textAlign: pw.TextAlign.right,
                                      style: pw.TextStyle(
                                          font: regular,
                                          fontSize: 11,
                                          color: _black))),
                              pw.SizedBox(
                                  width: 70,
                                  child: pw.Text(_pdfAmt(item.total),
                                      textAlign: pw.TextAlign.right,
                                      style: pw.TextStyle(
                                          font: bold,
                                          fontSize: 11,
                                          color: _black))),
                            ]),
                      );
                    }),

                    pw.Container(height: 1, color: _grey1),
                  ]),
                ),

                pw.SizedBox(height: 20),

                // ── Notes + Totals ──
                pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 36),
                  child: pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Expanded(child: _notesMini(inv, regular, bold)),
                      pw.SizedBox(width: 40),
                      pw.SizedBox(
                        width: 220,
                        child: pw.Column(children: [
                          _totalRow(
                              'Subtotal', _pdfAmt(inv.sub), regular, bold),
                          if (inv.discountAmount > 0) ...[
                            pw.SizedBox(height: 5),
                            _totalRow(
                                'Discount',
                                '-${_pdfAmt(inv.discountAmount)}',
                                regular,
                                bold,
                                sub: true),
                          ],
                          if (inv.splitGst && inv.gst > 0) ...[
                            pw.SizedBox(height: 5),
                            _totalRow(
                                'CGST (${(inv.gst / 2).toStringAsFixed(1)}%)',
                                _pdfAmt(inv.cgst),
                                regular,
                                bold,
                                sub: true),
                            pw.SizedBox(height: 3),
                            _totalRow(
                                'SGST (${(inv.gst / 2).toStringAsFixed(1)}%)',
                                _pdfAmt(inv.sgst),
                                regular,
                                bold,
                                sub: true),
                          ] else if (inv.gst > 0) ...[
                            pw.SizedBox(height: 5),
                            _totalRow('Tax (${inv.gst.toStringAsFixed(0)}%)',
                                _pdfAmt(inv.tax), regular, bold,
                                sub: true),
                          ],
                          pw.SizedBox(height: 8),
                          pw.Container(height: 1, color: _grey1),
                          pw.SizedBox(height: 8),
                          pw.Container(
                            color: _grey05,
                            padding: const pw.EdgeInsets.symmetric(
                                horizontal: 14, vertical: 10),
                            child: pw.Row(
                              mainAxisAlignment:
                                  pw.MainAxisAlignment.spaceBetween,
                              children: [
                                pw.Text('Total',
                                    style: pw.TextStyle(
                                        font: bold,
                                        fontSize: 13,
                                        color: _black)),
                                pw.Text(_pdfAmt(inv.total),
                                    style: pw.TextStyle(
                                        font: bold,
                                        fontSize: 15,
                                        color: _black)),
                              ],
                            ),
                          ),
                          if (inv.paidAmt > 0 && inv.balance > 0) ...[
                            pw.SizedBox(height: 6),
                            _totalRow(
                                'Paid', _pdfAmt(inv.paidAmt), regular, bold,
                                color: const PdfColor.fromInt(0xFF16A34A)),
                            pw.SizedBox(height: 4),
                            pw.Container(
                              color: const PdfColor.fromInt(0xFFFEF2F2),
                              padding: const pw.EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 8),
                              child: pw.Row(
                                mainAxisAlignment:
                                    pw.MainAxisAlignment.spaceBetween,
                                children: [
                                  pw.Text('Balance Due',
                                      style: pw.TextStyle(
                                          font: bold,
                                          fontSize: 11,
                                          color: const PdfColor.fromInt(
                                              0xFFDC2626))),
                                  pw.Text(_pdfAmt(inv.balance),
                                      style: pw.TextStyle(
                                          font: bold,
                                          fontSize: 11,
                                          color: const PdfColor.fromInt(
                                              0xFFDC2626))),
                                ],
                              ),
                            ),
                          ],
                        ]),
                      ),
                    ],
                  ),
                ),

                pw.Spacer(),

                // ── Footer ──
                pw.Container(height: 1, color: _grey1),
                pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.fromLTRB(36, 16, 36, 16),
                  child: _pdfFooter(inv, sender, regular, bold),
                ),
              ],
            ),
          )));

  return doc.save();
}

pw.Widget _minimalLayout(Invoice inv, String sender, pw.Font regular,
        pw.Font bold, PdfColor primary, PdfColor accent) =>
    pw.Container(
      color: _white,
      padding: const pw.EdgeInsets.fromLTRB(42, 42, 42, 34),
      child:
          pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Expanded(
              child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                pw.Text(sender,
                    style:
                        pw.TextStyle(font: bold, fontSize: 18, color: primary)),
                pw.SizedBox(height: 5),
                pw.Text(
                    Prefs.gstNum.value.isEmpty
                        ? 'Quick invoice'
                        : 'GSTIN ${Prefs.gstNum.value}',
                    style: pw.TextStyle(
                        font: regular, fontSize: 9, color: _grey5)),
              ])),
          pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
            pw.Text('INVOICE',
                style: pw.TextStyle(font: bold, fontSize: 26, color: primary)),
            pw.SizedBox(height: 4),
            pw.Text(inv.num,
                style:
                    pw.TextStyle(font: regular, fontSize: 10, color: _grey5)),
          ]),
        ]),
        pw.SizedBox(height: 34),
        pw.Container(height: 2, color: accent),
        pw.SizedBox(height: 22),
        pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Expanded(child: _clientMini(inv, regular, bold)),
          pw.SizedBox(width: 34),
          pw.SizedBox(width: 180, child: _metaMini(inv, regular, bold)),
        ]),
        pw.SizedBox(height: 34),
        _lineItemsMinimal(inv, regular, bold),
        pw.SizedBox(height: 24),
        pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Expanded(child: _notesMini(inv, regular, bold)),
          pw.SizedBox(width: 42),
          pw.SizedBox(
              width: 210,
              child: _totalsMinimal(inv, regular, bold, accent: accent)),
        ]),
        pw.Spacer(),
        pw.Container(height: 1, color: _grey1),
        pw.SizedBox(height: 12),
        _pdfFooter(inv, sender, regular, bold),
      ]),
    );

pw.Widget _ledgerLayout(Invoice inv, String sender, pw.Font regular,
        pw.Font bold, PdfColor primary, PdfColor accent) =>
    pw.Container(
      color: _white,
      padding: const pw.EdgeInsets.fromLTRB(36, 34, 36, 32),
      child:
          pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.fromLTRB(22, 20, 22, 20),
          decoration: pw.BoxDecoration(
            color: primary,
            borderRadius: pw.BorderRadius.circular(18),
          ),
          child: pw
              .Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Expanded(
                child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                  pw.Text(sender,
                      style: pw.TextStyle(
                          font: bold, fontSize: 18, color: _white)),
                  pw.SizedBox(height: 5),
                  pw.Text('Tax invoice',
                      style: pw.TextStyle(
                          font: regular, fontSize: 9, color: _grey1)),
                ])),
            pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
              pw.Text(inv.num,
                  style: pw.TextStyle(font: bold, fontSize: 12, color: _white)),
              pw.SizedBox(height: 5),
              pw.Text(fDate(inv.date),
                  style:
                      pw.TextStyle(font: regular, fontSize: 9, color: _grey1)),
            ]),
          ]),
        ),
        pw.SizedBox(height: 18),
        pw.Row(children: [
          pw.Expanded(
              child: _summaryTile(
                  'Due date', fDate(inv.due), regular, bold, accent)),
          pw.SizedBox(width: 10),
          pw.Expanded(
              child: _summaryTile(
                  'Terms',
                  inv.termDays == 0 ? 'Due now' : 'Net ${inv.termDays}',
                  regular,
                  bold,
                  accent)),
          pw.SizedBox(width: 10),
          pw.Expanded(
              child: _summaryTile(
                  'Amount due', _pdfAmt(inv.balance), regular, bold, accent)),
        ]),
        pw.SizedBox(height: 20),
        pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Expanded(
              child: pw.Container(
            padding: const pw.EdgeInsets.all(16),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: _grey1, width: 1),
              borderRadius: pw.BorderRadius.circular(14),
            ),
            child: _clientMini(inv, regular, bold),
          )),
          pw.SizedBox(width: 14),
          pw.SizedBox(
            width: 188,
            child: pw.Container(
              padding: const pw.EdgeInsets.all(16),
              decoration: pw.BoxDecoration(
                color: _grey05,
                borderRadius: pw.BorderRadius.circular(14),
              ),
              child: _metaMini(inv, regular, bold),
            ),
          ),
        ]),
        pw.SizedBox(height: 20),
        _lineItemsLedger(inv, regular, bold, accent),
        pw.SizedBox(height: 20),
        pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Expanded(child: _notesMini(inv, regular, bold)),
          pw.SizedBox(width: 34),
          pw.SizedBox(
              width: 218,
              child: pw.Container(
                decoration: pw.BoxDecoration(
                  color: _grey05,
                  borderRadius: pw.BorderRadius.circular(14),
                ),
                padding: const pw.EdgeInsets.all(14),
                child: _totalsMinimal(inv, regular, bold),
              )),
        ]),
        pw.Spacer(),
        pw.Container(height: 1, color: _grey1),
        pw.SizedBox(height: 12),
        _pdfFooter(inv, sender, regular, bold, accent: primary),
      ]),
    );

pw.Widget _compactLayout(Invoice inv, String sender, pw.Font regular,
        pw.Font bold, PdfColor primary, PdfColor accent) =>
    pw.Container(
      color: _grey05,
      padding: const pw.EdgeInsets.fromLTRB(36, 24, 36, 24),
      child: pw.Center(
        child: pw.Container(
          width: 330,
          padding: const pw.EdgeInsets.fromLTRB(22, 22, 22, 20),
          decoration: pw.BoxDecoration(
            color: _white,
            border: pw.Border.all(color: _grey1, width: 0.8),
          ),
          child: pw.Column(children: [
            pw.Text('TAX INVOICE',
                style: pw.TextStyle(
                    font: bold, fontSize: 10, color: _black, letterSpacing: 1)),
            pw.SizedBox(height: 8),
            pw.Text(sender,
                textAlign: pw.TextAlign.center,
                style: pw.TextStyle(font: bold, fontSize: 16, color: _black)),
            pw.SizedBox(height: 4),
            pw.Text('Bill no: ${inv.num}',
                style:
                    pw.TextStyle(font: regular, fontSize: 10, color: _grey5)),
            pw.SizedBox(height: 12),
            _receiptDashed(primary),
            pw.SizedBox(height: 12),
            _receiptMetaRow('Date', fDate(inv.date), regular, bold),
            pw.SizedBox(height: 5),
            _receiptMetaRow('Due', fDate(inv.due), regular, bold),
            pw.SizedBox(height: 12),
            _clientMini(inv, regular, bold),
            pw.SizedBox(height: 14),
            _receiptDashed(_grey1),
            pw.SizedBox(height: 12),
            _lineItemsReceipt(inv, regular, bold),
            pw.SizedBox(height: 12),
            _receiptDashed(_grey1),
            pw.SizedBox(height: 12),
            _receiptTotalRow('Subtotal', _pdfAmt(inv.sub), regular, bold),
            if (inv.discountAmount > 0) ...[
              pw.SizedBox(height: 5),
              _receiptTotalRow(
                  'Discount', '-${_pdfAmt(inv.discountAmount)}', regular, bold),
            ],
            if (inv.gst > 0) ...[
              pw.SizedBox(height: 5),
              _receiptTotalRow('GST', _pdfAmt(inv.tax), regular, bold),
            ],
            pw.SizedBox(height: 8),
            pw.Container(
              padding:
                  const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              color: accent,
              child: _receiptTotalRow(
                  'TOTAL', _pdfAmt(inv.total), regular, bold,
                  strong: true),
            ),
            if (inv.paidAmt > 0) ...[
              pw.SizedBox(height: 8),
              _receiptTotalRow('PAID', _pdfAmt(inv.paidAmt), regular, bold),
              if (inv.balance > 0) ...[
                pw.SizedBox(height: 5),
                _receiptTotalRow('DUE', _pdfAmt(inv.balance), regular, bold,
                    strong: true),
              ],
            ],
            _paymentHistoryPdf(inv, regular, bold, compact: true),
            pw.SizedBox(height: 12),
            pw.Text('Thank you for your business',
                style: pw.TextStyle(font: bold, fontSize: 9, color: _black)),
            _upiQrBlock(inv, regular, bold, size: 58, compact: true),
            pw.SizedBox(height: 8),
            _pdfFooter(inv, sender, regular, bold, compact: true),
          ]),
        ),
      ),
    );

pw.Widget _receiptDashed(PdfColor color) => pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: List.generate(
        24,
        (_) => pw.Container(width: 5, height: 1, color: color),
      ),
    );

pw.Widget _summaryTile(String label, String value, pw.Font regular,
        pw.Font bold, PdfColor bg) =>
    pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: pw.BoxDecoration(
        color: bg,
        borderRadius: pw.BorderRadius.circular(12),
      ),
      child:
          pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Text(label,
            style: pw.TextStyle(font: regular, fontSize: 8, color: _grey5)),
        pw.SizedBox(height: 4),
        pw.Text(value,
            style: pw.TextStyle(font: bold, fontSize: 10, color: _black)),
      ]),
    );

pw.Widget _receiptMetaRow(
        String label, String value, pw.Font regular, pw.Font bold) =>
    pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
      pw.Text(label,
          style: pw.TextStyle(font: regular, fontSize: 9, color: _grey5)),
      pw.Text(value,
          style: pw.TextStyle(font: bold, fontSize: 9, color: _black)),
    ]);

pw.Widget _lineItemsReceipt(Invoice inv, pw.Font regular, pw.Font bold) =>
    pw.Column(children: [
      pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
        pw.Text('Item',
            style: pw.TextStyle(font: bold, fontSize: 9, color: _black)),
        pw.Text('Amount',
            style: pw.TextStyle(font: bold, fontSize: 9, color: _black)),
      ]),
      pw.SizedBox(height: 8),
      if (inv.items.isEmpty)
        pw.Text('No items',
            style: pw.TextStyle(font: regular, fontSize: 9, color: _grey5))
      else
        ...inv.items.map((item) => pw.Container(
              padding: const pw.EdgeInsets.symmetric(vertical: 7),
              decoration: const pw.BoxDecoration(
                border: pw.Border(bottom: pw.BorderSide(color: _grey1)),
              ),
              child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Expanded(
                        child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                          pw.Text(item.desc,
                              style: pw.TextStyle(
                                  font: bold, fontSize: 9, color: _black)),
                          pw.SizedBox(height: 2),
                          pw.Text(
                              '${item.qty % 1 == 0 ? item.qty.toInt() : item.qty.toStringAsFixed(1)} x ${_pdfAmt(item.rate)}',
                              style: pw.TextStyle(
                                  font: regular, fontSize: 8, color: _grey5)),
                        ])),
                    pw.SizedBox(width: 12),
                    pw.Text(_pdfAmt(item.total),
                        textAlign: pw.TextAlign.right,
                        style: pw.TextStyle(
                            font: bold, fontSize: 9, color: _black)),
                  ]),
            )),
    ]);

pw.Widget _receiptTotalRow(
        String label, String value, pw.Font regular, pw.Font bold,
        {bool strong = false}) =>
    pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
      pw.Text(label,
          style: pw.TextStyle(
              font: strong ? bold : regular,
              fontSize: strong ? 11 : 9,
              color: _black)),
      pw.Text(value,
          style: pw.TextStyle(
              font: bold, fontSize: strong ? 11 : 9, color: _black)),
    ]);

pw.Widget _clientMini(Invoice inv, pw.Font regular, pw.Font bold) => pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('Bill to',
            style: pw.TextStyle(font: regular, color: _grey5, fontSize: 9)),
        pw.SizedBox(height: 5),
        pw.Text(inv.client.name.isNotEmpty ? inv.client.name : 'Unnamed Client',
            style: pw.TextStyle(font: bold, color: _black, fontSize: 14)),
        if (inv.client.email.isNotEmpty) ...[
          pw.SizedBox(height: 3),
          pw.Text(inv.client.email,
              style: pw.TextStyle(font: regular, color: _grey5, fontSize: 9)),
        ],
        if (inv.client.address.isNotEmpty) ...[
          pw.SizedBox(height: 3),
          pw.Text(inv.client.address,
              style: pw.TextStyle(font: regular, color: _grey5, fontSize: 9)),
        ],
        if (inv.client.gstin.isNotEmpty) ...[
          pw.SizedBox(height: 3),
          pw.Text('GSTIN ${inv.client.gstin}',
              style: pw.TextStyle(font: regular, color: _grey5, fontSize: 9)),
        ],
      ],
    );

pw.Widget _metaMini(Invoice inv, pw.Font regular, pw.Font bold) => pw.Column(
      children: [
        _metaRow('Date', fDate(inv.date), regular, bold),
        pw.SizedBox(height: 7),
        _metaRow('Due', fDate(inv.due), regular, bold),
        pw.SizedBox(height: 7),
        _metaRow('Terms', inv.termDays == 0 ? 'Due now' : 'Net ${inv.termDays}',
            regular, bold),
      ],
    );

pw.Widget _metaRow(String label, String value, pw.Font regular, pw.Font bold) =>
    pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
      pw.Text(label,
          style: pw.TextStyle(font: regular, color: _grey5, fontSize: 9)),
      pw.Text(value,
          style: pw.TextStyle(font: bold, color: _black, fontSize: 9)),
    ]);

pw.Widget _notesMini(Invoice inv, pw.Font regular, pw.Font bold) => pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('Notes',
            style: pw.TextStyle(font: bold, color: _black, fontSize: 10)),
        pw.SizedBox(height: 5),
        pw.Text(
            inv.notes.isNotEmpty ? inv.notes : 'Thank you for your business.',
            style: pw.TextStyle(font: regular, color: _grey5, fontSize: 9)),
        _paymentHistoryPdf(inv, regular, bold),
        _upiQrBlock(inv, regular, bold),
      ],
    );

pw.Widget _paymentHistoryPdf(Invoice inv, pw.Font regular, pw.Font bold,
    {bool compact = false}) {
  if (inv.payments.isEmpty) return pw.SizedBox();
  final payments = inv.payments.take(compact ? 3 : 4).toList();
  final extra = inv.payments.length - payments.length;
  return pw.Padding(
    padding: pw.EdgeInsets.only(top: compact ? 8 : 12),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(compact ? 'PAYMENTS' : 'Payments',
            style: pw.TextStyle(
                font: bold, color: _black, fontSize: compact ? 7.5 : 9)),
        pw.SizedBox(height: compact ? 4 : 6),
        ...payments.map((p) => pw.Padding(
              padding: pw.EdgeInsets.only(bottom: compact ? 3 : 4),
              child: pw.Row(children: [
                pw.Expanded(
                  child: pw.Text(
                      '${fDate(p.date)} - ${_paymentModeLabel(p.mode)}',
                      style: pw.TextStyle(
                          font: regular,
                          color: _grey5,
                          fontSize: compact ? 7 : 8)),
                ),
                pw.SizedBox(width: 8),
                pw.Text(_pdfAmt(p.amount),
                    textAlign: pw.TextAlign.right,
                    style: pw.TextStyle(
                        font: bold, color: _black, fontSize: compact ? 7 : 8)),
              ]),
            )),
        if (extra > 0)
          pw.Text('$extra more payment${extra == 1 ? '' : 's'} recorded',
              style: pw.TextStyle(
                  font: regular, color: _grey5, fontSize: compact ? 7 : 8)),
      ],
    ),
  );
}

pw.Widget _lineItemsMinimal(Invoice inv, pw.Font regular, pw.Font bold) =>
    pw.Column(children: [
      _itemHeader(regular, bold, fill: _white, text: _grey5),
      pw.Container(height: 1, color: _grey1),
      ...inv.items.map((item) => pw.Container(
            padding: const pw.EdgeInsets.symmetric(vertical: 12),
            decoration: const pw.BoxDecoration(
                border: pw.Border(bottom: pw.BorderSide(color: _grey1))),
            child: _itemRow(item, regular, bold),
          )),
    ]);

pw.Widget _lineItemsLedger(
        Invoice inv, pw.Font regular, pw.Font bold, PdfColor accent) =>
    pw.Table(
      border: const pw.TableBorder(
        horizontalInside: pw.BorderSide(color: _grey1, width: 0.7),
      ),
      columnWidths: const {
        0: pw.FlexColumnWidth(4),
        1: pw.FixedColumnWidth(58),
        2: pw.FixedColumnWidth(70),
        3: pw.FixedColumnWidth(78),
      },
      children: [
        pw.TableRow(
            decoration: pw.BoxDecoration(color: accent),
            children: _tableCells(['Item', 'Qty', 'Rate', 'Total'], bold,
                header: true)),
        ...inv.items.map((i) => pw.TableRow(children: [
              _cell(i.desc, bold),
              _cell(
                  i.qty % 1 == 0
                      ? '${i.qty.toInt()}'
                      : i.qty.toStringAsFixed(1),
                  regular,
                  align: pw.TextAlign.center),
              _cell(_pdfAmt(i.rate), regular, align: pw.TextAlign.right),
              _cell(_pdfAmt(i.total), bold, align: pw.TextAlign.right),
            ])),
      ],
    );

pw.Widget _itemHeader(pw.Font regular, pw.Font bold,
        {required PdfColor fill, required PdfColor text}) =>
    pw.Container(
      color: fill,
      padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      child: pw.Row(children: [
        pw.Expanded(
            flex: 4,
            child: pw.Text('Item',
                style: pw.TextStyle(font: bold, color: text, fontSize: 9))),
        pw.SizedBox(
            width: 54,
            child: pw.Text('Qty',
                textAlign: pw.TextAlign.center,
                style: pw.TextStyle(font: bold, color: text, fontSize: 9))),
        pw.SizedBox(
            width: 70,
            child: pw.Text('Rate',
                textAlign: pw.TextAlign.right,
                style: pw.TextStyle(font: bold, color: text, fontSize: 9))),
        pw.SizedBox(
            width: 78,
            child: pw.Text('Total',
                textAlign: pw.TextAlign.right,
                style: pw.TextStyle(font: bold, color: text, fontSize: 9))),
      ]),
    );

pw.Widget _itemRow(LineItem item, pw.Font regular, pw.Font bold) => pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(
            flex: 4,
            child: pw.Text(item.desc,
                style: pw.TextStyle(font: bold, color: _black, fontSize: 10))),
        pw.SizedBox(
            width: 54,
            child: pw.Text(
                item.qty % 1 == 0
                    ? '${item.qty.toInt()}'
                    : item.qty.toStringAsFixed(1),
                textAlign: pw.TextAlign.center,
                style:
                    pw.TextStyle(font: regular, color: _black, fontSize: 10))),
        pw.SizedBox(
            width: 70,
            child: pw.Text(_pdfAmt(item.rate),
                textAlign: pw.TextAlign.right,
                style:
                    pw.TextStyle(font: regular, color: _black, fontSize: 10))),
        pw.SizedBox(
            width: 78,
            child: pw.Text(_pdfAmt(item.total),
                textAlign: pw.TextAlign.right,
                style: pw.TextStyle(font: bold, color: _black, fontSize: 10))),
      ],
    );

List<pw.Widget> _tableCells(List<String> labels, pw.Font font,
        {bool header = false}) =>
    labels
        .map((l) => _cell(l, font,
            align: l == 'Item' ? pw.TextAlign.left : pw.TextAlign.center,
            header: header))
        .toList();

pw.Widget _cell(String text, pw.Font font,
        {pw.TextAlign align = pw.TextAlign.left, bool header = false}) =>
    pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: pw.Text(text,
          textAlign: align,
          style: pw.TextStyle(
              font: font,
              fontSize: header ? 9 : 10,
              color: header ? _grey5 : _black)),
    );

pw.Widget _totalsMinimal(Invoice inv, pw.Font regular, pw.Font bold,
        {PdfColor? accent}) =>
    pw.Column(children: [
      _totalRow('Subtotal', _pdfAmt(inv.sub), regular, bold),
      if (inv.discountAmount > 0) ...[
        pw.SizedBox(height: 6),
        _totalRow('Discount', '-${_pdfAmt(inv.discountAmount)}', regular, bold,
            sub: true),
      ],
      if (inv.gst > 0) ...[
        pw.SizedBox(height: 6),
        _totalRow('Tax', _pdfAmt(inv.tax), regular, bold, sub: true),
      ],
      pw.SizedBox(height: 10),
      pw.Container(height: 1, color: accent ?? _grey1),
      pw.SizedBox(height: 10),
      accent == null
          ? _totalRow('Total', _pdfAmt(inv.total), regular, bold)
          : pw.Container(
              padding:
                  const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              color: accent,
              child: _totalRow('Total', _pdfAmt(inv.total), regular, bold),
            ),
      if (inv.paidAmt > 0) ...[
        pw.SizedBox(height: 8),
        _totalRow('Paid', _pdfAmt(inv.paidAmt), regular, bold, sub: true),
        if (inv.balance > 0) ...[
          pw.SizedBox(height: 6),
          _totalRow('Balance due', _pdfAmt(inv.balance), regular, bold),
        ],
      ],
    ]);

// ─── Helpers ─────────────────────────────────────────────────────

PdfColor _pdfColor(Color c) => PdfColor.fromInt(c.toARGB32());

String _pdfAmt(double value) =>
    amtUi(value, maxChars: 20).replaceFirst('₹', 'Rs ');

String _paymentModeLabel(PayMode mode) => switch (mode) {
      PayMode.upi => 'UPI',
      PayMode.bank => 'Bank',
      PayMode.cash => 'Cash',
      PayMode.cheque => 'Cheque',
    };

pw.Widget _pdfFooter(Invoice inv, String sender, pw.Font regular, pw.Font bold,
    {PdfColor? accent, bool compact = false}) {
  final dueText =
      inv.termDays == 0 ? 'Due on receipt' : 'Due ${fDate(inv.due)}';
  final statusText =
      inv.balance > 0 ? 'Balance ${_pdfAmt(inv.balance)}' : 'Paid in full';
  final paymentText = Prefs.upiId.value.trim().isNotEmpty
      ? 'UPI ${Prefs.upiId.value.trim()}'
      : Prefs.gstNum.value.trim().isNotEmpty
          ? 'GSTIN ${Prefs.gstNum.value.trim()}'
          : sender;

  if (compact) {
    return pw.Column(children: [
      pw.Text('$dueText - $statusText',
          textAlign: pw.TextAlign.center,
          style: pw.TextStyle(font: regular, fontSize: 7.5, color: _grey5)),
      pw.SizedBox(height: 2),
      pw.Text(paymentText,
          textAlign: pw.TextAlign.center,
          style: pw.TextStyle(font: bold, fontSize: 7.5, color: _black)),
    ]);
  }

  return pw.Row(
    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
    crossAxisAlignment: pw.CrossAxisAlignment.center,
    children: [
      pw.Expanded(
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('$dueText - $statusText',
                style: pw.TextStyle(
                    font: bold, fontSize: 9, color: accent ?? _black)),
            pw.SizedBox(height: 2),
            pw.Text(paymentText,
                style: pw.TextStyle(font: regular, fontSize: 8, color: _grey5)),
          ],
        ),
      ),
      pw.SizedBox(width: 18),
      pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.end,
        children: [
          pw.Text(inv.num,
              style: pw.TextStyle(font: bold, fontSize: 8, color: _grey5)),
          pw.SizedBox(height: 2),
          pw.Text(fDate(inv.date),
              style: pw.TextStyle(font: regular, fontSize: 8, color: _grey5)),
        ],
      ),
    ],
  );
}

@visibleForTesting
String? upiPaymentUriForInvoice(Invoice inv) {
  if (!Prefs.showUpiQr) return null;
  final upi = Prefs.upiId.value.trim();
  if (upi.isEmpty || inv.items.isEmpty || inv.balance <= 0) return null;
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
      'tn': inv.num,
    },
  ).toString();
}

pw.Widget _upiQrBlock(Invoice inv, pw.Font regular, pw.Font bold,
    {double size = 68, bool compact = false}) {
  if (!Prefs.showUpiQr || inv.items.isEmpty || inv.balance <= 0) {
    return pw.SizedBox();
  }
  final uploaded = _uploadedUpiQrImage();
  final uri = upiPaymentUriForInvoice(inv);
  if (uploaded == null && uri == null) return pw.SizedBox();
  final upi = Prefs.upiId.value.trim();
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
              pw.Text('Scan to pay',
                  style: pw.TextStyle(font: bold, color: _black, fontSize: 9)),
              pw.SizedBox(height: 3),
              pw.Text(upi.isEmpty ? 'UPI QR' : upi,
                  style: pw.TextStyle(
                      font: regular, color: _grey5, fontSize: compact ? 7 : 8)),
              pw.SizedBox(height: 3),
              pw.Text('Amount ${_pdfAmt(inv.balance)}',
                  style: pw.TextStyle(
                      font: regular, color: _grey5, fontSize: compact ? 7 : 8)),
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
    return pw.MemoryImage(base64Decode(data));
  } catch (_) {
    return null;
  }
}

pw.Widget _infoRow(String label, String value, pw.Font regular, pw.Font bold) =>
    pw.Row(children: [
      pw.SizedBox(
          width: 80,
          child: pw.Text(label,
              style: pw.TextStyle(font: bold, fontSize: 10, color: _black))),
      pw.Text(value,
          style: pw.TextStyle(font: regular, fontSize: 10, color: _grey5)),
    ]);

pw.Widget _totalRow(String label, String value, pw.Font regular, pw.Font bold,
        {bool sub = false, PdfColor? color}) =>
    pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(label,
            style: pw.TextStyle(
                font: sub ? regular : bold,
                fontSize: sub ? 10 : 11,
                color: color ?? (sub ? _grey5 : _black))),
        pw.Text(value,
            style: pw.TextStyle(
                font: sub ? regular : bold,
                fontSize: sub ? 10 : 11,
                color: color ?? (sub ? _grey5 : _black))),
      ],
    );

// ─── Share & Download Helpers ────────────────────────────────────

Future<void> sharePdf(Invoice inv) async {
  final bytes = await buildPdf(inv).timeout(const Duration(seconds: 10));
  final filename = '${inv.num.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_')}.pdf';
  await Printing.sharePdf(bytes: bytes, filename: filename)
      .timeout(const Duration(seconds: 20));
}

/// Opens WhatsApp directly with a pre-filled invoice message.
/// Priority: whatsapp:// deep link → wa.me web link → system PDF share.
Future<void> shareWhatsApp(BuildContext context, Invoice inv) async {
  // ── Build message ──
  final clientName = inv.client.name.isNotEmpty ? inv.client.name : 'there';
  final dueText = inv.termDays == 0 ? 'today' : 'in ${inv.termDays} days';
  final message = 'Hi $clientName,\n\n'
      'Please find your invoice *${inv.num}* for *${amt(inv.total)}*, '
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

/// Saves an already-rendered PDF and returns the file path.
Future<String> savePdfBytes(Uint8List bytes, String invoiceNumber) async {
  final filename =
      '${invoiceNumber.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_')}.pdf';
  final candidates = <Directory>[];

  if (Platform.isAndroid) {
    candidates.add(Directory('/storage/emulated/0/Download'));
    final external = await getExternalStorageDirectory();
    if (external != null) candidates.add(external);
  } else {
    final downloads = await getDownloadsDirectory();
    if (downloads != null) candidates.add(downloads);
  }

  candidates.add(await getApplicationDocumentsDirectory());

  Object? lastError;
  for (final dir in candidates) {
    try {
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      final file = File('${dir.path}/$filename');
      await file.writeAsBytes(bytes, flush: true);
      return file.path;
    } catch (e) {
      lastError = e;
    }
  }

  throw FileSystemException('Unable to save PDF', lastError?.toString());
}

/// Saves PDF to Downloads when available and returns the file path.
Future<String> downloadPdf(Invoice inv) async {
  final bytes = await buildPdf(inv);
  return savePdfBytes(bytes, inv.num);
}
