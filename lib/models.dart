import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'theme.dart';

String uid() => DateTime.now().microsecondsSinceEpoch.toString();

enum PayMode { upi, bank, cash, cheque }

enum Status { draft, pending, paid, overdue }

class Customer {
  String name, email, phone, address, gstin;
  Customer({
    this.name = '',
    this.email = '',
    this.phone = '',
    this.address = '',
    this.gstin = '',
  });
  bool get isEmpty => name.isEmpty;

  Map<String, dynamic> toMap() => {
        'name': name,
        'email': email,
        'phone': phone,
        'address': address,
        'gstin': gstin,
      };

  factory Customer.fromMap(Map<String, dynamic> m) => Customer(
        name: m['name'] ?? '',
        email: m['email'] ?? '',
        phone: m['phone'] ?? '',
        address: m['address'] ?? '',
        gstin: m['gstin'] ?? '',
      );
}

class LineItem {
  final String id;
  String desc;
  double qty, rate;

  LineItem({required this.id, this.desc = '', this.qty = 1, this.rate = 0});
  double get total => qty * rate;

  Map<String, dynamic> toMap() =>
      {'id': id, 'desc': desc, 'qty': qty, 'rate': rate};

  factory LineItem.fromMap(Map<String, dynamic> m) => LineItem(
        id: m['id'] ?? uid(),
        desc: m['desc'] ?? '',
        qty: m['qty'] != null ? double.parse(m['qty'].toString()) : 1.0,
        rate: m['rate'] != null ? double.parse(m['rate'].toString()) : 0.0,
      );
}

class Payment {
  final double amount;
  final DateTime date;
  final PayMode mode;
  Payment({required this.amount, required this.date, required this.mode});

  Map<String, dynamic> toMap() => {
        'amount': amount,
        'date': date.millisecondsSinceEpoch,
        'mode': mode.name,
      };

  factory Payment.fromMap(Map<String, dynamic> m) => Payment(
        amount:
            m['amount'] != null ? double.parse(m['amount'].toString()) : 0.0,
        date: DateTime.fromMillisecondsSinceEpoch(m['date'] as int),
        mode: PayMode.values
            .firstWhere((e) => e.name == m['mode'], orElse: () => PayMode.upi),
      );
}

class Invoice {
  final String id;
  String num, template, notes;
  Customer client;
  List<LineItem> items;
  List<Payment> payments;
  DateTime date;
  int termDays;
  double gst;
  double discountValue;
  bool discountIsPercent;
  bool splitGst;
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
    this.status = Status.draft,
    this.template = 'Classic',
    this.notes = '',
    DateTime? createdAt,
  })  : client = client ?? Customer(),
        items = items ?? [],
        payments = payments ?? [],
        date = date ?? DateTime.now(),
        createdAt = createdAt ?? DateTime.now();

  double get sub => items.fold(0, (s, i) => s + i.total);
  double get discountAmount {
    if (discountValue <= 0 || sub <= 0) return 0;
    final raw = discountIsPercent ? sub * (discountValue / 100) : discountValue;
    return raw.clamp(0, sub).toDouble();
  }

  double get taxableSub {
    final amount = sub - discountAmount;
    return amount > 0 ? amount : 0;
  }

  double get tax => taxableSub * (gst / 100);
  double get cgst => tax / 2;
  double get sgst => tax / 2;
  double get total => taxableSub + tax;
  double get paidAmt => payments.fold(0, (s, p) => s + p.amount);
  bool get hasPayment => paidAmt > 0;
  bool get isPartPaid => items.isNotEmpty && hasPayment && balance > 0;
  double get collectedAmt {
    if (payments.isNotEmpty) {
      return paidAmt > total ? total : paidAmt;
    }
    return status == Status.paid ? total : 0;
  }

  double get balance {
    final due = total - paidAmt;
    return due > 0 ? due : 0;
  }

  DateTime get due => date.add(Duration(days: termDays));

  bool get isOverdue {
    if ((status == Status.paid && !isPartPaid) ||
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
    if (items.isNotEmpty && balance <= 0) return Status.paid;
    if (status == Status.paid && payments.isEmpty) return Status.paid;
    if (isOverdue) return Status.overdue;
    if (status == Status.draft) return Status.draft;
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
        ),
        items: items
            .map((i) =>
                LineItem(id: uid(), desc: i.desc, qty: i.qty, rate: i.rate))
            .toList(),
        termDays: termDays,
        gst: gst,
        discountValue: discountValue,
        discountIsPercent: discountIsPercent,
        splitGst: splitGst,
        status: Status.draft,
        template: template,
        notes: notes,
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
        'items': jsonEncode(items.map((i) => i.toMap()).toList()),
        'payments': jsonEncode(payments.map((p) => p.toMap()).toList()),
        'invoiceDate': date.millisecondsSinceEpoch,
        'termDays': termDays,
        'gst': gst,
        'discountValue': discountValue,
        'discountIsPercent': discountIsPercent ? 1 : 0,
        'splitGst': splitGst ? 1 : 0,
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
      ),
      items: itemsRaw
          .map((e) => LineItem.fromMap(e as Map<String, dynamic>))
          .toList(),
      payments: paysRaw
          .map((e) => Payment.fromMap(e as Map<String, dynamic>))
          .toList(),
      date: DateTime.fromMillisecondsSinceEpoch(m['invoiceDate'] as int),
      termDays: m['termDays'] as int? ?? 30,
      gst: m['gst'] != null ? double.parse(m['gst'].toString()) : 18.0,
      discountValue: m['discountValue'] != null
          ? double.parse(m['discountValue'].toString())
          : 0.0,
      discountIsPercent: (m['discountIsPercent'] as int?) == 1,
      splitGst: (m['splitGst'] as int?) == 1,
      status: Status.values
          .firstWhere((e) => e.name == m['status'], orElse: () => Status.draft),
      createdAt: DateTime.fromMillisecondsSinceEpoch(m['createdAt'] as int),
    );
  }
}

class DB {
  static late Database instance;
  static int _ctr = 0;

  static Future<void> init() async {
    final dbPath = await getDatabasesPath();
    instance = await openDatabase(
      p.join(dbPath, 'invoy_v2.db'),
      version: 3,
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
            items TEXT, payments TEXT,
            invoiceDate INTEGER, termDays INTEGER, gst REAL,
            discountValue REAL, discountIsPercent INTEGER,
            splitGst INTEGER, status TEXT, createdAt INTEGER
          )
        ''');
        await db.execute('''
          CREATE TABLE counter (id INTEGER PRIMARY KEY, val INTEGER)
        ''');
        await db.insert('counter', {'id': 1, 'val': 0});
        await _createClientsTable(db);
      },
      onUpgrade: (db, oldVersion, _) async {
        if (oldVersion < 2) {
          await _createClientsTable(db);
        }
        if (oldVersion < 3) {
          await _addColumnIfMissing(
              db, 'invoices', 'discountValue', 'REAL DEFAULT 0');
          await _addColumnIfMissing(
              db, 'invoices', 'discountIsPercent', 'INTEGER DEFAULT 0');
        }
      },
    );
    final row = await instance.query('counter', where: 'id = 1');
    _ctr = row.isNotEmpty ? row.first['val'] as int : 0;
  }

  static Future<void> _createClientsTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS clients (
        name TEXT PRIMARY KEY,
        email TEXT,
        phone TEXT,
        address TEXT,
        gstin TEXT,
        createdAt INTEGER
      )
    ''');
  }

  static Future<void> _addColumnIfMissing(
      Database db, String table, String column, String definition) async {
    final rows = await db.rawQuery('PRAGMA table_info($table)');
    final exists = rows.any((row) => row['name'] == column);
    if (!exists) {
      await db.execute('ALTER TABLE $table ADD COLUMN $column $definition');
    }
  }

  static Future<String> nextNum() async {
    _ctr++;
    await instance.update('counter', {'val': _ctr}, where: 'id = 1');
    final prefix = Prefs.invPrefix.value;
    final year = DateTime.now().year;
    return '$prefix-$year-${_ctr.toString().padLeft(3, '0')}';
  }

  static Future<void> saveInvoice(Invoice inv) async {
    await instance.insert('invoices', inv.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  static Future<void> deleteInvoice(String id) async {
    await instance.delete('invoices', where: 'id = ?', whereArgs: [id]);
  }

  static Future<void> replaceInvoices(List<Invoice> invoices) async {
    await instance.transaction((txn) async {
      await txn.delete('invoices');
      for (final inv in invoices) {
        await txn.insert('invoices', inv.toMap(),
            conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }

  static Future<List<Invoice>> loadAll() async {
    final rows = await instance.query('invoices', orderBy: 'createdAt DESC');
    return rows.map(Invoice.fromMap).toList();
  }

  static Future<void> saveClient(Customer c) async {
    await instance.insert(
        'clients',
        {
          'name': c.name,
          'email': c.email,
          'phone': c.phone,
          'address': c.address,
          'gstin': c.gstin,
          'createdAt': DateTime.now().millisecondsSinceEpoch,
        },
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  static Future<void> deleteClient(String name) async {
    await instance.delete('clients', where: 'name = ?', whereArgs: [name]);
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
            'createdAt': DateTime.now().millisecondsSinceEpoch,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  static Future<void> resetCounterFromInvoices(List<Invoice> invoices) async {
    var maxCounter = 0;
    final numberEnd = RegExp(r'(\d+)$');
    for (final inv in invoices) {
      final match = numberEnd.firstMatch(inv.num);
      if (match == null) continue;
      final value = int.tryParse(match.group(1) ?? '');
      if (value != null && value > maxCounter) {
        maxCounter = value;
      }
    }
    _ctr = maxCounter;
    await instance.insert('counter', {'id': 1, 'val': _ctr},
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  static Future<List<Customer>> loadClients() async {
    final rows =
        await instance.query('clients', orderBy: 'name COLLATE NOCASE');
    return rows
        .map((m) => Customer(
              name: m['name'] as String? ?? '',
              email: m['email'] as String? ?? '',
              phone: m['phone'] as String? ?? '',
              address: m['address'] as String? ?? '',
              gstin: m['gstin'] as String? ?? '',
            ))
        .where((c) => c.name.trim().isNotEmpty)
        .toList();
  }
}

class Prefs {
  static final themeMode = ValueNotifier<ThemeMode>(ThemeMode.light);
  static final onboarded = ValueNotifier<bool>(false);
  static final yourName = ValueNotifier<String>('');
  static final bizName = ValueNotifier<String>('');
  static final gstNum = ValueNotifier<String>('');
  static final upiId = ValueNotifier<String>('');
  static final upiQrImage = ValueNotifier<String>('');
  static final upiQrImageName = ValueNotifier<String>('');
  static final invPrefix = ValueNotifier<String>('INV');
  static final defaultTemplate = ValueNotifier<String>('Classic');
  static final lastBackupAt = ValueNotifier<String>('');
  static bool showUpiQr = true;
  static bool splitGst = true;
  static int defaultTermDays = 30;
  static double defaultGst = 18.0;

  static Future<void> load() async {
    final rows = await DB.instance.query('prefs');
    final map = {for (final r in rows) r['key'] as String: r['val'] as String};

    yourName.value = map['yourName'] ?? '';
    bizName.value = map['bizName'] ?? '';
    gstNum.value = map['gstNum'] ?? '';
    upiId.value = map['upiId'] ?? '';
    upiQrImage.value = map['upiQrImage'] ?? '';
    upiQrImageName.value = map['upiQrImageName'] ?? '';
    invPrefix.value = map['invPrefix'] ?? 'INV';
    defaultTemplate.value = map['defaultTemplate'] ?? 'Classic';
    lastBackupAt.value = map['lastBackupAt'] ?? '';
    showUpiQr = (map['showUpiQr'] ?? '1') == '1';
    splitGst = (map['splitGst'] ?? '1') == '1';
    defaultTermDays = int.tryParse(map['defaultTermDays'] ?? '30') ?? 30;
    defaultGst = double.tryParse(map['defaultGst'] ?? '18') ?? 18.0;
    onboarded.value = (map['onboarded'] ?? '0') == '1';

    final tm = map['themeMode'] ?? 'light';
    themeMode.value = tm == 'dark'
        ? ThemeMode.dark
        : tm == 'system'
            ? ThemeMode.system
            : ThemeMode.light;
  }

  static Future<void> _save(String key, String val) async {
    await DB.instance.insert('prefs', {'key': key, 'val': val},
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  static Future<void> setOnboarded(
      String name, String biz, String gst, String upi) async {
    yourName.value = name;
    bizName.value = biz;
    gstNum.value = gst;
    upiId.value = upi;
    onboarded.value = true;
    await _save('yourName', name);
    await _save('bizName', biz);
    await _save('gstNum', gst);
    await _save('upiId', upi);
    await _save('onboarded', '1');
  }

  static Future<void> update(String key, String val) async {
    switch (key) {
      case 'yourName':
        yourName.value = val;
        break;
      case 'bizName':
        bizName.value = val;
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

    Future<void> saveText(String key, ValueNotifier<String> notifier,
        {String? fallback}) async {
      final value = text(key) ?? fallback;
      if (value == null) return;
      notifier.value = value;
      await _save(key, value);
    }

    await saveText('yourName', yourName, fallback: yourName.value);
    await saveText('bizName', bizName, fallback: bizName.value);
    await saveText('gstNum', gstNum, fallback: gstNum.value);
    await saveText('upiId', upiId, fallback: upiId.value);
    await saveText('upiQrImage', upiQrImage, fallback: upiQrImage.value);
    await saveText('upiQrImageName', upiQrImageName,
        fallback: upiQrImageName.value);
    await saveText('invPrefix', invPrefix, fallback: invPrefix.value);
    await saveText('defaultTemplate', defaultTemplate,
        fallback: defaultTemplate.value);
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

    final terms = intValue('defaultTermDays');
    if (terms != null) {
      defaultTermDays = terms;
      await _save('defaultTermDays', '$terms');
    }

    final gst = doubleValue('defaultGst');
    if (gst != null) {
      defaultGst = gst;
      await _save('defaultGst', '$gst');
    }

    final onboard = boolValue('onboarded');
    if (onboard != null) {
      onboarded.value = onboard;
      await _save('onboarded', onboard ? '1' : '0');
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
                : 'light');
  }

  static Future<void> setSplitGst(bool v) async {
    splitGst = v;
    await _save('splitGst', v ? '1' : '0');
  }

  static Future<void> setShowUpiQr(bool v) async {
    showUpiQr = v;
    await _save('showUpiQr', v ? '1' : '0');
  }

  static Future<void> setUpiQrImage(String data, String name) async {
    upiQrImage.value = data;
    upiQrImageName.value = name;
    await _save('upiQrImage', data);
    await _save('upiQrImageName', name);
  }

  static Future<void> setDefaultTermDays(int v) async {
    defaultTermDays = v;
    await _save('defaultTermDays', '$v');
  }

  static Future<void> setDefaultGst(double v) async {
    defaultGst = v;
    await _save('defaultGst', '$v');
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
  bool _loaded = false;

  Future<void> load() async {
    if (_loaded) return;
    _list = await DB.loadAll();
    _clients = await DB.loadClients();
    _loaded = true;
  }

  List<Invoice> get all => List.unmodifiable(_list);
  List<Invoice> get unpaid =>
      _list.where((i) => i.displayStatus != Status.paid).toList();
  List<Invoice> get paid =>
      _list.where((i) => i.displayStatus == Status.paid).toList();
  List<Invoice> get overdue => _list.where((i) => i.isOverdue).toList();

  double get totalRevenue => _list.fold(0, (s, i) => s + i.collectedAmt);
  double get totalPending => unpaid.fold(0, (s, i) => s + i.balance);
  double get totalOverdue => overdue.fold(0, (s, i) => s + i.balance);

  Future<Invoice> create() async {
    final newNum = await DB.nextNum();
    return Invoice(
      id: uid(),
      num: newNum,
      gst: Prefs.defaultGst,
      splitGst: Prefs.splitGst,
      termDays: Prefs.defaultTermDays,
      template: Prefs.defaultTemplate.value,
      status: Status.draft,
    );
  }

  Future<void> add(Invoice inv) async {
    final existing = _list.indexWhere((e) => e.id == inv.id);
    if (existing != -1) {
      _list[existing] = inv;
      await DB.saveInvoice(inv);
      return;
    }
    _list.insert(0, inv);
    await DB.saveInvoice(inv);
  }

  Future<void> update(Invoice inv) async {
    final x = _list.indexWhere((e) => e.id == inv.id);
    if (x != -1) _list[x] = inv;
    await DB.saveInvoice(inv);
  }

  Future<void> delete(String id) async {
    _list.removeWhere((i) => i.id == id);
    await DB.deleteInvoice(id);
  }

  Future<void> restoreBackup({
    required List<Invoice> invoices,
    required List<Customer> clients,
    required Map<String, dynamic> prefs,
  }) async {
    await Prefs.restoreFromMap(prefs);
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
      );
      final key = clean.name.toLowerCase();
      if (key.isEmpty || seenClients.contains(key)) continue;
      seenClients.add(key);
      cleanClients.add(clean);
    }

    await DB.replaceInvoices(sortedInvoices);
    await DB.replaceClients(cleanClients);
    await DB.resetCounterFromInvoices(sortedInvoices);
    _list = sortedInvoices;
    _clients = cleanClients
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    _loaded = true;
  }

  Future<void> markPaid(String id) async {
    final x = _list.indexWhere((i) => i.id == id);
    if (x == -1) return;
    final remaining = _list[x].balance;
    if (_list[x].items.isEmpty || remaining <= 0) return;
    if (remaining > 0) {
      _list[x].payments.add(
          Payment(amount: remaining, date: DateTime.now(), mode: PayMode.upi));
    }
    _list[x].status = Status.paid;
    await DB.saveInvoice(_list[x]);
  }

  Future<void> markUnpaid(String id) async {
    final x = _list.indexWhere((i) => i.id == id);
    if (x == -1) return;
    _list[x].payments.clear();
    _list[x].status = Status.pending;
    await DB.saveInvoice(_list[x]);
  }

  List<Invoice> search(String q) {
    final lq = q.toLowerCase();
    return _list
        .where((i) =>
            i.clientDisplay.toLowerCase().contains(lq) ||
            i.num.toLowerCase().contains(lq))
        .toList();
  }

  List<String> get clientNames =>
      clients.map((c) => c.name).where((n) => n.isNotEmpty).toSet().toList()
        ..sort();

  List<Customer> get clients {
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
              ));
      final existing = map[key]!;
      if (existing.email.isEmpty) existing.email = c.email.trim();
      if (existing.phone.isEmpty) existing.phone = c.phone.trim();
      if (existing.address.isEmpty) existing.address = c.address.trim();
      if (existing.gstin.isEmpty) existing.gstin = c.gstin.trim();
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

  Future<void> saveClient(Customer c) async {
    final clean = Customer(
      name: c.name.trim(),
      email: c.email.trim(),
      phone: c.phone.trim(),
      address: c.address.trim(),
      gstin: c.gstin.trim(),
    );
    if (clean.name.isEmpty) return;

    final key = clean.name.toLowerCase();
    final x = _clients.indexWhere((e) => e.name.trim().toLowerCase() == key);
    if (x == -1) {
      _clients.add(clean);
    } else {
      _clients[x] = clean;
    }
    await DB.saveClient(clean);
  }

  Future<void> updateClient(Customer oldClient, Customer updated) async {
    final clean = Customer(
      name: updated.name.trim(),
      email: updated.email.trim(),
      phone: updated.phone.trim(),
      address: updated.address.trim(),
      gstin: updated.gstin.trim(),
    );
    if (clean.name.isEmpty) return;

    final oldKey = oldClient.name.trim().toLowerCase();
    final newKey = clean.name.toLowerCase();

    if (oldKey.isNotEmpty && oldKey != newKey) {
      _clients.removeWhere((e) => e.name.trim().toLowerCase() == oldKey);
      await DB.deleteClient(oldClient.name.trim());
    }

    final x = _clients.indexWhere((e) => e.name.trim().toLowerCase() == newKey);
    if (x == -1) {
      _clients.add(clean);
    } else {
      _clients[x] = clean;
    }
    await DB.saveClient(clean);

    for (final inv in _list) {
      if (inv.client.name.trim().toLowerCase() == oldKey) {
        inv.client = Customer(
          name: clean.name,
          email: clean.email,
          phone: clean.phone,
          address: clean.address,
          gstin: clean.gstin,
        );
        await DB.saveInvoice(inv);
      }
    }
  }
}
