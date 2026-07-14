import 'dart:convert';
import 'dart:collection';
import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'theme.dart';

int _uidSeq = 0;

String uid() {
  _uidSeq = (_uidSeq + 1) & 0xFFFFF;
  return '${DateTime.now().microsecondsSinceEpoch}-$_uidSeq';
}

enum PayMode { upi, bank, cash, cheque }

enum Status { draft, pending, paid, overdue }

const double kMaxInvoiceAmount = 9e17;
const double kMaxInvoiceQuantity = 999999999;
const int kMaxInvoiceNumberLength = 16;
const int kMaxInvoicePrefixLength = 5;

const Map<String, String> _gstStateCodes = {
  'jammuandkashmir': '01',
  'himachalpradesh': '02',
  'punjab': '03',
  'chandigarh': '04',
  'uttarakhand': '05',
  'uttaranchal': '05',
  'haryana': '06',
  'delhi': '07',
  'newdelhi': '07',
  'rajasthan': '08',
  'uttarpradesh': '09',
  'bihar': '10',
  'sikkim': '11',
  'arunachalpradesh': '12',
  'nagaland': '13',
  'manipur': '14',
  'mizoram': '15',
  'tripura': '16',
  'meghalaya': '17',
  'assam': '18',
  'westbengal': '19',
  'jharkhand': '20',
  'odisha': '21',
  'orissa': '21',
  'chhattisgarh': '22',
  'madhyapradesh': '23',
  'gujarat': '24',
  'dadraandnagarhavelianddamananddiu': '26',
  'damananddiu': '26',
  'dadraandnagarhaveli': '26',
  'maharashtra': '27',
  'karnataka': '29',
  'goa': '30',
  'lakshadweep': '31',
  'kerala': '32',
  'tamilnadu': '33',
  'puducherry': '34',
  'pondicherry': '34',
  'andamanandnicobarislands': '35',
  'telangana': '36',
  'andhrapradesh': '37',
  'ladakh': '38',
  'otherterritory': '97',
};

String _stateKey(String value) =>
    value.toLowerCase().replaceAll(RegExp(r'[^a-z]'), '');

String? gstStateCode(String state) => _gstStateCodes[_stateKey(state)];

String gstStateWithCode(String state) {
  final clean = state.trim();
  final code = gstStateCode(clean);
  if (code == null || RegExp('\\($code\\)\$').hasMatch(clean)) return clean;
  return '$clean ($code)';
}

bool? splitGstForStates(String supplierState, String placeOfSupply) {
  final supplierCode = gstStateCode(supplierState);
  final supplyCode = gstStateCode(placeOfSupply);
  if (supplierCode == null || supplyCode == null) return null;
  return supplierCode == supplyCode;
}

bool gstinMatchesState(String gstin, String state) {
  final clean = gstin.trim().toUpperCase();
  if (clean.isEmpty) return true;
  final code = gstStateCode(state);
  return code == null || clean.startsWith(code);
}

bool isValidHsnSac(String value) {
  final clean = value.trim();
  if (clean.isEmpty) return true;
  return RegExp(r'^(?:\d{4}|\d{6}|\d{8})$').hasMatch(clean);
}

String sanitizeInvoicePrefix(String value,
    {int maxLength = kMaxInvoicePrefixLength}) {
  final clean = value.trim().toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
  final fallback = clean.isEmpty ? 'INV' : clean;
  return fallback.substring(0, fallback.length.clamp(0, maxLength));
}

String financialYearCode(DateTime date) {
  final startYear = date.month >= 4 ? date.year : date.year - 1;
  final start = (startYear % 100).toString().padLeft(2, '0');
  final end = ((startYear + 1) % 100).toString().padLeft(2, '0');
  return '$start-$end';
}

String buildInvoiceNumber(String prefix, DateTime date, int serial) {
  final serialText = serial.clamp(1, 99999999).toString().padLeft(3, '0');
  final suffix = '-${financialYearCode(date)}-$serialText';
  final maxPrefix = (kMaxInvoiceNumberLength - suffix.length).clamp(1, 5);
  return '${sanitizeInvoicePrefix(prefix, maxLength: maxPrefix)}$suffix';
}

class Customer {
  String name, email, phone, address, gstin, state;
  Customer({
    this.name = '',
    this.email = '',
    this.phone = '',
    this.address = '',
    this.gstin = '',
    this.state = '',
  });
  bool get isEmpty => name.isEmpty;

  Customer copy() => Customer(
        name: name,
        email: email,
        phone: phone,
        address: address,
        gstin: gstin,
        state: state,
      );

  Map<String, dynamic> toMap() => {
        'name': name,
        'email': email,
        'phone': phone,
        'address': address,
        'gstin': gstin,
        'state': state,
      };

  factory Customer.fromMap(Map<String, dynamic> m) => Customer(
        name: m['name'] ?? '',
        email: m['email'] ?? '',
        phone: m['phone'] ?? '',
        address: m['address'] ?? '',
        gstin: m['gstin'] ?? '',
        state: m['state'] ?? '',
      );
}

class LineItem {
  final String id;
  String desc, hsnSac, unit;
  double qty, rate;
  double? gstRate;

  LineItem({
    required this.id,
    this.desc = '',
    this.qty = 1,
    this.rate = 0,
    this.hsnSac = '',
    this.unit = 'Nos',
    this.gstRate,
  });
  double get total => _boundedMoney(qty * rate);

  LineItem copy({String? id}) => LineItem(
        id: id ?? this.id,
        desc: desc,
        qty: qty,
        rate: rate,
        hsnSac: hsnSac,
        unit: unit,
        gstRate: gstRate,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'desc': desc,
        'qty': qty,
        'rate': rate,
        'hsnSac': hsnSac,
        'unit': unit,
        'gstRate': gstRate,
      };

  factory LineItem.fromMap(Map<String, dynamic> m) => LineItem(
        id: m['id'] ?? uid(),
        desc: m['desc'] ?? '',
        qty: _safeQuantity(m['qty']),
        rate: _safeMoney(m['rate']),
        hsnSac: m['hsnSac']?.toString() ?? '',
        unit: (m['unit']?.toString().trim().isNotEmpty ?? false)
            ? m['unit'].toString()
            : 'Nos',
        gstRate: m['gstRate'] == null ? null : _safeTaxRate(m['gstRate']),
      );
}

class SavedItem {
  String desc, hsnSac, unit;
  double rate, gstRate;
  SavedItem({
    this.desc = '',
    this.hsnSac = '',
    this.unit = 'Nos',
    this.rate = 0,
    this.gstRate = 18,
  });

  LineItem toLineItem() => LineItem(
        id: uid(),
        desc: desc,
        qty: 1,
        rate: rate,
        hsnSac: hsnSac,
        unit: unit,
        gstRate: gstRate,
      );

  Map<String, dynamic> toMap() => {
        'desc': desc,
        'hsnSac': hsnSac,
        'unit': unit,
        'rate': rate,
        'gstRate': gstRate,
      };

  factory SavedItem.fromMap(Map<String, dynamic> m) => SavedItem(
        desc: m['desc']?.toString() ?? '',
        hsnSac: m['hsnSac']?.toString() ?? '',
        unit: (m['unit']?.toString().trim().isNotEmpty ?? false)
            ? m['unit'].toString()
            : 'Nos',
        rate: _safeMoney(m['rate']),
        gstRate: _safeTaxRate(m['gstRate'], fallback: 18.0),
      );
}

class Payment {
  final double amount;
  final DateTime date;
  final PayMode mode;
  Payment({required this.amount, required this.date, required this.mode});

  Payment copy() => Payment(amount: amount, date: date, mode: mode);

  Map<String, dynamic> toMap() => {
        'amount': amount,
        'date': date.millisecondsSinceEpoch,
        'mode': mode.name,
      };

  factory Payment.fromMap(Map<String, dynamic> m) => Payment(
        amount: _safeMoney(m['amount']),
        date: DateTime.fromMillisecondsSinceEpoch(
          int.tryParse(m['date']?.toString() ?? '') ?? 0,
        ),
        mode: PayMode.values.firstWhere(
          (e) => e.name == m['mode'],
          orElse: () => PayMode.upi,
        ),
      );
}

typedef InvoiceCollection = ({DateTime date, double amount});

class Invoice {
  final String id;
  String num, template, notes, placeOfSupply, deliveryAddress;
  Customer client;
  List<LineItem> items;
  List<Payment> payments;
  DateTime date;
  int termDays;
  double gst;
  double discountValue;
  bool discountIsPercent;
  bool splitGst;
  bool reverseCharge;
  Status status;
  final DateTime createdAt;

  Invoice({
    required this.id,
    required this.num,
    Customer? client,
    List<LineItem>? items,
    List<Payment>? payments,
    DateTime? date,
    this.termDays = 30,
    this.gst = 18,
    this.discountValue = 0,
    this.discountIsPercent = false,
    this.splitGst = true,
    this.reverseCharge = false,
    this.status = Status.draft,
    this.template = 'Classic',
    this.notes = '',
    this.placeOfSupply = '',
    this.deliveryAddress = '',
    DateTime? createdAt,
  })  : client = client ?? Customer(),
        items = items ?? [],
        payments = payments ?? [],
        date = date ?? DateTime.now(),
        createdAt = createdAt ?? DateTime.now();

  Invoice copy() => Invoice(
        id: id,
        num: num,
        client: client.copy(),
        items: items.map((i) => i.copy()).toList(),
        payments: payments.map((p) => p.copy()).toList(),
        date: date,
        termDays: termDays,
        gst: gst,
        discountValue: discountValue,
        discountIsPercent: discountIsPercent,
        splitGst: splitGst,
        reverseCharge: reverseCharge,
        status: status,
        template: template,
        notes: notes,
        placeOfSupply: placeOfSupply,
        deliveryAddress: deliveryAddress,
        createdAt: createdAt,
      );

  double get sub =>
      items.fold(0.0, (sum, item) => _boundedMoney(sum + item.total));

  String get displayNumber => num.trim().isEmpty ? 'Draft' : num.trim();

  double get discountAmount {
    if (discountValue <= 0 || sub <= 0) return 0;
    final raw = discountIsPercent ? sub * (discountValue / 100) : discountValue;
    return _boundedMoney(raw.clamp(0, sub).toDouble());
  }

  double get taxableSub => _boundedMoney(sub - discountAmount);

  double discountShareFor(LineItem item) {
    if (sub <= 0 || discountAmount <= 0) return 0;
    var index = items.indexWhere((candidate) => identical(candidate, item));
    if (index == -1) {
      index = items.indexWhere((candidate) => candidate.id == item.id);
    }
    if (index == -1) {
      return _boundedMoney(discountAmount * (item.total / sub));
    }

    var allocated = 0.0;
    for (var i = 0; i <= index; i++) {
      final share = i == items.length - 1
          ? _boundedMoney(discountAmount - allocated)
          : _boundedMoney(discountAmount * (items[i].total / sub));
      if (i == index) return share;
      allocated = _boundedMoney(allocated + share);
    }
    return 0;
  }

  double taxableFor(LineItem item) =>
      _boundedMoney(item.total - discountShareFor(item));

  double taxRateFor(LineItem item) {
    final defaultRate = _clampTaxRate(gst);
    if (defaultRate <= 0) return 0;
    return _clampTaxRate(item.gstRate ?? defaultRate);
  }

  double taxFor(LineItem item) =>
      _boundedMoney(taxableFor(item) * (taxRateFor(item) / 100));

  double get tax => items.isEmpty
      ? _boundedMoney(taxableSub * (_clampTaxRate(gst) / 100))
      : items.fold(0.0, (sum, item) => _boundedMoney(sum + taxFor(item)));
  double get cgst => splitGst ? _boundedMoney(tax / 2) : 0;
  double get sgst => splitGst ? _boundedMoney(tax - cgst) : 0;
  double get igst => splitGst ? 0 : tax;
  double get total => _boundedMoney(taxableSub + tax);
  double get paidAmt {
    if (payments.isEmpty && status == Status.paid && items.isNotEmpty) {
      return total;
    }
    final recorded = payments.fold(
      0.0,
      (sum, payment) => _boundedMoney(sum + payment.amount),
    );
    return recorded > total ? total : recorded;
  }

  bool get hasPayment => paidAmt > 0;
  bool get isPartPaid => items.isNotEmpty && hasPayment && balance > 0;

  List<InvoiceCollection> get collections {
    if (items.isEmpty || total <= 0) return const <InvoiceCollection>[];
    if (payments.isEmpty) {
      return status == Status.paid
          ? <InvoiceCollection>[(date: date, amount: total)]
          : const <InvoiceCollection>[];
    }

    final sorted = List<Payment>.from(payments)
      ..sort((a, b) => a.date.compareTo(b.date));
    final result = <InvoiceCollection>[];
    var remaining = total;
    for (final payment in sorted) {
      if (remaining <= 0) break;
      if (payment.amount <= 0) continue;
      final amount = _boundedMoney(
        payment.amount > remaining ? remaining : payment.amount,
      );
      result.add((date: payment.date, amount: amount));
      remaining = _boundedMoney(remaining - amount);
    }
    return result;
  }

  double get collectedAmt => collections.fold(
        0.0,
        (sum, collection) => _boundedMoney(sum + collection.amount),
      );

  double get balance => _boundedMoney(total - paidAmt);

  DateTime get due => date.add(Duration(days: termDays));

  bool get isOverdue {
    if (status == Status.draft ||
        (status == Status.paid && !isPartPaid) ||
        items.isEmpty ||
        balance <= 0) {
      return false;
    }
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dueDay = DateTime(due.year, due.month, due.day);
    return dueDay.isBefore(today);
  }

  Status get displayStatus {
    if (status == Status.draft) return Status.draft;
    if (items.isNotEmpty && balance <= 0) return Status.paid;
    if (status == Status.paid && payments.isEmpty) return Status.paid;
    if (isOverdue) return Status.overdue;
    if (items.isEmpty) return Status.draft;
    return Status.pending;
  }

  Color get statusColor {
    if (isPartPaid) {
      return isOverdue ? C.overdue : C.grey5;
    }
    switch (displayStatus) {
      case Status.paid:
        return C.paid;
      case Status.overdue:
        return C.overdue;
      case Status.draft:
        return C.draft;
      default:
        return C.pending;
    }
  }

  Color get statusBg {
    if (isPartPaid) {
      return isOverdue ? C.overdueBg : C.draftBg;
    }
    switch (displayStatus) {
      case Status.paid:
        return C.paidBg;
      case Status.overdue:
        return C.overdueBg;
      case Status.draft:
        return C.draftBg;
      default:
        return C.pendingBg;
    }
  }

  String get statusLabel {
    if (isPartPaid) return isOverdue ? 'Part overdue' : 'Part paid';
    switch (displayStatus) {
      case Status.paid:
        return 'Paid';
      case Status.overdue:
        return 'Overdue';
      case Status.draft:
        return 'Draft';
      default:
        return 'Pending';
    }
  }

  String get dueDateText {
    if (displayStatus == Status.draft) return 'Draft';
    if (displayStatus == Status.paid) return 'Paid';
    if (isPartPaid && isOverdue) return 'Partial payment received';
    if (isPartPaid) return 'Balance due';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dueDay = DateTime(due.year, due.month, due.day);
    if (isOverdue) {
      final d = today.difference(dueDay).inDays;
      return '$d day${d == 1 ? "" : "s"} overdue';
    }
    final d = dueDay.difference(today).inDays;
    if (d <= 0) return 'Due today';
    return 'Due in $d days';
  }

  Color get avatarColor =>
      C.avatarColors[id.hashCode.abs() % C.avatarColors.length];

  String get initials {
    final n = client.name.trim();
    if (n.isEmpty) return '?';
    final parts = n.split(' ').where((w) => w.isNotEmpty).toList();
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return n[0].toUpperCase();
  }

  String get clientDisplay =>
      client.name.isNotEmpty ? client.name : 'Unnamed Client';

  Invoice duplicate(String newId, String newNum) => Invoice(
        id: newId,
        num: newNum,
        client: Customer(
          name: client.name,
          email: client.email,
          phone: client.phone,
          address: client.address,
          gstin: client.gstin,
          state: client.state,
        ),
        items: items
            .map(
              (i) => LineItem(
                id: uid(),
                desc: i.desc,
                qty: i.qty,
                rate: i.rate,
                hsnSac: i.hsnSac,
                unit: i.unit,
                gstRate: i.gstRate,
              ),
            )
            .toList(),
        termDays: termDays,
        gst: gst,
        discountValue: discountValue,
        discountIsPercent: discountIsPercent,
        splitGst: splitGst,
        reverseCharge: reverseCharge,
        status: Status.draft,
        template: template,
        notes: notes,
        placeOfSupply: placeOfSupply,
        deliveryAddress: deliveryAddress,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'num': num,
        'template': template,
        'notes': notes,
        'clientName': client.name,
        'clientEmail': client.email,
        'clientPhone': client.phone,
        'clientAddr': client.address,
        'clientGstin': client.gstin,
        'clientState': client.state,
        'items': jsonEncode(items.map((i) => i.toMap()).toList()),
        'payments': jsonEncode(payments.map((p) => p.toMap()).toList()),
        'invoiceDate': date.millisecondsSinceEpoch,
        'termDays': termDays,
        'gst': gst,
        'discountValue': discountValue,
        'discountIsPercent': discountIsPercent ? 1 : 0,
        'splitGst': splitGst ? 1 : 0,
        'reverseCharge': reverseCharge ? 1 : 0,
        'placeOfSupply': placeOfSupply,
        'deliveryAddress': deliveryAddress,
        'status': status.name,
        'createdAt': createdAt.millisecondsSinceEpoch,
      };

  factory Invoice.fromMap(Map<String, dynamic> m) {
    final itemsRaw = jsonDecode(m['items'] as String? ?? '[]') as List;
    final paysRaw = jsonDecode(m['payments'] as String? ?? '[]') as List;
    return Invoice(
      id: m['id'] as String,
      num: m['num'] as String,
      template: m['template'] as String? ?? 'Classic',
      notes: m['notes'] as String? ?? '',
      client: Customer(
        name: m['clientName'] as String? ?? '',
        email: m['clientEmail'] as String? ?? '',
        phone: m['clientPhone'] as String? ?? '',
        address: m['clientAddr'] as String? ?? '',
        gstin: m['clientGstin'] as String? ?? '',
        state: m['clientState'] as String? ?? '',
      ),
      items: itemsRaw
          .map((e) => LineItem.fromMap(e as Map<String, dynamic>))
          .toList(),
      payments: paysRaw
          .map((e) => Payment.fromMap(e as Map<String, dynamic>))
          .toList(),
      date: DateTime.fromMillisecondsSinceEpoch(
        _safeInt(m['invoiceDate'],
            fallback: DateTime.now().millisecondsSinceEpoch),
      ),
      termDays: _safeTermDays(m['termDays']),
      gst: _safeTaxRate(m['gst'], fallback: 18.0),
      discountValue: _safeMoney(m['discountValue']),
      discountIsPercent: _safeBool(m['discountIsPercent']),
      splitGst: _safeBool(m['splitGst'], fallback: true),
      reverseCharge: _safeBool(m['reverseCharge']),
      placeOfSupply: m['placeOfSupply'] as String? ?? '',
      deliveryAddress: m['deliveryAddress'] as String? ?? '',
      status: Status.values.firstWhere(
        (e) => e.name == m['status'],
        orElse: () => Status.draft,
      ),
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        int.tryParse(m['createdAt']?.toString() ?? '') ??
            int.tryParse(m['invoiceDate']?.toString() ?? '') ??
            DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }
}

double _safeDouble(Object? value, {double fallback = 0}) {
  final parsed = double.tryParse(value?.toString().replaceAll(',', '') ?? '');
  if (parsed == null || !parsed.isFinite) return fallback;
  return parsed;
}

double _safeMoney(Object? value, {double fallback = 0}) {
  final parsed = _safeDouble(value, fallback: fallback);
  return _boundedMoney(parsed);
}

double _safeQuantity(Object? value, {double fallback = 1}) {
  final parsed = _safeDouble(value, fallback: fallback);
  if (parsed <= 0) return fallback;
  return parsed > kMaxInvoiceQuantity ? kMaxInvoiceQuantity : parsed;
}

double _boundedMoney(double value) {
  if (!value.isFinite || value <= 0) return 0;
  final bounded = value > kMaxInvoiceAmount ? kMaxInvoiceAmount : value;
  return double.parse(bounded.toStringAsFixed(2));
}

double _safeTaxRate(Object? value, {double fallback = 0}) {
  return _clampTaxRate(_safeDouble(value, fallback: fallback));
}

double _clampTaxRate(double value) {
  if (!value.isFinite || value < 0) return 0;
  if (value > 100) return 100;
  return value;
}

int _safeInt(Object? value, {int fallback = 0}) {
  final parsed = int.tryParse(value?.toString() ?? '');
  return parsed ?? fallback;
}

int _safeTermDays(Object? value, {int fallback = 30}) {
  final parsed = _safeInt(value, fallback: fallback);
  return parsed.clamp(0, 3650).toInt();
}

bool _safeBool(Object? value, {bool fallback = false}) {
  if (value == null) return fallback;
  if (value is bool) return value;
  if (value is num) return value != 0;
  final raw = value.toString().trim().toLowerCase();
  if (raw == '1' || raw == 'true' || raw == 'yes') return true;
  if (raw == '0' || raw == 'false' || raw == 'no') return false;
  return fallback;
}

bool isSupportedRasterImage(List<int> bytes) {
  if (bytes.length >= 8 &&
      bytes[0] == 0x89 &&
      bytes[1] == 0x50 &&
      bytes[2] == 0x4E &&
      bytes[3] == 0x47 &&
      bytes[4] == 0x0D &&
      bytes[5] == 0x0A &&
      bytes[6] == 0x1A &&
      bytes[7] == 0x0A) {
    return true;
  }
  if (bytes.length >= 3 &&
      bytes[0] == 0xFF &&
      bytes[1] == 0xD8 &&
      bytes[2] == 0xFF) {
    return true;
  }
  return bytes.length >= 12 &&
      bytes[0] == 0x52 &&
      bytes[1] == 0x49 &&
      bytes[2] == 0x46 &&
      bytes[3] == 0x46 &&
      bytes[8] == 0x57 &&
      bytes[9] == 0x45 &&
      bytes[10] == 0x42 &&
      bytes[11] == 0x50;
}

class DB {
  static late Database instance;
  static Future<void>? _initFuture;
  static bool _initialized = false;

  static Future<void> init() {
    if (_initialized && instance.isOpen) return Future.value();
    return _initFuture ??= _runInit();
  }

  static Future<void> _runInit() async {
    try {
      await _open();
    } finally {
      _initFuture = null;
    }
  }

  static Future<void> _open() async {
    if (_initialized && instance.isOpen) return;
    final dbPath = await getDatabasesPath();
    instance = await openDatabase(
      p.join(dbPath, 'invoy_v2.db'),
      version: 5,
      onCreate: (db, _) async {
        await db.execute('''
          CREATE TABLE prefs (key TEXT PRIMARY KEY, val TEXT NOT NULL)
        ''');
        await db.execute('''
          CREATE TABLE invoices (
            id TEXT PRIMARY KEY,
            num TEXT, template TEXT, notes TEXT,
            clientName TEXT, clientEmail TEXT,
            clientPhone TEXT, clientAddr TEXT, clientGstin TEXT,
            clientState TEXT,
            items TEXT, payments TEXT,
            invoiceDate INTEGER, termDays INTEGER, gst REAL,
            discountValue REAL, discountIsPercent INTEGER,
            splitGst INTEGER, reverseCharge INTEGER,
            placeOfSupply TEXT, deliveryAddress TEXT,
            status TEXT, createdAt INTEGER
          )
        ''');
        await db.execute('''
          CREATE TABLE counter (id INTEGER PRIMARY KEY, val INTEGER)
        ''');
        await _createClientsTable(db);
        await _createSavedItemsTable(db);
      },
      onUpgrade: (db, oldVersion, _) async {
        if (oldVersion < 2) {
          await _createClientsTable(db);
        }
        if (oldVersion < 3) {
          await _addColumnIfMissing(
            db,
            'invoices',
            'discountValue',
            'REAL DEFAULT 0',
          );
          await _addColumnIfMissing(
            db,
            'invoices',
            'discountIsPercent',
            'INTEGER DEFAULT 0',
          );
        }
        if (oldVersion < 4) {
          await _createClientsTable(db);
          await _createSavedItemsTable(db);
          await _addColumnIfMissing(db, 'clients', 'state', 'TEXT DEFAULT ""');
          await _addColumnIfMissing(
            db,
            'invoices',
            'clientState',
            'TEXT DEFAULT ""',
          );
          await _addColumnIfMissing(
            db,
            'invoices',
            'reverseCharge',
            'INTEGER DEFAULT 0',
          );
          await _addColumnIfMissing(
            db,
            'invoices',
            'placeOfSupply',
            'TEXT DEFAULT ""',
          );
        }
        if (oldVersion < 5) {
          await _addColumnIfMissing(
            db,
            'invoices',
            'deliveryAddress',
            'TEXT DEFAULT ""',
          );
        }
      },
    );
    _initialized = true;
  }

  static Future<void> _createClientsTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS clients (
        name TEXT PRIMARY KEY COLLATE NOCASE,
        email TEXT,
        phone TEXT,
        address TEXT,
        gstin TEXT,
        state TEXT,
        createdAt INTEGER
      )
    ''');
  }

  static Future<void> _createSavedItemsTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS saved_items (
        desc TEXT PRIMARY KEY,
        hsnSac TEXT,
        unit TEXT,
        rate REAL,
        gstRate REAL,
        createdAt INTEGER
      )
    ''');
  }

  static Future<void> _addColumnIfMissing(
    Database db,
    String table,
    String column,
    String definition,
  ) async {
    final rows = await db.rawQuery('PRAGMA table_info($table)');
    final exists = rows.any((row) => row['name'] == column);
    if (!exists) {
      await db.execute('ALTER TABLE $table ADD COLUMN $column $definition');
    }
  }

  static Future<String> nextNum(DateTime invoiceDate) async {
    return instance.transaction((txn) async {
      final periodId =
          invoiceDate.month >= 4 ? invoiceDate.year : invoiceDate.year - 1;
      final rows = await txn.query(
        'counter',
        where: 'id = ?',
        whereArgs: [periodId],
      );
      var next = (rows.isEmpty ? 0 : _safeInt(rows.first['val'])) + 1;
      var candidate = buildInvoiceNumber(
        Prefs.invPrefix.value,
        invoiceDate,
        next,
      );
      while ((await txn.query(
        'invoices',
        columns: ['id'],
        where: 'num = ?',
        whereArgs: [candidate],
        limit: 1,
      ))
          .isNotEmpty) {
        next++;
        candidate = buildInvoiceNumber(
          Prefs.invPrefix.value,
          invoiceDate,
          next,
        );
      }
      await txn.insert(
        'counter',
        {'id': periodId, 'val': next},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      return candidate;
    });
  }

  static Future<void> saveInvoice(Invoice inv) async {
    await instance.insert(
      'invoices',
      inv.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<void> deleteInvoice(String id) async {
    await instance.delete('invoices', where: 'id = ?', whereArgs: [id]);
  }

  static Future<void> replaceInvoices(List<Invoice> invoices) async {
    await instance.transaction((txn) async {
      await txn.delete('invoices');
      for (final inv in invoices) {
        await txn.insert(
          'invoices',
          inv.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  static Future<List<Invoice>> loadAll() async {
    final rows = await instance.query('invoices', orderBy: 'createdAt DESC');
    final invoices = <Invoice>[];
    for (final row in rows) {
      try {
        invoices.add(Invoice.fromMap(row));
      } catch (_) {
        // Ignore a corrupt row so local startup never gets stuck on bad data.
      }
    }
    return invoices;
  }

  static Future<void> saveClient(Customer c) async {
    await instance.transaction((txn) async {
      await txn.delete(
        'clients',
        where: 'name = ? COLLATE NOCASE',
        whereArgs: [c.name],
      );
      await txn.insert(
        'clients',
        {
          'name': c.name,
          'email': c.email,
          'phone': c.phone,
          'address': c.address,
          'gstin': c.gstin,
          'state': c.state,
          'createdAt': DateTime.now().millisecondsSinceEpoch,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });
  }

  static Future<void> deleteClient(String name) async {
    await instance.delete(
      'clients',
      where: 'name = ? COLLATE NOCASE',
      whereArgs: [name],
    );
  }

  static Future<void> updateClientAndInvoices(
    String oldName,
    Customer client,
    List<Invoice> invoices,
  ) async {
    await instance.transaction((txn) async {
      await txn.delete(
        'clients',
        where: 'name = ? COLLATE NOCASE',
        whereArgs: [oldName],
      );
      if (oldName.trim().toLowerCase() != client.name.trim().toLowerCase()) {
        await txn.delete(
          'clients',
          where: 'name = ? COLLATE NOCASE',
          whereArgs: [client.name],
        );
      }
      await txn.insert(
        'clients',
        {
          'name': client.name,
          'email': client.email,
          'phone': client.phone,
          'address': client.address,
          'gstin': client.gstin,
          'state': client.state,
          'createdAt': DateTime.now().millisecondsSinceEpoch,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      for (final invoice in invoices) {
        await txn.insert(
          'invoices',
          invoice.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  static Future<void> replaceClients(List<Customer> clients) async {
    await instance.transaction((txn) async {
      await txn.delete('clients');
      for (final c in clients) {
        final clean = Customer(
          name: c.name.trim(),
          email: c.email.trim(),
          phone: c.phone.trim(),
          address: c.address.trim(),
          gstin: c.gstin.trim(),
          state: c.state.trim(),
        );
        if (clean.name.isEmpty) continue;
        await txn.insert(
            'clients',
            {
              'name': clean.name,
              'email': clean.email,
              'phone': clean.phone,
              'address': clean.address,
              'gstin': clean.gstin,
              'state': clean.state,
              'createdAt': DateTime.now().millisecondsSinceEpoch,
            },
            conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }

  static Future<void> resetCounterFromInvoices(List<Invoice> invoices) async {
    final maxByPeriod = <int, int>{};
    final numberEnd = RegExp(r'(\d+)$');
    for (final inv in invoices) {
      final match = numberEnd.firstMatch(inv.num);
      if (match == null) continue;
      final value = int.tryParse(match.group(1) ?? '');
      final periodId = inv.date.month >= 4 ? inv.date.year : inv.date.year - 1;
      if (value != null && value > (maxByPeriod[periodId] ?? 0)) {
        maxByPeriod[periodId] = value;
      }
    }
    await instance.transaction((txn) async {
      await txn.delete('counter');
      for (final entry in maxByPeriod.entries) {
        await txn.insert('counter', {'id': entry.key, 'val': entry.value});
      }
    });
  }

  static Future<List<Customer>> loadClients() async {
    final rows = await instance.query(
      'clients',
      orderBy: 'name COLLATE NOCASE',
    );
    return rows
        .map(
          (m) => Customer(
            name: m['name'] as String? ?? '',
            email: m['email'] as String? ?? '',
            phone: m['phone'] as String? ?? '',
            address: m['address'] as String? ?? '',
            gstin: m['gstin'] as String? ?? '',
            state: m['state'] as String? ?? '',
          ),
        )
        .where((c) => c.name.trim().isNotEmpty)
        .toList();
  }

  static Future<List<SavedItem>> loadSavedItems() async {
    final rows = await instance.query('saved_items', orderBy: 'createdAt DESC');
    return rows
        .map(
          (m) => SavedItem(
            desc: m['desc'] as String? ?? '',
            hsnSac: m['hsnSac'] as String? ?? '',
            unit: m['unit'] as String? ?? 'Nos',
            rate: _safeDouble(m['rate']),
            gstRate: _safeDouble(m['gstRate'], fallback: 18),
          ),
        )
        .where((i) => i.desc.trim().isNotEmpty)
        .toList();
  }

  static Future<void> saveSavedItem(SavedItem item) async {
    final clean = SavedItem(
      desc: item.desc.trim(),
      hsnSac: item.hsnSac.trim(),
      unit: item.unit.trim().isEmpty ? 'Nos' : item.unit.trim(),
      rate: item.rate,
      gstRate: item.gstRate,
    );
    if (clean.desc.isEmpty) return;
    await instance.transaction((txn) async {
      await txn.delete(
        'saved_items',
        where: 'desc = ? COLLATE NOCASE',
        whereArgs: [clean.desc],
      );
      await txn.insert(
        'saved_items',
        {
          'desc': clean.desc,
          'hsnSac': clean.hsnSac,
          'unit': clean.unit,
          'rate': clean.rate,
          'gstRate': clean.gstRate,
          'createdAt': DateTime.now().millisecondsSinceEpoch,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });
  }

  static Future<void> replaceSavedItems(List<SavedItem> items) async {
    await instance.transaction((txn) async {
      await txn.delete('saved_items');
      for (final item in items) {
        final clean = SavedItem(
          desc: item.desc.trim(),
          hsnSac: item.hsnSac.trim(),
          unit: item.unit.trim().isEmpty ? 'Nos' : item.unit.trim(),
          rate: item.rate,
          gstRate: item.gstRate,
        );
        if (clean.desc.isEmpty) continue;
        await txn.insert(
            'saved_items',
            {
              'desc': clean.desc,
              'hsnSac': clean.hsnSac,
              'unit': clean.unit,
              'rate': clean.rate,
              'gstRate': clean.gstRate,
              'createdAt': DateTime.now().millisecondsSinceEpoch,
            },
            conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }

  static Future<void> replaceAppData({
    required List<Invoice> invoices,
    required List<Customer> clients,
    required List<SavedItem> savedItems,
  }) async {
    final maxByPeriod = <int, int>{};
    final numberEnd = RegExp(r'(\d+)$');
    for (final invoice in invoices) {
      final match = numberEnd.firstMatch(invoice.num);
      final value = int.tryParse(match?.group(1) ?? '');
      if (value == null) continue;
      final periodId =
          invoice.date.month >= 4 ? invoice.date.year : invoice.date.year - 1;
      if (value > (maxByPeriod[periodId] ?? 0)) {
        maxByPeriod[periodId] = value;
      }
    }

    await instance.transaction((txn) async {
      await txn.delete('invoices');
      await txn.delete('clients');
      await txn.delete('saved_items');
      await txn.delete('counter');

      for (final invoice in invoices) {
        await txn.insert('invoices', invoice.toMap());
      }
      for (final client in clients) {
        await txn.insert('clients', {
          'name': client.name,
          'email': client.email,
          'phone': client.phone,
          'address': client.address,
          'gstin': client.gstin,
          'state': client.state,
          'createdAt': DateTime.now().millisecondsSinceEpoch,
        });
      }
      for (final item in savedItems) {
        await txn.insert('saved_items', {
          'desc': item.desc,
          'hsnSac': item.hsnSac,
          'unit': item.unit,
          'rate': item.rate,
          'gstRate': item.gstRate,
          'createdAt': DateTime.now().millisecondsSinceEpoch,
        });
      }
      for (final entry in maxByPeriod.entries) {
        await txn.insert('counter', {'id': entry.key, 'val': entry.value});
      }
    });
  }
}

class Prefs {
  static final themeMode = ValueNotifier<ThemeMode>(ThemeMode.light);
  static final onboarded = ValueNotifier<bool>(false);
  static final yourName = ValueNotifier<String>('');
  static final bizName = ValueNotifier<String>('');
  static final bizAddress = ValueNotifier<String>('');
  static final bizState = ValueNotifier<String>('');
  static final gstNum = ValueNotifier<String>('');
  static final upiId = ValueNotifier<String>('');
  static final upiQrImage = ValueNotifier<String>('');
  static final upiQrImageName = ValueNotifier<String>('');
  static final signatureImage = ValueNotifier<String>('');
  static final signatureImageName = ValueNotifier<String>('');
  static final invPrefix = ValueNotifier<String>('INV');
  static final defaultTemplate = ValueNotifier<String>('Classic');
  static final lastBackupAt = ValueNotifier<String>('');
  static bool showUpiQr = true;
  static bool showDashboardRecent = true;
  static bool haptics = true;
  static bool reduceMotion = false;
  static bool splitGst = true;
  static int startTab = 0;
  static int defaultTermDays = 30;
  static double defaultGst = 18.0;
  static Future<void>? _loadFuture;
  static bool _loaded = false;

  static Future<void> load() {
    if (_loaded) return Future.value();
    return _loadFuture ??= _runLoad();
  }

  static Future<void> _runLoad() async {
    try {
      await _load();
      _loaded = true;
    } finally {
      _loadFuture = null;
    }
  }

  static Future<void> _load() async {
    final rows = await DB.instance.query('prefs');
    final map = {for (final r in rows) r['key'] as String: r['val'] as String};

    yourName.value = map['yourName'] ?? '';
    bizName.value = map['bizName'] ?? '';
    bizAddress.value = map['bizAddress'] ?? '';
    bizState.value = map['bizState'] ?? '';
    gstNum.value = map['gstNum'] ?? '';
    upiId.value = map['upiId'] ?? '';
    upiQrImage.value = map['upiQrImage'] ?? '';
    upiQrImageName.value = map['upiQrImageName'] ?? '';
    signatureImage.value = map['signatureImage'] ?? '';
    signatureImageName.value = map['signatureImageName'] ?? '';
    invPrefix.value = map['invPrefix'] ?? 'INV';
    defaultTemplate.value = map['defaultTemplate'] ?? 'Classic';
    lastBackupAt.value = map['lastBackupAt'] ?? '';
    showUpiQr = (map['showUpiQr'] ?? '1') == '1';
    showDashboardRecent = (map['showDashboardRecent'] ?? '1') == '1';
    haptics = (map['haptics'] ?? '1') == '1';
    reduceMotion = (map['reduceMotion'] ?? '0') == '1';
    reduceAppMotion = reduceMotion;
    splitGst = (map['splitGst'] ?? '1') == '1';
    startTab = (int.tryParse(map['startTab'] ?? '0') ?? 0).clamp(0, 2);
    defaultTermDays = _safeTermDays(map['defaultTermDays']);
    defaultGst = _safeTaxRate(map['defaultGst'], fallback: 18.0);
    onboarded.value = (map['onboarded'] ?? '0') == '1';

    final tm = map['themeMode'] ?? 'light';
    themeMode.value = tm == 'dark'
        ? ThemeMode.dark
        : tm == 'system'
            ? ThemeMode.system
            : ThemeMode.light;
  }

  static Future<void> _save(String key, String val) async {
    await DB.instance.insert(
        'prefs',
        {
          'key': key,
          'val': val,
        },
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  static Future<void> update(String key, String val) async {
    switch (key) {
      case 'yourName':
        yourName.value = val;
        break;
      case 'bizName':
        bizName.value = val;
        break;
      case 'bizAddress':
        bizAddress.value = val;
        break;
      case 'bizState':
        bizState.value = val;
        break;
      case 'gstNum':
        gstNum.value = val;
        break;
      case 'upiId':
        upiId.value = val;
        break;
      case 'invPrefix':
        invPrefix.value = val;
        break;
      case 'defaultTemplate':
        defaultTemplate.value = val;
        break;
    }
    await _save(key, val);
  }

  static Future<void> restoreFromMap(Map<String, dynamic> prefs) async {
    String? text(String key) {
      final value = prefs[key];
      return value?.toString();
    }

    bool? boolValue(String key) {
      final value = prefs[key];
      if (value == null) return null;
      if (value is bool) return value;
      final raw = value.toString().toLowerCase();
      if (raw == '1' || raw == 'true') return true;
      if (raw == '0' || raw == 'false') return false;
      return null;
    }

    int? intValue(String key) {
      final value = prefs[key];
      return value == null ? null : int.tryParse(value.toString());
    }

    double? doubleValue(String key) {
      final value = prefs[key];
      return value == null ? null : double.tryParse(value.toString());
    }

    Future<void> saveText(
      String key,
      ValueNotifier<String> notifier, {
      String? fallback,
    }) async {
      final value = text(key) ?? fallback;
      if (value == null) return;
      notifier.value = value;
      await _save(key, value);
    }

    await saveText('yourName', yourName, fallback: yourName.value);
    await saveText('bizName', bizName, fallback: bizName.value);
    await saveText('bizAddress', bizAddress, fallback: bizAddress.value);
    await saveText('bizState', bizState, fallback: bizState.value);
    await saveText('gstNum', gstNum, fallback: gstNum.value);
    await saveText('upiId', upiId, fallback: upiId.value);
    await saveText('upiQrImage', upiQrImage, fallback: upiQrImage.value);
    await saveText(
      'upiQrImageName',
      upiQrImageName,
      fallback: upiQrImageName.value,
    );
    await saveText(
      'signatureImage',
      signatureImage,
      fallback: signatureImage.value,
    );
    await saveText(
      'signatureImageName',
      signatureImageName,
      fallback: signatureImageName.value,
    );
    await saveText('invPrefix', invPrefix, fallback: invPrefix.value);
    await saveText(
      'defaultTemplate',
      defaultTemplate,
      fallback: defaultTemplate.value,
    );
    await saveText('lastBackupAt', lastBackupAt, fallback: lastBackupAt.value);

    final split = boolValue('splitGst');
    if (split != null) {
      splitGst = split;
      await _save('splitGst', split ? '1' : '0');
    }

    final qr = boolValue('showUpiQr');
    if (qr != null) {
      showUpiQr = qr;
      await _save('showUpiQr', qr ? '1' : '0');
    }

    final recent = boolValue('showDashboardRecent');
    if (recent != null) {
      showDashboardRecent = recent;
      await _save('showDashboardRecent', recent ? '1' : '0');
    }

    final restoredHaptics = boolValue('haptics');
    if (restoredHaptics != null) {
      haptics = restoredHaptics;
      await _save('haptics', restoredHaptics ? '1' : '0');
    }

    final motion = boolValue('reduceMotion');
    if (motion != null) {
      reduceMotion = motion;
      reduceAppMotion = motion;
      await _save('reduceMotion', motion ? '1' : '0');
    }

    final tab = intValue('startTab');
    if (tab != null) {
      startTab = tab.clamp(0, 2);
      await _save('startTab', '$startTab');
    }

    final terms = intValue('defaultTermDays');
    if (terms != null) {
      defaultTermDays = terms.clamp(0, 3650).toInt();
      await _save('defaultTermDays', '$defaultTermDays');
    }

    final gst = doubleValue('defaultGst');
    if (gst != null) {
      defaultGst = _clampTaxRate(gst);
      await _save('defaultGst', '$defaultGst');
    }

    final onboard = boolValue('onboarded');
    if (onboard == true) {
      onboarded.value = true;
      await _save('onboarded', '1');
    }

    final theme = text('themeMode');
    if (theme != null) {
      themeMode.value = theme == 'dark'
          ? ThemeMode.dark
          : theme == 'system'
              ? ThemeMode.system
              : ThemeMode.light;
      await _save('themeMode', themeMode.value.name);
    }
  }

  static Future<void> setTheme(ThemeMode m) async {
    themeMode.value = m;
    await _save(
      'themeMode',
      m == ThemeMode.dark
          ? 'dark'
          : m == ThemeMode.system
              ? 'system'
              : 'light',
    );
  }

  static Future<void> setSplitGst(bool v) async {
    splitGst = v;
    await _save('splitGst', v ? '1' : '0');
  }

  static Future<void> setShowUpiQr(bool v) async {
    showUpiQr = v;
    await _save('showUpiQr', v ? '1' : '0');
  }

  static Future<void> setShowDashboardRecent(bool v) async {
    showDashboardRecent = v;
    await _save('showDashboardRecent', v ? '1' : '0');
  }

  static Future<void> setHaptics(bool v) async {
    haptics = v;
    await _save('haptics', v ? '1' : '0');
  }

  static Future<void> setReduceMotion(bool v) async {
    reduceMotion = v;
    reduceAppMotion = v;
    await _save('reduceMotion', v ? '1' : '0');
  }

  static Future<void> setStartTab(int v) async {
    startTab = v.clamp(0, 2);
    await _save('startTab', '$startTab');
  }

  static Future<void> setUpiQrImage(String data, String name) async {
    upiQrImage.value = data;
    upiQrImageName.value = name;
    await _save('upiQrImage', data);
    await _save('upiQrImageName', name);
  }

  static Future<void> setSignatureImage(String data, String name) async {
    signatureImage.value = data;
    signatureImageName.value = name;
    await _save('signatureImage', data);
    await _save('signatureImageName', name);
  }

  static Future<void> setDefaultTermDays(int v) async {
    defaultTermDays = v.clamp(0, 3650).toInt();
    await _save('defaultTermDays', '$defaultTermDays');
  }

  static Future<void> setDefaultGst(double v) async {
    defaultGst = _clampTaxRate(v);
    await _save('defaultGst', '$defaultGst');
  }

  static Future<void> setDefaultTemplate(String v) async {
    defaultTemplate.value = v;
    await _save('defaultTemplate', v);
  }

  static Future<void> setLastBackupAt(DateTime value) async {
    final iso = value.toIso8601String();
    lastBackupAt.value = iso;
    await _save('lastBackupAt', iso);
  }
}

class Store {
  static final Store i = Store._();
  Store._();

  List<Invoice> _list = [];
  List<Customer> _clients = [];
  List<SavedItem> _savedItems = [];
  UnmodifiableListView<Invoice> _allView = UnmodifiableListView(const []);
  UnmodifiableListView<Invoice> _unpaidView = UnmodifiableListView(const []);
  UnmodifiableListView<Invoice> _paidView = UnmodifiableListView(const []);
  UnmodifiableListView<Invoice> _overdueView = UnmodifiableListView(const []);
  UnmodifiableListView<Customer> _clientView = UnmodifiableListView(const []);
  UnmodifiableListView<SavedItem> _savedItemView = UnmodifiableListView(
    const [],
  );
  double _totalRevenue = 0;
  double _totalPending = 0;
  double _totalOverdue = 0;
  bool _loaded = false;
  Future<void>? _loadFuture;
  int _revision = 0;

  Future<void> load() {
    if (_loaded) return Future.value();
    return _loadFuture ??= _runLoad();
  }

  Future<void> _runLoad() async {
    try {
      final invoices = await DB.loadAll();
      final clients = await DB.loadClients();
      final savedItems = await DB.loadSavedItems();
      _list = invoices;
      _clients = clients;
      _savedItems = savedItems;
      _rebuildViews();
      _loaded = true;
    } finally {
      _loadFuture = null;
    }
  }

  void _rebuildViews() {
    _allView = UnmodifiableListView(_list);
    final unpaid = <Invoice>[];
    final paid = <Invoice>[];
    final overdue = <Invoice>[];
    var revenue = 0.0;
    var pending = 0.0;
    var overdueAmount = 0.0;

    for (final inv in _list) {
      revenue = _boundedMoney(revenue + inv.collectedAmt);
      final displayStatus = inv.displayStatus;
      if (displayStatus == Status.paid) {
        paid.add(inv);
      } else if (displayStatus != Status.draft) {
        unpaid.add(inv);
        pending = _boundedMoney(pending + inv.balance);
      }
      if (displayStatus == Status.overdue) {
        overdue.add(inv);
        overdueAmount = _boundedMoney(overdueAmount + inv.balance);
      }
    }

    _unpaidView = UnmodifiableListView(unpaid);
    _paidView = UnmodifiableListView(paid);
    _overdueView = UnmodifiableListView(overdue);
    _totalRevenue = revenue;
    _totalPending = pending;
    _totalOverdue = overdueAmount;
    _clientView = UnmodifiableListView(_buildClients());
    _savedItemView = UnmodifiableListView(_savedItems);
    _revision++;
  }

  List<Invoice> get all => _allView;
  List<Invoice> get unpaid => _unpaidView;
  List<Invoice> get paid => _paidView;
  List<Invoice> get overdue => _overdueView;

  double get totalRevenue => _totalRevenue;
  double get totalPending => _totalPending;
  double get totalOverdue => _totalOverdue;
  bool get isLoaded => _loaded;
  int get revision => _revision;

  Future<Invoice> create() async {
    return Invoice(
      id: uid(),
      num: '',
      gst: Prefs.gstNum.value.trim().isEmpty ? 0 : Prefs.defaultGst,
      splitGst: Prefs.splitGst,
      termDays: Prefs.defaultTermDays,
      template: Prefs.defaultTemplate.value,
      status: Status.draft,
    );
  }

  Future<void> add(Invoice inv) async {
    await _ensureInvoiceNumber(inv);
    await DB.saveInvoice(inv);
    final existing = _list.indexWhere((e) => e.id == inv.id);
    if (existing != -1) {
      _list[existing] = inv;
      _rebuildViews();
      return;
    }
    _list.insert(0, inv);
    _rebuildViews();
  }

  Future<void> update(Invoice inv) async {
    await _ensureInvoiceNumber(inv);
    await DB.saveInvoice(inv);
    final x = _list.indexWhere((e) => e.id == inv.id);
    if (x != -1) {
      _list[x] = inv;
    } else {
      _list.insert(0, inv);
    }
    _rebuildViews();
  }

  Future<void> _ensureInvoiceNumber(Invoice inv) async {
    if (inv.status == Status.draft) return;
    final number = inv.num.trim().toLowerCase();
    final duplicate = _list.any(
      (existing) =>
          existing.id != inv.id &&
          number.isNotEmpty &&
          existing.num.trim().toLowerCase() == number,
    );
    if (number.isEmpty || duplicate) {
      inv.num = await DB.nextNum(inv.date);
    }
  }

  Future<void> delete(String id) async {
    await DB.deleteInvoice(id);
    _list.removeWhere((i) => i.id == id);
    _rebuildViews();
  }

  Future<void> restoreBackup({
    required List<Invoice> invoices,
    required List<Customer> clients,
    List<SavedItem> savedItems = const [],
    required Map<String, dynamic> prefs,
  }) async {
    final sortedInvoices = List<Invoice>.from(invoices)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final cleanClients = <Customer>[];
    final seenClients = <String>{};
    for (final c in clients) {
      final clean = Customer(
        name: c.name.trim(),
        email: c.email.trim(),
        phone: c.phone.trim(),
        address: c.address.trim(),
        gstin: c.gstin.trim(),
        state: c.state.trim(),
      );
      final key = clean.name.toLowerCase();
      if (key.isEmpty || seenClients.contains(key)) continue;
      seenClients.add(key);
      cleanClients.add(clean);
    }

    final cleanSavedItems = <SavedItem>[];
    final seenItems = <String>{};
    for (final item in savedItems) {
      final clean = SavedItem(
        desc: item.desc.trim(),
        hsnSac: item.hsnSac.trim(),
        unit: item.unit.trim().isEmpty ? 'Nos' : item.unit.trim(),
        rate: item.rate,
        gstRate: item.gstRate,
      );
      final key = clean.desc.toLowerCase();
      if (key.isEmpty || seenItems.contains(key)) continue;
      seenItems.add(key);
      cleanSavedItems.add(clean);
    }

    await DB.replaceAppData(
      invoices: sortedInvoices,
      clients: cleanClients,
      savedItems: cleanSavedItems,
    );
    _list = sortedInvoices;
    _clients = cleanClients
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    _savedItems = cleanSavedItems;
    _rebuildViews();
    _loaded = true;
    await Prefs.restoreFromMap(prefs);
  }

  List<Invoice> search(String q) {
    final lq = q.toLowerCase();
    return _list
        .where(
          (i) =>
              i.clientDisplay.toLowerCase().contains(lq) ||
              i.num.toLowerCase().contains(lq),
        )
        .toList();
  }

  List<String> get clientNames =>
      _clientView.map((c) => c.name).where((n) => n.isNotEmpty).toList();

  List<Customer> _buildClients() {
    final map = <String, Customer>{};

    void add(Customer c) {
      final key = c.name.trim().toLowerCase();
      if (key.isEmpty) return;
      map.putIfAbsent(
        key,
        () => Customer(
          name: c.name.trim(),
          email: c.email.trim(),
          phone: c.phone.trim(),
          address: c.address.trim(),
          gstin: c.gstin.trim(),
          state: c.state.trim(),
        ),
      );
      final existing = map[key]!;
      if (existing.email.isEmpty) existing.email = c.email.trim();
      if (existing.phone.isEmpty) existing.phone = c.phone.trim();
      if (existing.address.isEmpty) existing.address = c.address.trim();
      if (existing.gstin.isEmpty) existing.gstin = c.gstin.trim();
      if (existing.state.isEmpty) existing.state = c.state.trim();
    }

    for (final c in _clients) {
      add(c);
    }
    for (final inv in _list) {
      add(inv.client);
    }

    final list = map.values.toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return list;
  }

  List<Customer> get clients => _clientView;

  List<SavedItem> get savedItems => _savedItemView;

  Future<void> saveClient(Customer c) async {
    final clean = Customer(
      name: c.name.trim(),
      email: c.email.trim(),
      phone: c.phone.trim(),
      address: c.address.trim(),
      gstin: c.gstin.trim(),
      state: c.state.trim(),
    );
    if (clean.name.isEmpty) return;

    await DB.saveClient(clean);
    final key = clean.name.toLowerCase();
    final x = _clients.indexWhere((e) => e.name.trim().toLowerCase() == key);
    if (x == -1) {
      _clients.add(clean);
    } else {
      _clients[x] = clean;
    }
    _rebuildViews();
  }

  Future<void> updateClient(Customer oldClient, Customer updated) async {
    final clean = Customer(
      name: updated.name.trim(),
      email: updated.email.trim(),
      phone: updated.phone.trim(),
      address: updated.address.trim(),
      gstin: updated.gstin.trim(),
      state: updated.state.trim(),
    );
    if (clean.name.isEmpty) return;

    final oldKey = oldClient.name.trim().toLowerCase();
    final newKey = clean.name.toLowerCase();

    final changedInvoices = <Invoice>[];
    for (final invoice in _list) {
      if (invoice.client.name.trim().toLowerCase() != oldKey) continue;
      final changed = invoice.copy()
        ..client = Customer(
          name: clean.name,
          email: clean.email,
          phone: clean.phone,
          address: clean.address,
          gstin: clean.gstin,
          state: clean.state,
        );
      changedInvoices.add(changed);
    }

    await DB.updateClientAndInvoices(
      oldClient.name.trim(),
      clean,
      changedInvoices,
    );

    if (oldKey.isNotEmpty && oldKey != newKey) {
      _clients.removeWhere((e) => e.name.trim().toLowerCase() == oldKey);
    }

    final x = _clients.indexWhere((e) => e.name.trim().toLowerCase() == newKey);
    if (x == -1) {
      _clients.add(clean);
    } else {
      _clients[x] = clean;
    }
    for (final changed in changedInvoices) {
      final index = _list.indexWhere((invoice) => invoice.id == changed.id);
      if (index != -1) _list[index] = changed;
    }
    _rebuildViews();
  }

  Future<void> deleteClient(Customer client) async {
    final key = client.name.trim().toLowerCase();
    if (key.isEmpty) return;
    await DB.deleteClient(client.name.trim());
    _clients.removeWhere((e) => e.name.trim().toLowerCase() == key);
    _rebuildViews();
  }

  Future<void> saveSavedItem(LineItem item) async {
    final clean = SavedItem(
      desc: item.desc.trim(),
      hsnSac: item.hsnSac.trim(),
      unit: item.unit.trim().isEmpty ? 'Nos' : item.unit.trim(),
      rate: item.rate,
      gstRate: item.gstRate ?? Prefs.defaultGst,
    );
    if (clean.desc.isEmpty) return;
    await DB.saveSavedItem(clean);
    final key = clean.desc.toLowerCase();
    _savedItems.removeWhere((i) => i.desc.trim().toLowerCase() == key);
    _savedItems.insert(0, clean);
    _rebuildViews();
  }
}
