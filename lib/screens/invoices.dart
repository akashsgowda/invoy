import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import '../theme.dart';
import '../models.dart';
import '../widgets.dart';
import 'create.dart';
import 'detail.dart';

enum _InvoiceSort { newest, dueSoon, amountHigh, client }

class InvoicesPage extends StatefulWidget {
  final VoidCallback onRefresh;
  final int initialTab;
  const InvoicesPage({super.key, required this.onRefresh, this.initialTab = 0});
  @override
  State<InvoicesPage> createState() => _InvoicesPageState();
}

class _InvoicesPageState extends State<InvoicesPage> {
  late int _tab;
  _InvoiceSort _sort = _InvoiceSort.newest;
  bool _searching = false;
  String _q = '';
  final _sc = TextEditingController();
  final _searchFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _tab = widget.initialTab.clamp(0, 3);
    _searchFocus.addListener(() => setState(() {}));
  }

  @override
  void didUpdateWidget(covariant InvoicesPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialTab != oldWidget.initialTab) {
      _tab = widget.initialTab.clamp(0, 3);
    }
  }

  @override
  void dispose() {
    _searchFocus.dispose();
    _sc.dispose();
    super.dispose();
  }

  void _r() {
    widget.onRefresh();
    setState(() {});
  }

  Future<void> _del(String id) async {
    await Store.i.delete(id);
    _r();
  }

  List<Invoice> _sorted(List<Invoice> source) {
    final list = List<Invoice>.from(source);
    switch (_sort) {
      case _InvoiceSort.newest:
        list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
      case _InvoiceSort.dueSoon:
        list.sort((a, b) => a.due.compareTo(b.due));
        break;
      case _InvoiceSort.amountHigh:
        double amount(Invoice inv) => inv.isPartPaid ? inv.balance : inv.total;
        list.sort((a, b) => amount(b).compareTo(amount(a)));
        break;
      case _InvoiceSort.client:
        list.sort((a, b) => a.clientDisplay
            .toLowerCase()
            .compareTo(b.clientDisplay.toLowerCase()));
        break;
    }
    return list;
  }

  void _openSort() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => PickSheet(
        title: 'Sort invoices',
        items: const [
          'Newest first',
          'Due soon',
          'Highest amount',
          'Client A-Z'
        ],
        sel: _sort.index,
        dark: T.dark(context),
        onSel: (i) => setState(() => _sort = _InvoiceSort.values[i]),
      ),
    );
  }

  void _open(Invoice inv) => Navigator.push(
        context,
        slideRoute(DetailPage(invoice: inv, onRefresh: _r)),
      ).then((_) => _r());

  void _newInvoice() {
    Store.i.create().then((inv) {
      if (!mounted) return;
      Navigator.push(
          context,
          slideRoute(CreatePage(
            invoice: inv,
            onSaved: (v) async {
              await Store.i.add(v);
              _r();
            },
          ))).then((_) => _r());
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: T.bg(context),
      body: SafeArea(
        child: Column(children: [
          // ── Top bar ──
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 16, 0),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: _searching ? _searchBar() : _topRow(),
            ),
          ),

          const SizedBox(height: 16),

          // ── Tabs ──
          if (!_searching) _tabs(),

          const SizedBox(height: 12),

          // ── List ──
          Expanded(
            child: _searching
                ? _buildList(Store.i.search(_q), 'No results', false)
                : _currentList(),
          ),
        ]),
      ),
    );
  }

  // ── Top row ──────────────────────────────────────────────────

  Widget _topRow() => Row(key: const ValueKey('title'), children: [
        Text('Invoices',
            style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w700,
                color: T.text(context),
                letterSpacing: 0)),
        const Spacer(),
        _iconBtn(Icons.sort_rounded, _openSort,
            tooltip: 'Sort invoices', active: _sort != _InvoiceSort.newest),
        const SizedBox(width: 8),
        _iconBtn(Icons.search_rounded, () => setState(() => _searching = true),
            tooltip: 'Search invoices'),
      ]);

  Widget _searchBar() => Row(key: const ValueKey('search'), children: [
        Expanded(
            child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: kSmooth,
          height: 48,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: _searchFocus.hasFocus ? T.card(context) : T.subtle(context),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _searchFocus.hasFocus
                  ? T.text(context).withValues(alpha: 0.18)
                  : T.border(context),
              width: 0.8,
            ),
          ),
          child: Row(children: [
            const SizedBox(width: 14),
            Icon(Icons.search_rounded,
                size: 18,
                color:
                    _searchFocus.hasFocus ? T.text(context) : T.muted(context)),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                focusNode: _searchFocus,
                controller: _sc,
                autofocus: true,
                style: TextStyle(color: T.text(context), fontSize: 14),
                decoration: InputDecoration(
                  isCollapsed: true,
                  filled: false,
                  hintText: 'Search invoices…',
                  hintStyle: TextStyle(color: T.faint(context), fontSize: 14),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  disabledBorder: InputBorder.none,
                ),
                onChanged: (v) => setState(() => _q = v),
              ),
            ),
            const SizedBox(width: 14),
          ]),
        )),
        TextButton(
          onPressed: () => setState(() {
            _searching = false;
            _q = '';
            _sc.clear();
          }),
          child: Text('Cancel',
              style: TextStyle(
                  color: T.text(context),
                  fontSize: 14,
                  fontWeight: FontWeight.w700)),
        ),
      ]);

  Widget _iconBtn(IconData icon, VoidCallback onTap,
          {required String tooltip, bool active = false}) =>
      Tooltip(
        message: tooltip,
        child: Semantics(
          button: true,
          label: tooltip,
          child: GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              onTap();
            },
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                  color: active ? T.inverse(context) : T.card(context),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: active ? Colors.transparent : T.border(context),
                      width: 0.5)),
              child: Icon(icon,
                  size: 17,
                  color: active ? T.onInverse(context) : T.muted(context)),
            ),
          ),
        ),
      );

  // ── Tabs ─────────────────────────────────────────────────────

  Widget _tabs() => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Container(
          height: 38,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
              color: T.subtle(context),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: T.border(context), width: 0.5)),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LayoutBuilder(
              builder: (context, constraints) {
                const labels = ['All', 'Unpaid', 'Overdue', 'Paid'];
                final itemW = constraints.maxWidth / labels.length;
                return Stack(children: [
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 220),
                    curve: kSmooth,
                    left: itemW * _tab,
                    top: 0,
                    bottom: 0,
                    width: itemW,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: T.inverse(context),
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                  Row(
                    children: List.generate(labels.length, (i) {
                      final active = i == _tab;
                      return Expanded(
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () {
                            if (active) return;
                            HapticFeedback.selectionClick();
                            setState(() => _tab = i);
                          },
                          child: Center(
                            child: AnimatedDefaultTextStyle(
                              duration: const Duration(milliseconds: 180),
                              curve: kSmooth,
                              style: TextStyle(
                                color: active
                                    ? T.onInverse(context)
                                    : T.muted(context),
                                fontWeight:
                                    active ? FontWeight.w700 : FontWeight.w500,
                                fontSize: 11,
                              ),
                              child: Text(labels[i]),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ]);
              },
            ),
          ),
        ),
      );

  Widget _currentList() {
    switch (_tab) {
      case 1:
        return _buildList(Store.i.unpaid, 'No unpaid invoices', true,
            subtitle: 'All your invoices are paid.');
      case 2:
        return _buildList(Store.i.overdue, 'No overdue invoices', true,
            subtitle: 'Great! You\'re all caught up.');
      case 3:
        return _buildList(Store.i.paid, 'No paid invoices', false);
      default:
        return _buildList(Store.i.all, 'No invoices yet', true);
    }
  }

  // ── List builder ─────────────────────────────────────────────

  Widget _buildList(List<Invoice> invs, String emptyTitle, bool showCta,
      {String? subtitle}) {
    if (invs.isEmpty) {
      return _emptyState(emptyTitle, subtitle, showCta);
    }
    final sorted = _sorted(invs);
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(0, 4, 0, 100),
      itemCount: sorted.length,
      separatorBuilder: (_, __) => Divider(
          height: 1, color: T.divider(context), indent: 20, endIndent: 20),
      itemBuilder: (_, i) {
        final inv = sorted[i];
        return _InvRow(
          inv: inv,
          onTap: () => _open(inv),
          onDel: () => _del(inv.id),
        );
      },
    );
  }

  Widget _emptyState(String title, String? subtitle, bool showCta) =>
      EmptyState(
        icon: Icons.receipt_long_outlined,
        message: title,
        subtitle: subtitle ??
            (showCta ? 'Start with a quick invoice.' : 'Nothing to show here.'),
        ctaLabel: showCta ? 'Create Invoice' : null,
        ctaOnTap: showCta ? _newInvoice : null,
      );
}

// ── Invoice row ───────────────────────────────────────────────────

class _InvRow extends StatelessWidget {
  final Invoice inv;
  final VoidCallback onTap, onDel;
  const _InvRow({
    required this.inv,
    required this.onTap,
    required this.onDel,
  });

  String get _title {
    final name = inv.client.name.trim();
    if (name.isNotEmpty) return name;
    return inv.displayStatus == Status.draft
        ? 'Draft invoice'
        : 'No client added';
  }

  String get _amount => inv.isPartPaid ? amtK(inv.balance) : amtK(inv.total);

  String get _dueLine {
    if (inv.isPartPaid) return '${amtK(inv.balance)} balance due';
    switch (inv.displayStatus) {
      case Status.paid:
        if (inv.payments.isNotEmpty) {
          return 'Paid on ${fDate(inv.payments.last.date)}';
        }
        return 'Paid';
      case Status.overdue:
        final d = DateTime.now().difference(inv.due).inDays;
        return 'Overdue by $d day${d == 1 ? '' : 's'}';
      case Status.draft:
        return 'Draft';
      default:
        return inv.dueDateText;
    }
  }

  @override
  Widget build(BuildContext context) {
    final urgent = inv.displayStatus == Status.overdue;
    final meta = '${inv.num}  ·  $_dueLine';

    return Dismissible(
      key: Key(inv.id),
      direction: DismissDirection.endToStart,
      background: Semantics(
        label: 'Delete invoice',
        child: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 24),
          color: C.overdue,
          child: const Icon(Icons.delete_outline_rounded,
              color: C.white, size: 22),
        ),
      ),
      confirmDismiss: (_) => showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: T.card(context),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Delete Invoice',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
          content: Text('Remove ${inv.num}?',
              style: TextStyle(color: T.muted(context))),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel', style: TextStyle(color: C.grey5))),
            TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Delete',
                    style: TextStyle(
                        color: C.overdue, fontWeight: FontWeight.w600))),
          ],
        ),
      ),
      onDismissed: (_) => onDel(),
      child: Tooltip(
        message: 'Open invoice. Swipe left to delete.',
        child: Semantics(
          button: true,
          label: 'Open invoice ${inv.num}',
          hint: 'Swipe left to delete',
          child: InkWell(
            onTap: () {
              HapticFeedback.selectionClick();
              onTap();
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 17),
              child: Row(children: [
                // Left: client + quiet invoice metadata
                Expanded(
                    child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: T.text(context))),
                    const SizedBox(height: 6),
                    Text(
                      meta,
                      style: TextStyle(
                          fontSize: 12,
                          color: urgent ? C.overdue : T.muted(context)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                )),
                const SizedBox(width: 16),
                // Right: amount + status
                SizedBox(
                  width: 96,
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(_amount,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.right,
                            style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: T.text(context))),
                        const SizedBox(height: 5),
                        StatusPill(inv: inv),
                      ]),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
