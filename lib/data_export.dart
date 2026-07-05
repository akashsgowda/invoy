import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'models.dart';
import 'widgets.dart';

class BackupPreview {
  const BackupPreview({
    required this.path,
    required this.invoices,
    required this.clients,
    required this.savedItems,
    required this.prefs,
    this.createdAt,
  });

  final String path;
  final List<Invoice> invoices;
  final List<Customer> clients;
  final List<SavedItem> savedItems;
  final Map<String, dynamic> prefs;
  final DateTime? createdAt;

  int get invoiceCount => invoices.length;
  int get clientCount => clients.length;
}

Future<File> _writeExportFile(String filename, String content) async {
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
      return file.writeAsString(content, flush: true);
    } catch (e) {
      lastError = e;
    }
  }

  throw FileSystemException('Unable to save export', lastError?.toString());
}

String _safeCell(Object? value) {
  final text = (value ?? '').toString().replaceAll('"', '""');
  return '"$text"';
}

Future<File> createInvoicesCsvFile() async {
  final rows = <List<Object?>>[
    [
      'Invoice No',
      'Date',
      'Client',
      'Status',
      'Subtotal',
      'Discount',
      'GST',
      'CGST',
      'SGST',
      'IGST',
      'Total',
      'Paid',
      'Balance',
    ],
    ...Store.i.all.map(
      (inv) => [
        inv.num,
        fDate(inv.date),
        inv.clientDisplay,
        inv.statusLabel,
        inv.sub.toStringAsFixed(2),
        inv.discountAmount.toStringAsFixed(2),
        inv.tax.toStringAsFixed(2),
        inv.cgst.toStringAsFixed(2),
        inv.sgst.toStringAsFixed(2),
        inv.igst.toStringAsFixed(2),
        inv.total.toStringAsFixed(2),
        inv.paidAmt.toStringAsFixed(2),
        inv.balance.toStringAsFixed(2),
      ],
    ),
  ];
  final csv = rows.map((row) => row.map(_safeCell).join(',')).join('\n');
  return _writeExportFile(
    'invoy_invoices_${DateTime.now().millisecondsSinceEpoch}.csv',
    csv,
  );
}

Future<File> createGstSummaryCsvFile() async {
  final rows = <List<Object?>>[
    [
      'Invoice No',
      'Date',
      'Client',
      'Client GSTIN',
      'Place of Supply',
      'Tax Type',
      'Taxable Value',
      'CGST',
      'SGST',
      'IGST',
      'Total GST',
      'Invoice Total',
      'Status',
    ],
    ...Store.i.all.where((inv) => inv.gst > 0).map(
          (inv) => [
            inv.num,
            fDate(inv.date),
            inv.clientDisplay,
            inv.client.gstin,
            inv.placeOfSupply,
            inv.splitGst ? 'CGST + SGST' : 'IGST',
            inv.taxableSub.toStringAsFixed(2),
            inv.cgst.toStringAsFixed(2),
            inv.sgst.toStringAsFixed(2),
            inv.igst.toStringAsFixed(2),
            inv.tax.toStringAsFixed(2),
            inv.total.toStringAsFixed(2),
            inv.statusLabel,
          ],
        ),
  ];
  final csv = rows.map((row) => row.map(_safeCell).join(',')).join('\n');
  return _writeExportFile(
    'invoy_gst_summary_${DateTime.now().millisecondsSinceEpoch}.csv',
    csv,
  );
}

Map<String, dynamic> createBackupPayload({DateTime? backedUpAt}) {
  final backupTime = backedUpAt?.toIso8601String() ?? Prefs.lastBackupAt.value;
  return {
    'app': 'Invoy',
    'version': 1,
    'createdAt': DateTime.now().toIso8601String(),
    'prefs': {
      'yourName': Prefs.yourName.value,
      'bizName': Prefs.bizName.value,
      'bizAddress': Prefs.bizAddress.value,
      'bizState': Prefs.bizState.value,
      'gstNum': Prefs.gstNum.value,
      'upiId': Prefs.upiId.value,
      'upiQrImage': Prefs.upiQrImage.value,
      'upiQrImageName': Prefs.upiQrImageName.value,
      'invPrefix': Prefs.invPrefix.value,
      'defaultTemplate': Prefs.defaultTemplate.value,
      'lastBackupAt': backupTime,
      'showUpiQr': Prefs.showUpiQr,
      'showDashboardRecent': Prefs.showDashboardRecent,
      'haptics': Prefs.haptics,
      'reduceMotion': Prefs.reduceMotion,
      'splitGst': Prefs.splitGst,
      'startTab': Prefs.startTab,
      'defaultTermDays': Prefs.defaultTermDays,
      'defaultGst': Prefs.defaultGst,
      'themeMode': Prefs.themeMode.value.name,
      'onboarded': Prefs.onboarded.value,
    },
    'clients': Store.i.clients.map((c) => c.toMap()).toList(),
    'savedItems': Store.i.savedItems.map((i) => i.toMap()).toList(),
    'invoices': Store.i.all.map((i) => i.toMap()).toList(),
  };
}

Future<File> createBackupJsonFile({DateTime? backedUpAt}) async {
  final backup = createBackupPayload(backedUpAt: backedUpAt);
  final json = const JsonEncoder.withIndent('  ').convert(backup);
  return _writeExportFile(
    'invoy_backup_${DateTime.now().millisecondsSinceEpoch}.json',
    json,
  );
}

Future<String> exportInvoicesCsv() async {
  final file = await createInvoicesCsvFile();
  return file.path;
}

Future<String> exportBackupJson({DateTime? backedUpAt}) async {
  final file = await createBackupJsonFile(backedUpAt: backedUpAt);
  return file.path;
}

Future<String> exportGstSummaryCsv() async {
  final file = await createGstSummaryCsvFile();
  return file.path;
}

Future<String> shareInvoicesCsv() async {
  final file = await createInvoicesCsvFile();
  await Share.shareXFiles([XFile(file.path)], text: 'Invoy invoice export');
  return file.path;
}

Future<String> shareBackupJson({DateTime? backedUpAt}) async {
  final file = await createBackupJsonFile(backedUpAt: backedUpAt);
  await Share.shareXFiles([XFile(file.path)], text: 'Invoy data backup');
  return file.path;
}

Future<String> shareGstSummaryCsv() async {
  final file = await createGstSummaryCsvFile();
  await Share.shareXFiles([XFile(file.path)], text: 'Invoy GST summary');
  return file.path;
}

Future<BackupPreview?> pickBackupPreview() async {
  final result = await FilePicker.pickFiles(
    type: FileType.custom,
    allowedExtensions: const ['json'],
    withData: true,
  );
  if (result == null || result.files.isEmpty) return null;

  final file = result.files.single;
  final path = file.path ?? file.name;
  final content = file.bytes != null
      ? utf8.decode(file.bytes!)
      : file.path == null
          ? throw const FormatException('Could not read backup file')
          : await File(file.path!).readAsString();
  return parseBackupJson(content, path: path);
}

BackupPreview parseBackupJson(String content, {String path = ''}) {
  final decoded = jsonDecode(content);
  if (decoded is! Map) {
    throw const FormatException('Backup file is not valid JSON');
  }
  final root = Map<String, dynamic>.from(decoded);
  final invoicesRaw = root['invoices'];
  final clientsRaw = root['clients'];
  final savedItemsRaw = root['savedItems'];
  final prefsRaw = root['prefs'];

  if (invoicesRaw is! List) {
    throw const FormatException('Backup file is missing app data');
  }

  Map<String, dynamic> objectMap(Object? value) {
    if (value is Map) return Map<String, dynamic>.from(value);
    throw const FormatException('Backup file contains invalid rows');
  }

  final invoices = invoicesRaw.map((e) {
    final map = objectMap(e);
    if (map['items'] is List) {
      map['items'] = jsonEncode(map['items']);
    }
    if (map['payments'] is List) {
      map['payments'] = jsonEncode(map['payments']);
    }
    return Invoice.fromMap(map);
  }).toList();
  final clients = clientsRaw is List
      ? clientsRaw.map((e) => Customer.fromMap(objectMap(e))).toList()
      : <Customer>[];
  final savedItems = savedItemsRaw is List
      ? savedItemsRaw.map((e) => SavedItem.fromMap(objectMap(e))).toList()
      : <SavedItem>[];
  final prefs = prefsRaw is Map
      ? Map<String, dynamic>.from(prefsRaw)
      : <String, dynamic>{};
  final createdAtRaw = root['createdAt']?.toString();

  return BackupPreview(
    path: path,
    invoices: invoices,
    clients: clients,
    savedItems: savedItems,
    prefs: prefs,
    createdAt: createdAtRaw == null ? null : DateTime.tryParse(createdAtRaw),
  );
}
