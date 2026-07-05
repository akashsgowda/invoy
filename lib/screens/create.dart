import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme.dart';
import '../models.dart';
import '../widgets.dart';
import '../pdf_builder.dart';
import 'client_form.dart';
import 'pdf_preview_page.dart';

String _pct(double value) {
  if (value == value.roundToDouble()) return value.toStringAsFixed(0);
  return value.toStringAsFixed(1);
}

const _commonUnits = [
  'Nos',
  'Pcs',
  'Kg',
  'Gm',
  'Ltr',
  'Ml',
  'Mtr',
  'Sq ft',
  'Box',
  'Pack',
  'Hour',
  'Day',
  'Service',
];

const _commonGstRates = [0.0, 5.0, 12.0, 18.0, 28.0];

// ════════════════════════════════════════════════════════════════
// CREATE PAGE  —  Quick Invoice
// ════════════════════════════════════════════════════════════════

class CreatePage extends StatefulWidget {
  final Invoice? invoice;
  final bool editing;
  final FutureOr<void> Function(Invoice) onSaved;
  const CreatePage({
    super.key,
    this.invoice,
    this.editing = false,
    required this.onSaved,
  });
  @override
  State<CreatePage> createState() => _CreatePageState();
}

class _CreatePageState extends State<CreatePage> {
  Invoice? _inv;
  late bool _isNew;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _isNew = !widget.editing;
    if (widget.invoice != null) {
      _inv = widget.invoice!.copy();
    } else {
      _loading = true;
      Store.i.create().then((inv) {
        if (mounted) {
          setState(() {
            _inv = inv;
            _loading = false;
          });
        }
      });
    }
  }

  // ── Actions ─────────────────────────────────────────────────

  Future<void> _saveDraft() async {
    if (_inv == null) return;
    _inv!.status = Status.draft;
    await widget.onSaved(_inv!);
    if (!mounted) return;
    Navigator.pop(context, true);
  }

  Future<void> _saveChanges() async {
    if (_inv == null) return;
    if (_inv!.status != Status.draft) {
      final validation = _issueValidationMessage(_inv!);
      if (validation != null) {
        if (Prefs.haptics) HapticFeedback.mediumImpact();
        showAppSnack(context, validation);
        return;
      }
    }
    await widget.onSaved(_inv!);
    if (!mounted) return;
    Navigator.pop(context, true);
  }

  Future<void> _createInvoice() async {
    if (_inv == null) return;
    if (!_isNew) {
      await _saveChanges();
      return;
    }
    final validation = _issueValidationMessage(_inv!);
    if (validation != null) {
      if (Prefs.haptics) HapticFeedback.mediumImpact();
      showAppSnack(context, validation);
      return;
    }
    _inv!.status = Status.pending;
    await widget.onSaved(_inv!);
    for (final item in _inv!.items) {
      await Store.i.saveSavedItem(item);
    }
    if (!mounted) return;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: true,
      builder: (_) => _PostInvoiceSheet(inv: _inv!),
    );
    if (mounted) Navigator.pop(context, true);
  }

  String? _issueValidationMessage(Invoice inv) {
    if (inv.client.name.trim().isEmpty) return 'Add a client first';
    if (inv.items.isEmpty) return 'Add at least one item';
    if (Prefs.gstNum.value.trim().isNotEmpty && inv.gst > 0) {
      final place = inv.placeOfSupply.trim().isNotEmpty
          ? inv.placeOfSupply.trim()
          : inv.client.state.trim();
      if (place.isEmpty) return 'Add place of supply in invoice options';
      if (inv.items.any((i) => i.hsnSac.trim().isEmpty)) {
        return 'Add HSN/SAC for GST items';
      }
    }
    return null;
  }

  Future<void> _openClientPicker() async {
    if (_inv == null) return;
    final c = await Navigator.push<Customer>(
      context,
      slideUpRoute(_ClientPickerPage(selected: _inv!.client)),
    );
    if (!mounted) return;
    if (c != null) {
      setState(() {
        _inv!.client = c;
        if (_inv!.placeOfSupply.trim().isEmpty && c.state.trim().isNotEmpty) {
          _inv!.placeOfSupply = c.state.trim();
        }
      });
    }
  }

  Future<void> _openAddItem() async {
    if (_inv == null) return;
    final item = await Navigator.push<LineItem>(
      context,
      slideUpRoute(_AddItemPage(defaultGst: _inv!.gst)),
    );
    if (item != null) {
      await Store.i.saveSavedItem(item);
      if (!mounted) return;
      setState(() => _inv!.items.add(item));
    }
  }

  Future<void> _openEditItem(LineItem current) async {
    if (_inv == null) return;
    final item = await Navigator.push<LineItem>(
      context,
      slideUpRoute(_AddItemPage(item: current, defaultGst: _inv!.gst)),
    );
    if (item == null) return;
    await Store.i.saveSavedItem(item);
    if (!mounted) return;
    setState(() {
      final index = _inv!.items.indexWhere((i) => i.id == current.id);
      if (index == -1) return;
      _inv!.items[index] = item;
    });
  }

  Future<void> _openMoreOptions() async {
    if (_inv == null) return;
    await Navigator.push(
      context,
      slideUpRoute(
        _MoreOptionsPage(
          inv: _inv!,
          onChanged: () {
            if (mounted) setState(() {});
          },
        ),
      ),
    );
  }

  // ── Build ────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_loading || _inv == null) {
      return Scaffold(
        backgroundColor: T.bg(context),
        body: Center(
          child: CircularProgressIndicator(
            color: T.faint(context),
            strokeWidth: 1.5,
          ),
        ),
      );
    }

    final inv = _inv!;

    return Scaffold(
      backgroundColor: T.bg(context),
      appBar: AppBar(
        backgroundColor: T.bg(context),
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          tooltip: _isNew ? 'Close' : 'Back',
          onPressed: () => Navigator.pop(context),
          icon: Icon(
            _isNew ? Icons.close_rounded : Icons.arrow_back_rounded,
            size: 20,
            color: T.text(context),
          ),
        ),
        title: Text(
          _isNew ? 'Quick Invoice' : 'Edit Invoice',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: T.text(context),
          ),
        ),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.only(top: 18, bottom: 120),
        children: [
          // ── Client ──────────────────────────────────────────
          const _SecLabel('Client'),
          _FlatRow(
            leading:
                inv.client.isEmpty ? _addIcon() : _initAvatar(inv.client.name),
            title: inv.client.isEmpty ? 'Add client' : inv.client.name,
            subtitle: inv.client.isEmpty ? null : inv.client.email,
            onTap: _openClientPicker,
          ),

          const SizedBox(height: 24),

          // ── Items ───────────────────────────────────────────
          const _SecLabel('Items'),
          _FlatRow(leading: _addIcon(), title: 'Add item', onTap: _openAddItem),
          if (inv.items.isNotEmpty)
            ...inv.items.map(
              (item) => _ItemTile(
                item: item,
                onTap: () => _openEditItem(item),
                onDelete: () => setState(
                  () => inv.items.removeWhere((i) => i.id == item.id),
                ),
              ),
            ),

          const SizedBox(height: 24),

          // ── Amount summary ───────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: T.card(context),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: T.border(context), width: 0.5),
              ),
              child: Column(
                children: [
                  _amtRow('Amount due', amtUi(inv.sub), false),
                  if (inv.discountAmount > 0) ...[
                    const SizedBox(height: 8),
                    _amtRow('Discount', '-${amtUi(inv.discountAmount)}', true),
                  ],
                  if (inv.gst > 0) ...[
                    const SizedBox(height: 8),
                    _amtRow(
                      _taxSummaryLabel(inv),
                      amtUi(inv.tax),
                      true,
                    ),
                  ],
                  Divider(height: 20, color: T.divider(context)),
                  _amtRow('Total', amtUi(inv.total), false, bold: true),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // ── More options ─────────────────────────────────────
          _FlatRow(
            title: 'Invoice options',
            subtitle: 'GST, payment terms, PDF style and notes',
            onTap: _openMoreOptions,
          ),
        ],
      ),

      // ── Bottom bar ───────────────────────────────────────────
      bottomNavigationBar:
          _isNew ? _createBottomBar(context) : _editBottomBar(context),
    );
  }

  // ── Helpers ──────────────────────────────────────────────────

  Widget _createBottomBar(BuildContext context) => SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
          color: T.bg(context),
          child: Row(
            children: [
              Expanded(
                child: AppButton(
                  label: 'Save Draft',
                  onTap: _saveDraft,
                  tone: AppButtonTone.secondary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: AppButton(
                  label: 'Create Invoice',
                  onTap: _createInvoice,
                ),
              ),
            ],
          ),
        ),
      );

  Widget _editBottomBar(BuildContext context) => SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
          color: T.bg(context),
          child: SizedBox(
            width: double.infinity,
            child: AppButton(
              label: 'Save Changes',
              onTap: _saveChanges,
            ),
          ),
        ),
      );

  Widget _addIcon() => Container(
        width: 28,
        height: 28,
        alignment: Alignment.center,
        child: Icon(Icons.add_rounded, size: 21, color: T.text(context)),
      );

  Widget _initAvatar(String name) {
    final parts = name.trim().split(' ').where((w) => w.isNotEmpty).toList();
    final initials = parts.isEmpty
        ? '?'
        : parts.length >= 2
            ? '${parts[0][0]}${parts[1][0]}'.toUpperCase()
            : parts[0][0].toUpperCase();
    return CircleAvatar(
      radius: 14,
      backgroundColor: T.subtle(context),
      child: Text(
        initials,
        style: TextStyle(
          color: T.text(context),
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _amtRow(String label, String value, bool sub, {bool bold = false}) =>
      Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: sub ? 12 : 13,
                color: sub ? T.muted(context) : T.text(context),
                fontWeight: bold ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: sub ? 12 : 13,
                color: sub ? T.muted(context) : T.text(context),
                fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
              ),
            ),
          ),
        ],
      );

  String _taxSummaryLabel(Invoice inv) {
    final rates = inv.items
        .map(inv.taxRateFor)
        .where((rate) => rate > 0)
        .map((rate) => rate.toStringAsFixed(3))
        .toSet();
    if (rates.length == 1) {
      final rate = double.parse(rates.first);
      return inv.splitGst
          ? 'Tax (CGST ${_pct(rate / 2)}% + SGST ${_pct(rate / 2)}%)'
          : 'Tax (IGST ${_pct(rate)}%)';
    }
    return inv.splitGst ? 'Tax (GST)' : 'Tax (IGST)';
  }
}

// ── Section label ─────────────────────────────────────────────────

class _SecLabel extends StatelessWidget {
  final String text;
  const _SecLabel(this.text);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: T.muted(context),
            letterSpacing: 0,
          ),
        ),
      );
}

// ── Flat row ──────────────────────────────────────────────────────

class _FlatRow extends StatelessWidget {
  final Widget? leading;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  const _FlatRow({
    this.leading,
    required this.title,
    this.subtitle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: SpringTap(
          onTap: onTap,
          scale: 0.985,
          child: Container(
            constraints: const BoxConstraints(minHeight: 58),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
            decoration: BoxDecoration(
              color: T.card(context),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: T.border(context), width: 0.5),
            ),
            child: Row(
              children: [
                if (leading != null) ...[leading!, const SizedBox(width: 12)],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 14,
                          color: T.text(context),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          subtitle!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:
                              TextStyle(fontSize: 12, color: T.muted(context)),
                        ),
                      ],
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: T.text(context),
                ),
              ],
            ),
          ),
        ),
      );
}

// ── Item tile ─────────────────────────────────────────────────────

class _ItemTile extends StatelessWidget {
  final LineItem item;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  const _ItemTile({
    required this.item,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
        child: SpringTap(
          onTap: onTap,
          scale: 0.985,
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 6, 14),
            decoration: BoxDecoration(
              color: T.card(context),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: T.border(context), width: 0.5),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.desc,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: T.text(context),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${item.qty % 1 == 0 ? item.qty.toInt() : item.qty.toStringAsFixed(1)} ${item.unit} x ${amtUi(item.rate)}'
                        '${item.hsnSac.isEmpty ? '' : ' · HSN ${item.hsnSac}'}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, color: T.muted(context)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 104,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      amtUi(item.total),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: T.text(context),
                      ),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Remove item',
                  onPressed: onDelete,
                  visualDensity: VisualDensity.compact,
                  icon: Icon(
                    Icons.close_rounded,
                    size: 16,
                    color: T.faint(context),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}

// ════════════════════════════════════════════════════════════════
// MORE OPTIONS PAGE
// ════════════════════════════════════════════════════════════════

class _MoreOptionsPage extends StatefulWidget {
  final Invoice inv;
  final VoidCallback onChanged;
  const _MoreOptionsPage({required this.inv, required this.onChanged});
  @override
  State<_MoreOptionsPage> createState() => _MoreOptionsPageState();
}

class _MoreOptionsPageState extends State<_MoreOptionsPage> {
  Invoice get inv => widget.inv;

  String get _gstLabel {
    if (inv.gst == 0) return 'No GST';
    if (inv.splitGst) {
      return '${_pct(inv.gst)}% (CGST ${_pct(inv.gst / 2)}% + SGST ${_pct(inv.gst / 2)}%)';
    }
    return '${_pct(inv.gst)}% IGST';
  }

  String get _taxTypeLabel => inv.splitGst ? 'CGST + SGST' : 'IGST';

  String get _placeLabel {
    final place = inv.placeOfSupply.trim().isNotEmpty
        ? inv.placeOfSupply.trim()
        : inv.client.state.trim();
    return place.isEmpty ? 'Add place of supply' : place;
  }

  String get _termsLabel {
    switch (inv.termDays) {
      case 0:
        return 'Due on receipt';
      case 7:
        return 'Net 7';
      case 14:
        return 'Net 14';
      case 30:
        return 'Net 30';
      case 60:
        return 'Net 60';
      default:
        return 'Net ${inv.termDays}';
    }
  }

  String get _discountLabel {
    if (inv.discountAmount <= 0) return 'No discount';
    if (inv.discountIsPercent) {
      return '${inv.discountValue.toStringAsFixed(inv.discountValue % 1 == 0 ? 0 : 1)}% (${amtUi(inv.discountAmount)})';
    }
    return amtUi(inv.discountAmount);
  }

  Future<void> _pickGst() async {
    final opts = [0.0, 5.0, 12.0, 18.0, 28.0];
    final labels = ['No GST', '5%', '12%', '18%', '28%'];
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => PickSheet(
        title: 'GST Rate',
        items: labels,
        dark: T.dark(context),
        sel: opts.indexWhere((x) => x == inv.gst).clamp(0, 4),
        onSel: (i) {
          final oldGst = inv.gst;
          final nextGst = opts[i];
          setState(() {
            inv.gst = nextGst;
            for (final item in inv.items) {
              final itemRate = item.gstRate;
              final followsOldDefault =
                  itemRate == null || (itemRate - oldGst).abs() < 0.001;
              if (nextGst == 0 || oldGst == 0 || followsOldDefault) {
                item.gstRate = nextGst;
              }
            }
          });
          widget.onChanged();
        },
      ),
    );
  }

  Future<void> _pickTaxType() async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => PickSheet(
        title: 'Tax type',
        items: const ['CGST + SGST', 'IGST'],
        dark: T.dark(context),
        sel: inv.splitGst ? 0 : 1,
        onSel: (i) {
          setState(() => inv.splitGst = i == 0);
          widget.onChanged();
        },
      ),
    );
  }

  Future<void> _editPlaceOfSupply() async {
    final ctrl = TextEditingController(
      text: _placeLabel == 'Add place of supply' ? '' : _placeLabel,
    );
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => EditSheet(
        title: 'Place of supply',
        ctrl: ctrl,
        hint: 'Karnataka',
        dark: T.dark(context),
      ),
    );
    ctrl.dispose();
    if (!mounted) return;
    if (result == null) return;
    setState(() => inv.placeOfSupply = result.trim());
    widget.onChanged();
  }

  Future<void> _pickTerms() async {
    final opts = [0, 7, 14, 30, 60];
    final labels = ['Due on receipt', 'Net 7', 'Net 14', 'Net 30', 'Net 60'];
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => PickSheet(
        title: 'Payment Terms',
        items: labels,
        dark: T.dark(context),
        sel: opts.indexOf(inv.termDays).clamp(0, 4),
        onSel: (i) {
          setState(() => inv.termDays = opts[i]);
          widget.onChanged();
        },
      ),
    );
  }

  Future<void> _pickTpl() async {
    final result = await Navigator.push<String>(
      context,
      slideUpRoute(_TplPicker(sel: inv.template)),
    );
    if (!mounted) return;
    if (result != null) {
      setState(() => inv.template = result);
      widget.onChanged();
    }
  }

  Future<void> _editDiscount() async {
    final result = await showModalBottomSheet<_DiscountResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _DiscountSheet(
        value: inv.discountValue,
        isPercent: inv.discountIsPercent,
      ),
    );
    if (!mounted) return;
    if (result != null) {
      setState(() {
        inv.discountValue = result.value;
        inv.discountIsPercent = result.isPercent;
      });
      widget.onChanged();
    }
  }

  Future<void> _editNotes() async {
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _NotesSheet(initialText: inv.notes),
    );
    if (!mounted) return;
    if (result != null) {
      setState(() => inv.notes = result);
      widget.onChanged();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: T.bg(context),
      appBar: AppBar(
        backgroundColor: T.bg(context),
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          tooltip: 'Close',
          onPressed: () => Navigator.pop(context),
          icon: Icon(Icons.close_rounded, size: 20, color: T.text(context)),
        ),
        title: Text(
          'Invoice Options',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: T.text(context),
          ),
        ),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
        children: [
          // Tax & GST
          _sHeader('Tax & GST'),
          const SizedBox(height: 8),
          _sCard([
            _sRow('GST', _gstLabel, onTap: _pickGst, stacked: true),
            if (inv.gst > 0) ...[
              _sDivider(),
              _sRow('Tax type', _taxTypeLabel, onTap: _pickTaxType),
              _sDivider(),
              _sRow(
                'Place of supply',
                _placeLabel,
                onTap: _editPlaceOfSupply,
                valueIsHint: _placeLabel == 'Add place of supply',
                stacked: true,
              ),
              _sDivider(),
              _sToggle('Reverse charge', inv.reverseCharge, (v) {
                setState(() => inv.reverseCharge = v);
                widget.onChanged();
              }),
            ],
          ]),

          const SizedBox(height: 28),

          // Invoice rules
          _sHeader('Invoice rules'),
          const SizedBox(height: 8),
          _sCard([
            _sRow(
              'Discount',
              _discountLabel,
              onTap: _editDiscount,
              valueIsHint: inv.discountAmount <= 0,
              stacked: true,
            ),
            _sDivider(),
            _sRow('Payment terms', _termsLabel, onTap: _pickTerms),
            _sDivider(),
            _sRow('PDF style', inv.template, onTap: _pickTpl, stacked: true),
          ]),

          const SizedBox(height: 28),

          // Additional
          _sHeader('Optional'),
          const SizedBox(height: 8),
          _sCard([
            _sRow(
              'Notes',
              inv.notes.isEmpty ? 'Add notes or instructions' : inv.notes,
              onTap: _editNotes,
              valueIsHint: inv.notes.isEmpty,
              stacked: true,
            ),
          ]),
        ],
      ),
    );
  }

  Widget _sHeader(String t) => Text(
        t,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: T.muted(context),
          letterSpacing: 0,
        ),
      );

  Widget _sCard(List<Widget> c) => Container(
        decoration: BoxDecoration(
          color: T.card(context),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: T.border(context), width: 0.5),
        ),
        child: Column(children: c),
      );

  Widget _sDivider() =>
      Divider(height: 1, color: T.divider(context), indent: 16, endIndent: 16);

  Widget _sRow(
    String label,
    String value, {
    VoidCallback? onTap,
    bool valueIsHint = false,
    bool stacked = false,
  }) =>
      SpringTap(
        onTap: onTap,
        scale: 0.985,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
          child: Row(
            children: [
              Expanded(
                child: stacked
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            label,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: T.text(context),
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            value,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              color: valueIsHint
                                  ? T.faint(context)
                                  : T.muted(context),
                            ),
                          ),
                        ],
                      )
                    : Text(
                        label,
                        style: TextStyle(fontSize: 14, color: T.text(context)),
                      ),
              ),
              if (!stacked) ...[
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.end,
                    style: TextStyle(
                      fontSize: 13,
                      color: valueIsHint ? T.faint(context) : T.muted(context),
                    ),
                  ),
                ),
              ],
              if (onTap != null) ...[
                const SizedBox(width: 6),
                Icon(Icons.chevron_right_rounded,
                    size: 18, color: T.text(context)),
              ],
            ],
          ),
        ),
      );

  Widget _sToggle(String label, bool value, void Function(bool) on) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Text(label, style: TextStyle(fontSize: 14, color: T.text(context))),
            const Spacer(),
            Switch.adaptive(
              value: value,
              onChanged: on,
              activeThumbColor: T.onInverse(context),
              activeTrackColor: T.inverse(context),
              inactiveThumbColor: T.faint(context),
              inactiveTrackColor: T.border(context),
            ),
          ],
        ),
      );
}

class _DiscountResult {
  final double value;
  final bool isPercent;
  const _DiscountResult(this.value, this.isPercent);
}

class _DiscountSheet extends StatefulWidget {
  final double value;
  final bool isPercent;
  const _DiscountSheet({required this.value, required this.isPercent});

  @override
  State<_DiscountSheet> createState() => _DiscountSheetState();
}

class _DiscountSheetState extends State<_DiscountSheet> {
  late final TextEditingController _ctrl;
  late bool _isPercent;

  @override
  void initState() {
    super.initState();
    _isPercent = widget.isPercent;
    _ctrl = TextEditingController(
      text: widget.value <= 0
          ? ''
          : widget.value.toStringAsFixed(widget.value % 1 == 0 ? 0 : 2),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  double get _value {
    final raw = _ctrl.text.trim().replaceAll(',', '');
    return double.tryParse(raw) ?? 0;
  }

  void _save() {
    final value = _value;
    Navigator.pop(
      context,
      _DiscountResult(value <= 0 ? 0 : value, value <= 0 ? false : _isPercent),
    );
  }

  @override
  Widget build(BuildContext context) => AppSheet(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Discount',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: T.text(context),
              ),
            ),
            const SizedBox(height: 14),
            Container(
              height: 44,
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: T.subtle(context),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: T.border(context), width: 0.5),
              ),
              child: Row(
                children: [
                  _discountMode('Amount', false),
                  _discountMode('Percent', true),
                ],
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _ctrl,
              autofocus: true,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
              ],
              style: TextStyle(color: T.text(context), fontSize: 15),
              decoration: InputDecoration(
                prefixText: _isPercent ? null : '₹ ',
                suffixText: _isPercent ? '%' : null,
                hintText: _isPercent ? '10' : '500',
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: AppButton(
                    label: 'Clear',
                    onTap: () =>
                        Navigator.pop(context, const _DiscountResult(0, false)),
                    tone: AppButtonTone.secondary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: AppButton(
                    label: 'Save Discount',
                    onTap: _save,
                  ),
                ),
              ],
            ),
          ],
        ),
      );

  Widget _discountMode(String label, bool percent) {
    final active = _isPercent == percent;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => setState(() => _isPercent = percent),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: kSmooth,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active ? T.inverse(context) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: active ? T.onInverse(context) : T.faint(context),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Notes sheet ───────────────────────────────────────────────────

class _NotesSheet extends StatefulWidget {
  final String initialText;
  const _NotesSheet({required this.initialText});
  @override
  State<_NotesSheet> createState() => _NotesSheetState();
}

class _NotesSheetState extends State<_NotesSheet> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initialText);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: T.surface(context),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border(top: BorderSide(color: T.border(context), width: 0.5)),
        ),
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 8,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 32,
              height: 3,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: T.border(context),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Notes',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: T.text(context),
                ),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _ctrl,
              autofocus: true,
              maxLines: 4,
              style: TextStyle(color: T.text(context), fontSize: 14),
              decoration: const InputDecoration(
                hintText: 'Payment instructions, thank you note…',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: AppButton(
                label: 'Save',
                onTap: () => Navigator.pop(context, _ctrl.text.trim()),
              ),
            ),
          ],
        ),
      );
}

// ════════════════════════════════════════════════════════════════
// CLIENT PICKER PAGE
// ════════════════════════════════════════════════════════════════

class _ClientPickerPage extends StatefulWidget {
  final Customer selected;
  const _ClientPickerPage({required this.selected});
  @override
  State<_ClientPickerPage> createState() => _ClientPickerPageState();
}

class _ClientPickerPageState extends State<_ClientPickerPage> {
  final _searchC = TextEditingController();
  final _searchFocus = FocusNode();
  String _q = '';
  bool _showAll = false;

  @override
  void initState() {
    super.initState();
    _searchFocus.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _searchFocus.dispose();
    _searchC.dispose();
    super.dispose();
  }

  List<Customer> get _allClients => Store.i.clients;

  List<Customer> get _recentClients {
    final seen = <String>{};
    final result = <Customer>[];
    for (final inv in Store.i.all) {
      final key = inv.client.name.trim().toLowerCase();
      if (key.isNotEmpty && seen.add(key)) {
        result.add(inv.client);
      }
      if (result.length == 3) break;
    }
    return result;
  }

  List<Customer> get _clients {
    final source = _q.isNotEmpty
        ? _allClients
        : _showAll
            ? _allClients
            : _recentClients.isNotEmpty
                ? _recentClients
                : _allClients;
    if (_q.isEmpty) return source;
    final q = _q.toLowerCase();
    return source
        .where(
          (c) =>
              c.name.toLowerCase().contains(q) ||
              c.email.toLowerCase().contains(q),
        )
        .toList();
  }

  Future<void> _addNew() async {
    final c = await Navigator.push<Customer>(
      context,
      slideRoute(const ClientFormPage()),
    );
    if (c == null || c.name.trim().isEmpty) return;
    await Store.i.saveClient(c);
    if (mounted) Navigator.pop(context, c);
  }

  Future<void> _editClient(Customer client) async {
    final updated = await Navigator.push<Customer>(
      context,
      slideRoute(ClientFormPage(client: client)),
    );
    if (updated == null || updated.name.trim().isEmpty) return;
    await Store.i.updateClient(client, updated);
    if (mounted) Navigator.pop(context, updated);
  }

  @override
  Widget build(BuildContext context) {
    final clients = _clients;
    final recent = _recentClients;
    final all = _allClients;
    final sectionTitle = _q.isNotEmpty
        ? 'Results'
        : (_showAll || recent.isEmpty)
            ? 'All clients'
            : 'Recent';

    return Scaffold(
      backgroundColor: T.bg(context),
      appBar: AppBar(
        backgroundColor: T.bg(context),
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          tooltip: 'Close',
          onPressed: () => Navigator.pop(context),
          icon: Icon(Icons.close_rounded, size: 20, color: T.text(context)),
        ),
        title: Text(
          'Select Client',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: T.text(context),
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Add client',
            onPressed: _addNew,
            icon: Icon(Icons.add_rounded, size: 22, color: T.text(context)),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
            child: AppSearchField(
              controller: _searchC,
              focusNode: _searchFocus,
              hint: 'Search clients...',
              onChanged: (v) => setState(() => _q = v),
              onClear: () {
                _searchC.clear();
                setState(() => _q = '');
              },
            ),
          ),

          const SizedBox(height: 24),

          // Clients list
          Expanded(
            child: clients.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.people_outline_rounded,
                          size: 40,
                          color: T.border(context),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _q.isNotEmpty
                              ? 'No clients match "$_q"'
                              : 'No clients yet',
                          style: TextStyle(
                            fontSize: 14,
                            color: T.muted(context),
                          ),
                        ),
                        if (_q.isEmpty) ...[
                          const SizedBox(height: 20),
                          SizedBox(
                            width: 190,
                            child: AppButton(
                              label: 'Add client',
                              icon: Icons.add_rounded,
                              onTap: _addNew,
                            ),
                          ),
                        ],
                      ],
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.only(bottom: 40),
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                        child: Text(
                          sectionTitle,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: T.muted(context),
                            letterSpacing: 0,
                          ),
                        ),
                      ),
                      ...clients.map((c) {
                        final selected = c.name == widget.selected.name;
                        return Padding(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 6),
                          child: SpringTap(
                            onTap: () => Navigator.pop(context, c),
                            scale: 0.985,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 13,
                              ),
                              decoration: BoxDecoration(
                                color: T.card(context),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: selected
                                      ? T.text(context).withValues(alpha: 0.24)
                                      : T
                                          .border(context)
                                          .withValues(alpha: 0.72),
                                  width: 0.6,
                                ),
                              ),
                              child: Row(
                                children: [
                                  _clientAvatar(c.name),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          c.name,
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: T.text(context),
                                          ),
                                        ),
                                        if (c.email.isNotEmpty) ...[
                                          const SizedBox(height: 3),
                                          Text(
                                            c.email,
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: T.muted(context),
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  SpringTap(
                                    onTap: () => _editClient(c),
                                    scale: 0.9,
                                    child: Container(
                                      width: 34,
                                      height: 34,
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        color: T.subtle(context),
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: T.border(context),
                                          width: 0.5,
                                        ),
                                      ),
                                      child: Icon(
                                        Icons.edit_rounded,
                                        size: 16,
                                        color: T.muted(context),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  if (selected)
                                    Container(
                                      width: 22,
                                      height: 22,
                                      decoration: BoxDecoration(
                                        color: T.inverse(context),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        Icons.check_rounded,
                                        size: 13,
                                        color: T.onInverse(context),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }),
                      if (_q.isEmpty &&
                          !_showAll &&
                          all.length > clients.length) ...[
                        SpringTap(
                          onTap: () => setState(() => _showAll = true),
                          scale: 0.985,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 16,
                            ),
                            child: Row(
                              children: [
                                Text(
                                  'View all clients',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: T.text(context),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Icon(
                                  Icons.chevron_right_rounded,
                                  size: 16,
                                  color: T.text(context),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _clientAvatar(String name) {
    final parts = name.trim().split(' ').where((w) => w.isNotEmpty).toList();
    final initials = parts.isEmpty
        ? '?'
        : parts.length >= 2
            ? '${parts[0][0]}${parts[1][0]}'.toUpperCase()
            : parts[0][0].toUpperCase();
    return CircleAvatar(
      radius: 18,
      backgroundColor: T.subtle(context),
      child: Text(
        initials,
        style: TextStyle(
          color: T.text(context),
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// ADD ITEM PAGE
// ════════════════════════════════════════════════════════════════

class _AddItemPage extends StatefulWidget {
  final LineItem? item;
  final double defaultGst;
  const _AddItemPage({this.item, this.defaultGst = 18});
  @override
  State<_AddItemPage> createState() => _AddItemPageState();
}

class _AddItemPageState extends State<_AddItemPage> {
  late final TextEditingController _descC;
  late final TextEditingController _hsnC;
  late final TextEditingController _unitC;
  late final TextEditingController _qtyC;
  late final TextEditingController _rateC;
  late final TextEditingController _gstC;
  late bool _showTaxDetails;
  bool get _editing => widget.item != null;

  @override
  void initState() {
    super.initState();
    final item = widget.item;
    _descC = TextEditingController(text: item?.desc ?? '');
    _hsnC = TextEditingController(text: item?.hsnSac ?? '');
    _unitC = TextEditingController(text: item?.unit ?? 'Nos');
    _qtyC = TextEditingController(text: _numInput(item?.qty ?? 1));
    _rateC = TextEditingController(
      text: item == null || item.rate == 0 ? '' : _numInput(item.rate),
    );
    final gst = item?.gstRate ?? widget.defaultGst;
    _gstC = TextEditingController(text: _numInput(gst));
    _showTaxDetails = (item?.hsnSac.trim().isNotEmpty ?? false) ||
        (Prefs.gstNum.value.trim().isNotEmpty && gst > 0);
  }

  @override
  void dispose() {
    _descC.dispose();
    _hsnC.dispose();
    _unitC.dispose();
    _qtyC.dispose();
    _rateC.dispose();
    _gstC.dispose();
    super.dispose();
  }

  double get _subtotal {
    final q = _numberValue(_qtyC.text);
    final r = _numberValue(_rateC.text);
    return q * r;
  }

  List<SavedItem> get _suggestions {
    final q = _descC.text.trim().toLowerCase();
    final items = Store.i.savedItems;
    if (q.isEmpty) return items.take(4).toList();
    return items
        .where((i) => i.desc.toLowerCase().contains(q))
        .take(4)
        .toList();
  }

  String _numInput(double value) {
    if (value == value.roundToDouble()) return value.toStringAsFixed(0);
    return value.toStringAsFixed(2);
  }

  double _numberValue(String raw, {double fallback = 0}) {
    final parsed = double.tryParse(raw.trim().replaceAll(',', ''));
    if (parsed == null || !parsed.isFinite) return fallback;
    return parsed;
  }

  void _applySaved(SavedItem item) {
    setState(() {
      _descC.text = item.desc;
      _hsnC.text = item.hsnSac;
      _unitC.text = item.unit;
      _rateC.text = item.rate == 0 ? '' : _numInput(item.rate);
      _gstC.text = _numInput(item.gstRate);
      _qtyC.text = '1';
      _showTaxDetails = item.hsnSac.trim().isNotEmpty ||
          (Prefs.gstNum.value.trim().isNotEmpty && item.gstRate > 0);
    });
  }

  String get _unitLabel {
    final value = _unitC.text.trim();
    return value.isEmpty ? 'Nos' : value;
  }

  String get _gstLabel {
    final rate = _numberValue(_gstC.text, fallback: widget.defaultGst);
    return rate <= 0 ? 'No GST' : '${_pct(rate)}%';
  }

  bool _isKnownUnit(String value) {
    final raw = value.trim().toLowerCase();
    return _commonUnits.any((unit) => unit.toLowerCase() == raw);
  }

  bool _isValidUnit(String value) {
    final raw = value.trim();
    if (raw.isEmpty) return true;
    if (_isKnownUnit(raw)) return true;
    return RegExp(r'^[A-Za-z0-9][A-Za-z0-9 /.-]{0,13}$').hasMatch(raw);
  }

  Future<void> _pickUnit() async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _UnitPickerSheet(current: _unitLabel),
    );
    if (!mounted || picked == null) return;

    if (picked == '__custom__') {
      final ctrl = TextEditingController(
        text: _isKnownUnit(_unitLabel) ? '' : _unitLabel,
      );
      final custom = await showModalBottomSheet<String>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => EditSheet(
          title: 'Custom unit',
          ctrl: ctrl,
          hint: 'Bundle',
          dark: T.dark(context),
        ),
      );
      ctrl.dispose();
      if (!mounted || custom == null) return;
      final clean = custom.trim();
      if (!_isValidUnit(clean)) {
        showAppSnack(context, 'Use a short unit like Bundle or Sq ft');
        return;
      }
      setState(() => _unitC.text = clean.isEmpty ? 'Nos' : clean);
      return;
    }

    setState(() => _unitC.text = picked);
  }

  Future<void> _pickItemGst() async {
    final current = _numberValue(_gstC.text, fallback: widget.defaultGst);
    final picked = await showModalBottomSheet<double>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _GstRatePickerSheet(current: current),
    );
    if (!mounted || picked == null) return;

    if (picked == -1) {
      final ctrl = TextEditingController(
        text: _commonGstRates.any((rate) => (rate - current).abs() < 0.001)
            ? ''
            : _numInput(current),
      );
      final custom = await showModalBottomSheet<String>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => EditSheet(
          title: 'Custom GST rate',
          ctrl: ctrl,
          hint: '3',
          dark: T.dark(context),
        ),
      );
      ctrl.dispose();
      if (!mounted || custom == null) return;
      final rate = _numberValue(custom, fallback: -1);
      if (rate < 0 || rate > 100) {
        showAppSnack(context, 'GST rate must be between 0 and 100');
        return;
      }
      setState(() => _gstC.text = _numInput(rate));
      return;
    }

    setState(() => _gstC.text = _numInput(picked));
  }

  @override
  Widget build(BuildContext context) {
    final hasAmount = _subtotal > 0;

    return Scaffold(
      backgroundColor: T.bg(context),
      appBar: AppBar(
        backgroundColor: T.bg(context),
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          tooltip: _editing ? 'Back' : 'Close',
          onPressed: () => Navigator.pop(context),
          icon: Icon(
            _editing ? Icons.arrow_back_rounded : Icons.close_rounded,
            size: 20,
            color: T.text(context),
          ),
        ),
        title: Text(
          _editing ? 'Edit Item' : 'Add Item',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: T.text(context),
          ),
        ),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
        children: [
          if (!_editing && _suggestions.isNotEmpty) ...[
            _fieldLabel('Saved items'),
            const SizedBox(height: 8),
            ..._suggestions.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: SpringTap(
                  onTap: () => _applySaved(item),
                  scale: 0.985,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: T.card(context),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: T.border(context), width: 0.5),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.desc,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: T.text(context),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                '${item.unit} · ${item.gstRate <= 0 ? 'No GST' : '${_pct(item.gstRate)}% GST'}'
                                '${item.hsnSac.isEmpty ? '' : ' · HSN ${item.hsnSac}'}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: T.muted(context),
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          amtUi(item.rate),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: T.text(context),
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          // Item name
          _fieldLabel('Item name'),
          const SizedBox(height: 8),
          TextField(
            controller: _descC,
            autofocus: true,
            style: TextStyle(color: T.text(context), fontSize: 14),
            onChanged: (_) => setState(() {}),
            decoration: _fieldDecoration('e.g. UI/UX Design, Consulting...'),
          ),

          const SizedBox(height: 20),

          // Qty + Rate
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _fieldLabel('Quantity'),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _qtyC,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                      ],
                      style: TextStyle(color: T.text(context), fontSize: 14),
                      onChanged: (_) => setState(() {}),
                      decoration: _fieldDecoration('1'),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _fieldLabel('Unit'),
                    const SizedBox(height: 8),
                    _unitPicker(),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _fieldLabel('Rate (₹)'),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _rateC,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                      ],
                      style: TextStyle(color: T.text(context), fontSize: 14),
                      onChanged: (_) => setState(() {}),
                      decoration: _fieldDecoration('0'),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _fieldLabel('GST rate'),
                    const SizedBox(height: 8),
                    _gstPicker(),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),
          _taxDetailsBlock(),

          if (hasAmount) ...[
            const SizedBox(height: 20),
            _fieldLabel('Amount'),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: T.card(context),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: T.border(context), width: 0.5),
              ),
              child: Text(
                amtUi(_subtotal),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: T.text(context),
                  letterSpacing: 0,
                ),
              ),
            ),
          ],
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: AppButton(
            label: _editing ? 'Save Item' : 'Add Item',
            onTap: () {
              if (_descC.text.trim().isEmpty) {
                showAppSnack(context, 'Enter an item name');
                return;
              }
              final q = _numberValue(_qtyC.text, fallback: 1);
              final r = _numberValue(_rateC.text);
              final gst = _numberValue(_gstC.text, fallback: widget.defaultGst);
              if (q <= 0) {
                showAppSnack(context, 'Quantity must be above zero');
                return;
              }
              if (r < 0) {
                showAppSnack(context, 'Rate cannot be negative');
                return;
              }
              if (gst < 0 || gst > 100) {
                showAppSnack(context, 'GST rate must be between 0 and 100');
                return;
              }
              if (!_isValidUnit(_unitC.text)) {
                showAppSnack(
                    context, 'Choose a unit or use a short custom one');
                return;
              }
              Navigator.pop(
                context,
                LineItem(
                  id: widget.item?.id ?? uid(),
                  desc: _descC.text.trim(),
                  hsnSac: _hsnC.text.trim(),
                  unit: _unitLabel,
                  qty: q,
                  rate: r,
                  gstRate: gst,
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _unitPicker() => SpringTap(
        onTap: _pickUnit,
        scale: 0.975,
        child: Container(
          height: 52,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: T.card(context),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: T.border(context), width: 0.5),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  _unitLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: T.text(context),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0,
                  ),
                ),
              ),
              Icon(Icons.expand_more_rounded,
                  color: T.faint(context), size: 18),
            ],
          ),
        ),
      );

  Widget _gstPicker() => SpringTap(
        onTap: _pickItemGst,
        scale: 0.975,
        child: Container(
          height: 52,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: T.card(context),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: T.border(context), width: 0.5),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  _gstLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: T.text(context),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0,
                  ),
                ),
              ),
              Icon(Icons.expand_more_rounded,
                  color: T.faint(context), size: 18),
            ],
          ),
        ),
      );

  Widget _taxDetailsBlock() {
    final hasHsn = _hsnC.text.trim().isNotEmpty;
    final shouldNudge = Prefs.gstNum.value.trim().isNotEmpty &&
        _numberValue(_gstC.text, fallback: widget.defaultGst) > 0;

    return Container(
      decoration: BoxDecoration(
        color: T.card(context),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: T.border(context), width: 0.5),
      ),
      child: Column(
        children: [
          SpringTap(
            onTap: () => setState(() => _showTaxDetails = !_showTaxDetails),
            scale: 0.985,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Tax details',
                          style: TextStyle(
                            color: T.text(context),
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          hasHsn
                              ? 'HSN/SAC ${_hsnC.text.trim()}'
                              : shouldNudge
                                  ? 'HSN/SAC for GST invoices'
                                  : 'Optional HSN/SAC code',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:
                              TextStyle(color: T.muted(context), fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    _showTaxDetails
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: T.faint(context),
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
          if (_showTaxDetails) ...[
            Divider(height: 1, color: T.border(context)),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _fieldLabel('HSN/SAC'),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _hsnC,
                    keyboardType: TextInputType.text,
                    textCapitalization: TextCapitalization.characters,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
                      LengthLimitingTextInputFormatter(8),
                    ],
                    style: TextStyle(color: T.text(context), fontSize: 14),
                    onChanged: (_) => setState(() {}),
                    decoration: _fieldDecoration('9983'),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Use HSN for goods, SAC for services. Leave blank if this is not a GST invoice.',
                    style: TextStyle(
                      color: T.muted(context),
                      fontSize: 11,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _fieldLabel(String t) => Text(
        t,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: T.muted(context),
          letterSpacing: 0,
        ),
      );

  InputDecoration _fieldDecoration(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: T.faint(context), fontSize: 14),
        filled: true,
        fillColor: T.card(context),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(22),
          borderSide: BorderSide(color: T.border(context), width: 0.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(22),
          borderSide: BorderSide(color: T.border(context), width: 0.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(22),
          borderSide: BorderSide(
            color: T.accent(context).withValues(alpha: 0.26),
            width: 1,
          ),
        ),
      );
}

class _UnitPickerSheet extends StatelessWidget {
  final String current;
  const _UnitPickerSheet({required this.current});

  @override
  Widget build(BuildContext context) {
    final currentLower = current.trim().toLowerCase();
    final isCustom = currentLower.isNotEmpty &&
        !_commonUnits.any((unit) => unit.toLowerCase() == currentLower);

    return AppSheet(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Unit',
            style: TextStyle(
              color: T.text(context),
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Pick how this item is measured.',
            style: TextStyle(color: T.muted(context), fontSize: 12),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ..._commonUnits.map(
                (unit) => _unitChoice(
                  context,
                  label: unit,
                  selected: unit.toLowerCase() == currentLower,
                  value: unit,
                ),
              ),
              _unitChoice(
                context,
                label: isCustom ? current : 'Custom',
                selected: isCustom,
                value: '__custom__',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _unitChoice(
    BuildContext context, {
    required String label,
    required bool selected,
    required String value,
  }) =>
      SpringTap(
        onTap: () => Navigator.pop(context, value),
        scale: 0.965,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            color: selected ? T.inverse(context) : T.card(context),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected ? T.inverse(context) : T.border(context),
              width: 0.5,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? T.onInverse(context) : T.text(context),
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 0,
            ),
          ),
        ),
      );
}

class _GstRatePickerSheet extends StatelessWidget {
  final double current;
  const _GstRatePickerSheet({required this.current});

  @override
  Widget build(BuildContext context) {
    final isCustom =
        !_commonGstRates.any((rate) => (rate - current).abs() < 0.001);

    return AppSheet(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'GST rate',
            style: TextStyle(
              color: T.text(context),
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Use the common slab unless this item needs a special rate.',
            style: TextStyle(color: T.muted(context), fontSize: 12),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ..._commonGstRates.map(
                (rate) => _rateChoice(
                  context,
                  label: rate <= 0 ? 'No GST' : '${_pct(rate)}%',
                  selected: (rate - current).abs() < 0.001,
                  value: rate,
                ),
              ),
              _rateChoice(
                context,
                label: isCustom ? '${_pct(current)}%' : 'Custom',
                selected: isCustom,
                value: -1,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _rateChoice(
    BuildContext context, {
    required String label,
    required bool selected,
    required double value,
  }) =>
      SpringTap(
        onTap: () => Navigator.pop(context, value),
        scale: 0.965,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            color: selected ? T.inverse(context) : T.card(context),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected ? T.inverse(context) : T.border(context),
              width: 0.5,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? T.onInverse(context) : T.text(context),
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 0,
            ),
          ),
        ),
      );
}

// ════════════════════════════════════════════════════════════════
// TEMPLATE PICKER
// ════════════════════════════════════════════════════════════════

class _TplPicker extends StatefulWidget {
  final String sel;
  const _TplPicker({required this.sel});
  @override
  State<_TplPicker> createState() => _TplPickerState();
}

class _TplPickerState extends State<_TplPicker> {
  late String _sel;
  @override
  void initState() {
    super.initState();
    _sel = widget.sel;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: T.bg(context),
      appBar: AppBar(
        backgroundColor: T.bg(context),
        leading: IconButton(
          tooltip: 'Close',
          onPressed: () => Navigator.pop(context),
          icon: Icon(Icons.close_rounded, size: 20, color: T.text(context)),
        ),
        title: Text(
          'PDF Style',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: T.text(context),
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
              itemCount: kTemplates.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, i) {
                final t = kTemplates[i];
                final active = _sel == t.name;
                return GestureDetector(
                  onTap: () => setState(() => _sel = t.name),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    curve: kSmooth,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: T.card(context),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: active ? T.inverse(context) : T.border(context),
                        width: active ? 1.0 : 0.5,
                      ),
                    ),
                    child: Row(
                      children: [
                        _MiniTemplatePreview(tpl: t),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                t.name,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: T.text(context),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                t.description,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: T.muted(context),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (active)
                          Icon(
                            Icons.check_rounded,
                            size: 18,
                            color: T.text(context),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: SafeArea(
              top: false,
              child: SizedBox(
                width: double.infinity,
                child: AppButton(
                  label: 'Use This Style',
                  onTap: () => Navigator.pop(context, _sel),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniTemplatePreview extends StatelessWidget {
  final InvTemplate tpl;
  const _MiniTemplatePreview({required this.tpl});

  @override
  Widget build(BuildContext context) => Container(
        width: 44,
        height: 54,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: T.border(context), width: 0.5),
        ),
        clipBehavior: Clip.antiAlias,
        child: CustomPaint(painter: _MiniTemplatePainter(tpl)),
      );
}

class _MiniTemplatePainter extends CustomPainter {
  final InvTemplate tpl;
  const _MiniTemplatePainter(this.tpl);

  @override
  void paint(Canvas canvas, Size size) {
    final ink = Paint()..color = const Color(0xFF111111);
    final primary = Paint()..color = tpl.primary;
    final accent = Paint()..color = tpl.accent;
    final soft = Paint()..color = const Color(0xFFE5E7EB);
    final mid = Paint()..color = const Color(0xFF9CA3AF);

    RRect rr(double x, double y, double w, double h, double r) =>
        RRect.fromRectAndRadius(Rect.fromLTWH(x, y, w, h), Radius.circular(r));

    void bar(double x, double y, double w, {Paint? paint, double h = 2}) {
      canvas.drawRRect(rr(x, y, w, h, h / 2), paint ?? soft);
    }

    switch (tpl.name) {
      case 'Minimal':
        bar(6, 8, 14, paint: primary, h: 3);
        bar(6, 16, 28);
        bar(6, 23, 22);
        canvas.drawLine(
          const Offset(6, 31),
          Offset(size.width - 6, 31),
          mid..strokeWidth = 0.8,
        );
        bar(size.width - 22, 45, 16, paint: primary, h: 3);
        break;
      case 'Ledger':
        canvas.drawRRect(rr(5, 6, size.width - 10, 13, 4), primary);
        bar(9, 10, 14, paint: Paint()..color = Colors.white, h: 2);
        bar(
          size.width - 19,
          10,
          10,
          paint: Paint()..color = Colors.white,
          h: 2,
        );
        canvas.drawRRect(rr(6, 25, 10, 7, 3), accent);
        canvas.drawRRect(rr(19, 25, 10, 7, 3), accent);
        canvas.drawRRect(rr(32, 25, 7, 7, 3), accent);
        for (final y in [39.0, 45.0, 50.0]) {
          canvas.drawLine(Offset(6, y), Offset(size.width - 6, y), mid);
        }
        break;
      case 'Compact':
        canvas.drawRRect(
          rr(11, 4, size.width - 22, size.height - 8, 2),
          Paint()..color = Colors.white,
        );
        canvas.drawRRect(
          rr(11, 4, size.width - 22, size.height - 8, 2),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 0.8
            ..color = const Color(0xFFE5E7EB),
        );
        bar(15, 10, 14, paint: ink, h: 2.4);
        for (final x in [15.0, 23.0, 31.0]) {
          bar(x, 20, 4, paint: primary, h: 1.2);
        }
        bar(15, 29, 15, paint: primary, h: 3);
        for (final y in [39.0, 45.0, 50.0]) {
          bar(15, y, 15, paint: soft, h: 1.3);
        }
        break;
      default:
        canvas.drawRect(Rect.fromLTWH(0, 0, size.width, 12), ink);
        bar(6, 19, 18, paint: ink, h: 3);
        bar(6, 29, 32);
        bar(6, 37, 32);
        canvas.drawRRect(rr(6, 45, 32, 5, 2), soft);
    }
  }

  @override
  bool shouldRepaint(_MiniTemplatePainter oldDelegate) =>
      oldDelegate.tpl != tpl;
}

// ════════════════════════════════════════════════════════════════
// POST-INVOICE SHEET
// ════════════════════════════════════════════════════════════════

class _PostInvoiceSheet extends StatefulWidget {
  final Invoice inv;
  const _PostInvoiceSheet({required this.inv});
  @override
  State<_PostInvoiceSheet> createState() => _PostInvoiceSheetState();
}

class _PostInvoiceSheetState extends State<_PostInvoiceSheet>
    with SingleTickerProviderStateMixin {
  late AnimationController _ac;
  late Animation<double> _checkScale, _contentFade;
  late Animation<Offset> _contentSlide;
  bool _sharing = false;

  @override
  void initState() {
    super.initState();
    _ac = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _checkScale = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _ac,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOutCubic),
      ),
    );
    _contentFade = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _ac,
        curve: const Interval(0.3, 0.7, curve: Curves.easeOut),
      ),
    );
    _contentSlide =
        Tween(begin: const Offset(0, 0.06), end: Offset.zero).animate(
      CurvedAnimation(
        parent: _ac,
        curve: const Interval(0.3, 0.8, curve: kSmooth),
      ),
    );
    _ac.forward();
  }

  @override
  void dispose() {
    _ac.dispose();
    super.dispose();
  }

  Future<void> _share() async {
    if (_sharing) return;
    setState(() => _sharing = true);
    try {
      await sharePdf(widget.inv);
    } catch (_) {
      if (!mounted) return;
      showAppSnack(context, 'Could not open share sheet');
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  Future<void> _pdf() async {
    if (!mounted) return;
    await Navigator.push(
      context,
      slideRoute(PdfPreviewPage(invoice: widget.inv)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final inv = widget.inv;
    return Container(
      decoration: BoxDecoration(
        color: T.surface(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(top: BorderSide(color: T.border(context), width: 0.5)),
      ),
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 8,
        bottom: MediaQuery.of(context).viewInsets.bottom + 32,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 32,
            height: 3,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: T.border(context),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          ScaleTransition(
            scale: _checkScale,
            child: Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                color: T.inverse(context),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.check_rounded,
                color: T.onInverse(context),
                size: 32,
              ),
            ),
          ),
          const SizedBox(height: 16),
          FadeTransition(
            opacity: _contentFade,
            child: SlideTransition(
              position: _contentSlide,
              child: Column(
                children: [
                  Text(
                    'Invoice created',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: T.text(context),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${inv.num}  ·  ${inv.client.name.isNotEmpty ? inv.client.name : "No client"}',
                    style: TextStyle(fontSize: 13, color: T.muted(context)),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: T.card(context),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: T.border(context), width: 0.5),
                    ),
                    child: Column(
                      children: [
                        _pRow(
                          'Items',
                          inv.items.length == 1
                              ? inv.items[0].desc
                              : '${inv.items.length} items',
                        ),
                        const SizedBox(height: 6),
                        _pRow(
                          'Due in',
                          inv.termDays == 0 ? 'Today' : '${inv.termDays}d',
                        ),
                        Divider(height: 16, color: T.divider(context)),
                        Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: Text(
                                'Total',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: T.text(context),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 2,
                              child: Text(
                                amtUi(inv.total),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.right,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: T.text(context),
                                  letterSpacing: 0,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: AppButton(
                      label: 'Share invoice',
                      icon: Icons.share_rounded,
                      loading: _sharing,
                      onTap: _sharing ? null : _share,
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: AppButton(
                      label: 'Preview PDF',
                      icon: Icons.visibility_outlined,
                      onTap: _pdf,
                      tone: AppButtonTone.secondary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: AppButton(
                      label: 'Done',
                      onTap: () => Navigator.pop(context),
                      tone: AppButtonTone.ghost,
                      height: 46,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _pRow(String l, String v) => Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              l,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: T.muted(context)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 3,
            child: Text(
              v,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: T.text(context),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      );
}
