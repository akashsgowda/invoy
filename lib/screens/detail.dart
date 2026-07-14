import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import '../theme.dart';
import '../models.dart';
import '../widgets.dart';
import '../pdf_builder.dart';
import 'create.dart';
import 'pdf_preview_page.dart';

String _pct(double value) {
  if (value == value.roundToDouble()) return value.toStringAsFixed(0);
  return value.toStringAsFixed(1);
}

class DetailPage extends StatefulWidget {
  final Invoice invoice;
  final VoidCallback onRefresh;
  const DetailPage({super.key, required this.invoice, required this.onRefresh});

  @override
  State<DetailPage> createState() => _DetailPageState();
}

class _DetailPageState extends State<DetailPage> {
  late Invoice _inv;
  bool _sharing = false;
  bool _previewing = false;
  bool _updating = false;

  @override
  void initState() {
    super.initState();
    _inv = widget.invoice;
  }

  void _r() {
    if (!mounted) return;
    widget.onRefresh();
    setState(() {});
  }

  Future<void> _shareInvoice() async {
    if (_sharing) return;
    setState(() => _sharing = true);
    try {
      if (!mounted) return;
      _snack('Preparing share sheet');
      await sharePdf(_inv);
    } catch (_) {
      if (!mounted) return;
      _snack('Could not open share sheet');
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  Future<void> _shareReceipt() async {
    if (_inv.payments.isEmpty) {
      _snack('No payments recorded');
      return;
    }
    try {
      _snack('Preparing receipt');
      await shareReceiptPdf(_inv);
    } catch (_) {
      if (!mounted) return;
      _snack('Could not open share sheet');
    }
  }

  Future<void> _pdf() async {
    if (_previewing) return;
    setState(() => _previewing = true);
    try {
      await Navigator.push(context, slideRoute(PdfPreviewPage(invoice: _inv)));
    } finally {
      if (mounted) setState(() => _previewing = false);
    }
  }

  Future<void> _shareReminder() async {
    if (_inv.balance <= 0) {
      _snack('No balance due');
      return;
    }
    try {
      await Share.share(paymentReminderMessage(_inv));
    } catch (_) {
      if (!mounted) return;
      _snack('Could not open share sheet');
    }
  }

  Future<void> _dup() async {
    if (_updating) return;
    setState(() => _updating = true);
    try {
      final draft = _inv.duplicate(uid(), '');
      await Store.i.add(draft);
      if (!mounted) return;
      _r();
      final messenger = ScaffoldMessenger.of(context);
      final snack = appSnackBar(context, 'Draft duplicated');
      Navigator.pop(context);
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(snack);
    } catch (_) {
      if (mounted) _snack("Couldn't duplicate this invoice");
    } finally {
      if (mounted) setState(() => _updating = false);
    }
  }

  Future<void> _markPaid() async {
    if (_updating || _inv.items.isEmpty || _inv.balance <= 0) {
      _snack('No balance due');
      return;
    }
    final payment = await showModalBottomSheet<Payment>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => PaySheet(
        remaining: _inv.balance,
        dark: T.dark(context),
        fullPayment: true,
      ),
    );
    if (!mounted || payment == null) return;
    await _savePayment(payment, fullPayment: true);
  }

  Future<void> _editInvoice() async {
    Invoice? saved;
    final changed = await Navigator.push<bool>(
      context,
      slideRoute(
        CreatePage(
          invoice: _inv,
          editing: true,
          onSaved: (invoice) async {
            await Store.i.update(invoice);
            saved = invoice;
          },
        ),
      ),
    );
    if (!mounted) return;
    if (changed == true && saved != null) {
      _inv = saved!;
      _r();
    }
  }

  Future<void> _markUnpaid() async {
    if (_updating) return;
    if (_inv.payments.isNotEmpty) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: T.card(context),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            'Clear payments?',
            style: TextStyle(
              color: T.text(context),
              fontWeight: FontWeight.w700,
              fontSize: 17,
            ),
          ),
          content: Text(
            'This removes the recorded payment history and marks the invoice unpaid.',
            style: TextStyle(color: T.muted(context), fontSize: 13),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Cancel', style: TextStyle(color: T.muted(context))),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(
                'Clear',
                style: TextStyle(
                  color: T.text(context),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      );
      if (!mounted) return;
      if (confirm != true) return;
    }
    final oldPayments = _inv.payments.map((entry) => entry.copy()).toList();
    final oldStatus = _inv.status;
    setState(() {
      _updating = true;
      _inv.payments.clear();
      _inv.status = Status.pending;
    });
    try {
      await Store.i.update(_inv);
      if (!mounted) return;
      _r();
      if (Prefs.haptics) HapticFeedback.selectionClick();
      _snack('Marked as unpaid');
    } catch (_) {
      _inv.payments = oldPayments;
      _inv.status = oldStatus;
      if (mounted) _snack("Couldn't update this invoice");
    } finally {
      if (mounted) setState(() => _updating = false);
    }
  }

  Future<void> _deleteInvoice() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: T.card(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Delete invoice?',
          style: TextStyle(
            color: T.text(context),
            fontWeight: FontWeight.w700,
            fontSize: 17,
          ),
        ),
        content: Text(
          'This permanently removes ${_inv.num.isEmpty ? 'this invoice' : _inv.num}.',
          style: TextStyle(color: T.muted(context), fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: TextStyle(color: T.muted(context))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Delete',
              style: TextStyle(color: C.overdue, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (confirm != true) return;
    try {
      await Store.i.delete(_inv.id);
      if (!mounted) return;
      _r();
      Navigator.pop(context);
    } catch (_) {
      if (mounted) _snack("Couldn't delete this invoice");
    }
  }

  Future<void> _recordPayment() async {
    if (_updating || _inv.items.isEmpty || _inv.balance <= 0) {
      _snack('No balance due');
      return;
    }
    final p = await showModalBottomSheet<Payment>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => PaySheet(remaining: _inv.balance, dark: T.dark(context)),
    );
    if (!mounted || p == null) return;
    await _savePayment(p, fullPayment: false);
  }

  Future<void> _savePayment(
    Payment payment, {
    required bool fullPayment,
  }) async {
    if (_updating) return;
    final oldPayments = _inv.payments.map((entry) => entry.copy()).toList();
    final oldStatus = _inv.status;
    setState(() {
      _updating = true;
      _inv.payments.add(payment);
      if (_inv.balance <= 0) _inv.status = Status.paid;
    });
    try {
      await Store.i.update(_inv);
      if (!mounted) return;
      _r();
      if (_inv.displayStatus == Status.paid) {
        if (Prefs.haptics) HapticFeedback.mediumImpact();
        await _showDone('Marked paid');
      } else {
        _snack(fullPayment ? 'Payment recorded' : 'Partial payment recorded');
      }
    } catch (_) {
      _inv.payments = oldPayments;
      _inv.status = oldStatus;
      if (mounted) _snack("Couldn't record this payment");
    } finally {
      if (mounted) setState(() => _updating = false);
    }
  }

  void _snack(String msg) => showAppSnack(context, msg);

  String _taxBreakupLabel(String label) {
    final rates = _inv.items
        .map(_inv.taxRateFor)
        .where((rate) => rate > 0)
        .map((rate) => rate.toStringAsFixed(3))
        .toSet();
    if (rates.length != 1) return label;
    final rate = double.parse(rates.first);
    final shown = label == 'IGST' ? rate : rate / 2;
    return '$label (${_pct(shown)}%)';
  }

  Future<void> _copyValue(String label, String value) async {
    final clean = value.trim();
    if (clean.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: clean));
    if (!mounted) return;
    _snack('$label copied');
  }

  Future<void> _openSettleInvoice() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => AppSheet(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Settle invoice',
              style: TextStyle(
                color: T.text(context),
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Balance due ${amtUi(_inv.balance)}',
              style: TextStyle(color: T.muted(context), fontSize: 13),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: AppButton(
                label: 'Mark as paid',
                icon: Icons.check_circle_outline_rounded,
                onTap: () async {
                  Navigator.pop(sheetContext);
                  await Future<void>.delayed(const Duration(milliseconds: 80));
                  if (!mounted) return;
                  await _markPaid();
                },
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: AppButton(
                label: 'Record partial payment',
                tone: AppButtonTone.ghost,
                height: 46,
                onTap: () async {
                  Navigator.pop(sheetContext);
                  await Future<void>.delayed(const Duration(milliseconds: 80));
                  if (!mounted) return;
                  await _recordPayment();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showDone(String title) async {
    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierLabel: title,
      barrierColor: Colors.black.withValues(alpha: 0.18),
      transitionDuration: Prefs.reduceMotion
          ? Duration.zero
          : const Duration(milliseconds: 160),
      pageBuilder: (_, __, ___) => _DonePulse(title: title),
      transitionBuilder: (_, animation, __, child) => FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isPaid = _inv.displayStatus == Status.paid;
    final canCollect = !isPaid &&
        _inv.displayStatus != Status.draft &&
        _inv.items.isNotEmpty &&
        _inv.balance > 0;

    return Scaffold(
      backgroundColor: T.bg(context),
      appBar: AppBar(
        backgroundColor: T.bg(context),
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          tooltip: 'Back',
          onPressed: () => Navigator.pop(context),
          icon: Icon(
            Icons.arrow_back_rounded,
            size: 18,
            color: T.text(context),
          ),
        ),
        title: Tooltip(
          message: _inv.num.trim().isEmpty
              ? 'Draft invoice'
              : 'Tap to copy invoice number',
          child: GestureDetector(
            onTap: _inv.num.trim().isEmpty
                ? null
                : () => _copyValue('Invoice number', _inv.num),
            child: Text(
              _inv.displayNumber,
              style: TextStyle(
                color: T.faint(context),
                fontSize: 13,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
        ),
        centerTitle: false,
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Invoice actions',
            icon: Icon(
              Icons.more_horiz_rounded,
              color: T.muted(context),
              size: 20,
            ),
            color: T.card(context),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            onSelected: (v) async {
              if (v == 'edit') {
                await _editInvoice();
              }
              if (v == 'dup') await _dup();
              if (v == 'remind') await _shareReminder();
              if (v == 'receipt') await _shareReceipt();
              if (v == 'unpaid') await _markUnpaid();
              if (v == 'del') await _deleteInvoice();
            },
            itemBuilder: (_) => [
              _menuItem('edit', Icons.edit_outlined, 'Edit', T.text(context)),
              _menuItem(
                'dup',
                Icons.copy_outlined,
                'Duplicate',
                T.text(context),
              ),
              if (canCollect)
                _menuItem(
                  'remind',
                  Icons.chat_bubble_outline_rounded,
                  'Send Reminder',
                  T.text(context),
                ),
              if (_inv.payments.isNotEmpty)
                _menuItem(
                  'receipt',
                  Icons.payments_outlined,
                  'Share Receipt',
                  T.text(context),
                ),
              if (isPaid || _inv.payments.isNotEmpty)
                _menuItem(
                  'unpaid',
                  Icons.undo_rounded,
                  _inv.payments.isNotEmpty
                      ? 'Clear Payments'
                      : 'Mark as Unpaid',
                  T.text(context),
                ),
              _menuItem('del', Icons.delete_outline, 'Delete', C.overdue),
            ],
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          // ── Flat header ──
          SliverToBoxAdapter(
            child: Container(
              color: T.bg(context),
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    amtUi(_inv.total),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: T.text(context),
                      fontSize: 36,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      StatusPill(inv: _inv),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _inv.dueDateText,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:
                              TextStyle(color: T.faint(context), fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // ── Content ──
          SliverToBoxAdapter(
            child: Container(
              decoration: BoxDecoration(
                color: T.surface(context),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
                border: Border(
                  top: BorderSide(color: T.border(context), width: 0.5),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                child: Column(
                  children: [
                    // Customer
                    _section('Customer', [
                      if (_inv.client.name.isNotEmpty)
                        _row('Name', _inv.client.name, copyable: true),
                      if (_inv.client.email.isNotEmpty)
                        _row('Email', _inv.client.email, copyable: true),
                      if (_inv.client.phone.isNotEmpty)
                        _row('Phone', _inv.client.phone, copyable: true),
                      if (_inv.client.address.isNotEmpty)
                        _row('Address', _inv.client.address, copyable: true),
                      if (_inv.client.gstin.isNotEmpty)
                        _row('GSTIN', _inv.client.gstin, copyable: true),
                      if (_inv.client.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          child: Text(
                            'No customer added',
                            style: TextStyle(
                              color: T.faint(context),
                              fontSize: 13,
                            ),
                          ),
                        ),
                    ]),
                    const SizedBox(height: 2),

                    // Details
                    _section('Details', [
                      _row('Invoice Date', fDate(_inv.date)),
                      _row('Due Date', fDate(_inv.due)),
                      _row(
                        'Terms',
                        _inv.termDays == 0
                            ? 'Due on receipt'
                            : 'Net ${_inv.termDays}',
                      ),
                      _row('Template', _inv.template),
                      if (_inv.gst > 0)
                        _row(
                          'Tax type',
                          _inv.splitGst ? 'CGST + SGST' : 'IGST',
                        ),
                      if (_inv.gst > 0 &&
                          (_inv.placeOfSupply.isNotEmpty ||
                              _inv.client.state.isNotEmpty))
                        _row(
                          'Place of supply',
                          _inv.placeOfSupply.isNotEmpty
                              ? _inv.placeOfSupply
                              : _inv.client.state,
                        ),
                      if (_inv.gst > 0)
                        _row(
                          'Reverse charge',
                          _inv.reverseCharge ? 'Yes' : 'No',
                        ),
                    ]),
                    const SizedBox(height: 2),

                    // Items
                    if (_inv.items.isNotEmpty) ...[
                      _section(
                        'Items',
                        _inv.items
                            .map(
                              (item) => Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            item.desc,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w500,
                                              color: T.text(context),
                                            ),
                                          ),
                                          const SizedBox(height: 3),
                                          Text(
                                            () {
                                              final rate = _inv.taxRateFor(
                                                item,
                                              );
                                              final taxText = rate <= 0
                                                  ? 'No GST'
                                                  : 'GST ${_pct(rate)}%';
                                              return '${item.qty % 1 == 0 ? item.qty.toInt() : item.qty.toStringAsFixed(1)} ${item.unit} x ${amtUi(item.rate)}'
                                                  '${item.hsnSac.isEmpty ? '' : ' · HSN ${item.hsnSac}'}'
                                                  ' · $taxText';
                                            }(),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: T.faint(context),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    SizedBox(
                                      width: 112,
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
                                  ],
                                ),
                              ),
                            )
                            .toList(),
                      ),
                      const SizedBox(height: 2),
                    ],

                    // Totals
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      child: Column(
                        children: [
                          _totalRow('Subtotal', amtUi(_inv.sub), sub: true),
                          if (_inv.discountAmount > 0) ...[
                            const SizedBox(height: 8),
                            _totalRow(
                              'Discount',
                              '-${amtUi(_inv.discountAmount)}',
                              sub: true,
                            ),
                          ],
                          if (_inv.splitGst && _inv.gst > 0) ...[
                            const SizedBox(height: 8),
                            _totalRow(
                              _taxBreakupLabel('CGST'),
                              amtUi(_inv.cgst),
                              sub: true,
                            ),
                            const SizedBox(height: 6),
                            _totalRow(
                              _taxBreakupLabel('SGST'),
                              amtUi(_inv.sgst),
                              sub: true,
                            ),
                          ] else if (_inv.gst > 0) ...[
                            const SizedBox(height: 8),
                            _totalRow(
                              _taxBreakupLabel('IGST'),
                              amtUi(_inv.igst),
                              sub: true,
                            ),
                          ],
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            child: Divider(
                              height: 1,
                              color: T.divider(context),
                            ),
                          ),
                          _totalRow('Total', amtUi(_inv.total), bold: true),
                          if (_inv.paidAmt > 0 && _inv.balance > 0) ...[
                            const SizedBox(height: 10),
                            _totalRow(
                              'Paid',
                              amtUi(_inv.paidAmt),
                              valueColor: C.paid,
                            ),
                            const SizedBox(height: 10),
                            _totalRow(
                              'Balance Due',
                              amtUi(_inv.balance),
                              valueColor: C.overdue,
                              bold: true,
                            ),
                          ],
                        ],
                      ),
                    ),

                    // Notes
                    if (_inv.notes.isNotEmpty) ...[
                      _section('Notes', [
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          child: Text(
                            _inv.notes,
                            style: TextStyle(
                              fontSize: 13,
                              color: T.muted(context),
                              height: 1.6,
                            ),
                          ),
                        ),
                      ]),
                      const SizedBox(height: 2),
                    ],

                    // Payment history
                    if (_inv.payments.isNotEmpty) ...[
                      _section('Payment history', [_paymentHistoryCard()]),
                    ],

                    const SizedBox(height: 120),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _bottomBar(isPaid),
    );
  }

  // ── Bottom bar ───────────────────────────────────────────────

  Widget _bottomBar(bool isPaid) {
    final isDraft = _inv.displayStatus == Status.draft;
    final canCollect =
        !isPaid && !isDraft && _inv.items.isNotEmpty && _inv.balance > 0;
    return Container(
      color: T.surface(context),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isDraft) ...[
                SizedBox(
                  width: double.infinity,
                  child: AppButton(
                    label: 'Continue Draft',
                    onTap: _updating ? null : _editInvoice,
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: _bottomOutlineButton(
                    icon: Icons.visibility_outlined,
                    label: 'Preview Draft',
                    onPressed: _pdf,
                  ),
                ),
              ] else ...[
                SizedBox(
                  width: double.infinity,
                  child: AppButton(
                    label: 'Share invoice',
                    icon: Icons.share_rounded,
                    onTap: _sharing ? null : _shareInvoice,
                    loading: _sharing,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _bottomOutlineButton(
                        icon: Icons.visibility_outlined,
                        label: 'Preview PDF',
                        onPressed: _pdf,
                      ),
                    ),
                    if (canCollect) ...[
                      const SizedBox(width: 10),
                      Expanded(
                        child: _bottomOutlineButton(
                          icon: Icons.account_balance_wallet_outlined,
                          label: 'Settle invoice',
                          onPressed: _openSettleInvoice,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ── Helpers ──────────────────────────────────────────────────

  Widget _bottomOutlineButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) =>
      AppButton(
        label: label,
        icon: icon,
        onTap: onPressed,
        tone: AppButtonTone.secondary,
        height: 50,
      );

  Widget _paymentHistoryCard() => Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
        decoration: BoxDecoration(
          color: T.card(context),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: T.border(context), width: 0.5),
        ),
        child: Column(
          children: [
            _paymentMetricRow('Paid so far', amtUi(_inv.paidAmt)),
            if (_inv.balance > 0) ...[
              const SizedBox(height: 8),
              _paymentMetricRow('Balance due', amtUi(_inv.balance),
                  strong: true),
            ],
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Divider(height: 1, color: T.divider(context)),
            ),
            ..._inv.payments.asMap().entries.map(
                  (entry) => Column(
                    children: [
                      _paymentRow(entry.value),
                      if (entry.key != _inv.payments.length - 1)
                        Divider(height: 1, color: T.divider(context)),
                    ],
                  ),
                ),
          ],
        ),
      );

  Widget _paymentMetricRow(String label, String value, {bool strong = false}) =>
      Row(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: strong ? 14 : 13,
              fontWeight: strong ? FontWeight.w700 : FontWeight.w500,
              color: strong ? T.text(context) : T.muted(context),
            ),
          ),
          const Spacer(),
          Flexible(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: strong ? 15 : 13,
                fontWeight: strong ? FontWeight.w800 : FontWeight.w600,
                color: T.text(context),
              ),
            ),
          ),
        ],
      );

  Widget _section(String title, List<Widget> children) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              title.toUpperCase(),
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: T.faint(context),
                letterSpacing: 0.8,
              ),
            ),
          ),
          ...children.map(
            (c) => Column(
              children: [
                c,
                if (c != children.last)
                  Divider(height: 1, color: T.divider(context)),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
      );

  Widget _row(String l, String v, {bool copyable = false}) {
    final value = Text(
      v,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      textAlign: TextAlign.right,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: T.text(context),
      ),
    );
    final valueWidget = copyable
        ? Tooltip(
            message: 'Tap to copy $l',
            child: SpringTap(
              onTap: () => _copyValue(l, v),
              scale: 0.985,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Flexible(child: value),
                    const SizedBox(width: 6),
                    Icon(Icons.copy_rounded, size: 12, color: T.faint(context)),
                  ],
                ),
              ),
            ),
          )
        : value;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              l,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 13, color: T.faint(context)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(flex: 3, child: valueWidget),
        ],
      ),
    );
  }

  Widget _totalRow(
    String l,
    String v, {
    bool sub = false,
    bool bold = false,
    Color? valueColor,
  }) =>
      Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              l,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: sub ? 12 : 14,
                color: sub ? T.faint(context) : T.muted(context),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: Text(
              v,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: sub ? 12 : 14,
                fontWeight: bold ? FontWeight.w600 : FontWeight.w400,
                color: valueColor ?? (sub ? T.faint(context) : T.text(context)),
              ),
            ),
          ),
        ],
      );

  Widget _paymentRow(Payment p) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _paymentModeLabel(p.mode),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: T.text(context),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    fDate(p.date),
                    style: TextStyle(fontSize: 11, color: T.faint(context)),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 126,
              child: Text(
                amtUi(p.amount),
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
          ],
        ),
      );

  String _paymentModeLabel(PayMode mode) => switch (mode) {
        PayMode.upi => 'UPI payment',
        PayMode.bank => 'Bank transfer',
        PayMode.cash => 'Cash payment',
        PayMode.cheque => 'Cheque payment',
      };

  PopupMenuItem<String> _menuItem(
    String v,
    IconData icon,
    String label,
    Color color,
  ) =>
      PopupMenuItem(
        value: v,
        child: Row(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 10),
            Text(label, style: TextStyle(fontSize: 14, color: color)),
          ],
        ),
      );
}

String paymentReminderMessage(Invoice inv) {
  final client =
      inv.client.name.trim().isEmpty ? 'there' : inv.client.name.trim();
  final sender = Prefs.bizName.value.trim().isNotEmpty
      ? Prefs.bizName.value.trim()
      : Prefs.yourName.value.trim();
  final signoff = sender.isEmpty ? 'Thank you.' : 'Thank you,\n$sender';
  return 'Hi $client,\n\n'
      'This is a reminder for invoice ${inv.displayNumber}.\n'
      'Balance due: ${amt(inv.balance)}\n'
      'Due date: ${fDate(inv.due)}\n\n'
      'Please share an update when convenient.\n\n'
      '$signoff';
}

class _DonePulse extends StatefulWidget {
  final String title;
  const _DonePulse({required this.title});

  @override
  State<_DonePulse> createState() => _DonePulseState();
}

class _DonePulseState extends State<_DonePulse> {
  @override
  void initState() {
    super.initState();
    Future.delayed(
      Prefs.reduceMotion ? Duration.zero : const Duration(milliseconds: 900),
      () {
        if (mounted) Navigator.of(context).pop();
      },
    );
  }

  @override
  Widget build(BuildContext context) => Center(
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: Prefs.reduceMotion ? 1.0 : 0.76, end: 1),
          duration: Prefs.reduceMotion
              ? Duration.zero
              : const Duration(milliseconds: 260),
          curve: kSmooth,
          builder: (_, scale, child) =>
              Transform.scale(scale: scale, child: child),
          child: Material(
            color: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.fromLTRB(22, 20, 22, 18),
              decoration: BoxDecoration(
                color: T.card(context),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: T.border(context), width: 0.5),
                boxShadow: T.shadow(context),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: T.inverse(context),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.check_rounded,
                      color: T.onInverse(context),
                      size: 28,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    widget.title,
                    style: TextStyle(
                      color: T.text(context),
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}
