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
  final int navigationRequest;
  const InvoicesPage({
    super.key,
    required this.onRefresh,
    this.initialTab = 0,
    this.navigationRequest = 0,
  });
  @override
  State<InvoicesPage> createState() => _InvoicesPageState();
}

class _InvoicesPageState extends State<InvoicesPage> {
  late int _tab;
  _InvoiceSort _sort = _InvoiceSort.newest;
  bool _searching = false;
  bool _openingInvoice = false;
  String _q = '';
  final _sc = TextEditingController();
  final _searchFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _tab = widget.initialTab.clamp(0, 3);
    _searchFocus.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void didUpdateWidget(covariant InvoicesPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialTab != oldWidget.initialTab ||
        widget.navigationRequest != oldWidget.navigationRequest) {
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
    if (!mounted) return;
    widget.onRefresh();
    setState(() {});
  }

  Future<void> _del(String id) async {
    try {
      await Store.i.delete(id);
      if (!mounted) return;
      _r();
    } catch (_) {
      if (!mounted) return;
      setState(() {});
      showAppSnack(context, "Couldn't delete this invoice");
    }
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
        list.sort(
          (a, b) => a.clientDisplay.toLowerCase().compareTo(
                b.clientDisplay.toLowerCase(),
              ),
        );
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
          'Client A-Z',
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
      );

  Future<void> _newInvoice() async {
    if (_openingInvoice) return;
    _openingInvoice = true;
    try {
      final inv = await Store.i.create();
      if (!mounted) return;
      final changed = await Navigator.push<bool>(
        context,
        slideRoute(
          CreatePage(
            invoice: inv,
            onSaved: Store.i.add,
          ),
        ),
      );
      if (changed == true && mounted) _r();
    } finally {
      _openingInvoice = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: T.bg(context),
      body: SafeArea(
        child: Column(
          children: [
            // ── Top bar ──
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 16, 0),
              child: AnimatedSwitcher(
                duration: Prefs.reduceMotion
                    ? Duration.zero
                    : const Duration(milliseconds: 200),
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
          ],
        ),
      ),
    );
  }

  // ── Top row ──────────────────────────────────────────────────

  Widget _topRow() => Row(
        key: const ValueKey('title'),
        children: [
          Expanded(
            child: Text(
              'Invoices',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w700,
                color: T.text(context),
                letterSpacing: 0,
              ),
            ),
          ),
          _iconBtn(
            Icons.sort_rounded,
            _openSort,
            tooltip: 'Sort invoices',
            active: _sort != _InvoiceSort.newest,
          ),
          const SizedBox(width: 8),
          _iconBtn(
            Icons.search_rounded,
            () => setState(() => _searching = true),
            tooltip: 'Search invoices',
          ),
        ],
      );

  Widget _searchBar() => Row(
        key: const ValueKey('search'),
        children: [
          Expanded(
            child: AppSearchField(
              controller: _sc,
              focusNode: _searchFocus,
              hint: 'Search invoices',
              autofocus: true,
              onChanged: (v) => setState(() => _q = v),
              onClear: () => setState(() {
                _q = '';
                _sc.clear();
              }),
            ),
          ),
          TextButton(
            onPressed: () => setState(() {
              _searching = false;
              _q = '';
              _sc.clear();
            }),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: T.text(context),
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      );

  Widget _iconBtn(
    IconData icon,
    VoidCallback onTap, {
    required String tooltip,
    bool active = false,
  }) =>
      Tooltip(
        message: tooltip,
        child: Semantics(
          button: true,
          label: tooltip,
          child: SpringTap(
            onTap: onTap,
            scale: 0.92,
            hoverScale: 1.04,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: active ? T.accentSoft(context) : T.card(context),
                shape: BoxShape.circle,
                border: Border.all(
                  color: active
                      ? T.accent(context).withValues(alpha: 0.22)
                      : T.border(context).withValues(alpha: 0.70),
                  width: 0.5,
                ),
                boxShadow: active ? T.glow(context) : const [],
              ),
              child: Icon(
                icon,
                size: 17,
                color: active ? T.accent(context) : T.muted(context),
              ),
            ),
          ),
        ),
      );

  // ── Tabs ─────────────────────────────────────────────────────

  Widget _tabs() => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Container(
          height: 48,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: T
                .card(context)
                .withValues(alpha: T.dark(context) ? 0.72 : 0.90),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: T.border(context).withValues(alpha: 0.68),
              width: 0.5,
            ),
            boxShadow: T.dark(context) ? const [] : T.softShadow(context),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: LayoutBuilder(
              builder: (context, constraints) {
                const labels = ['All', 'Unpaid', 'Overdue', 'Paid'];
                final itemW = constraints.maxWidth / labels.length;
                return Stack(
                  children: [
                    AnimatedPositioned(
                      duration:
                          Prefs.reduceMotion ? Duration.zero : kSegmentDuration,
                      curve: kSmooth,
                      left: itemW * _tab,
                      top: 0,
                      bottom: 0,
                      width: itemW,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: T.inverse(context),
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: T.buttonShadow(context),
                        ),
                      ),
                    ),
                    Row(
                      children: List.generate(labels.length, (i) {
                        final active = i == _tab;
                        return Expanded(
                          child: SpringTap(
                            scale: 0.955,
                            haptic: false,
                            onTap: () {
                              if (active) {
                                if (Prefs.haptics) {
                                  HapticFeedback.selectionClick();
                                }
                                return;
                              }
                              if (Prefs.haptics) {
                                HapticFeedback.selectionClick();
                              }
                              setState(() => _tab = i);
                            },
                            child: Center(
                              child: AnimatedDefaultTextStyle(
                                duration: Prefs.reduceMotion
                                    ? Duration.zero
                                    : kSegmentTextDuration,
                                curve: kSmooth,
                                style: TextStyle(
                                  color: active
                                      ? T.onInverse(context)
                                      : T.muted(context),
                                  fontWeight: active
                                      ? FontWeight.w800
                                      : FontWeight.w700,
                                  fontSize: 12,
                                ),
                                child: Text(labels[i]),
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      );

  Widget _currentList() {
    switch (_tab) {
      case 1:
        return _buildList(
          Store.i.unpaid,
          'No unpaid invoices',
          true,
          subtitle: 'All your invoices are paid.',
        );
      case 2:
        return _buildList(
          Store.i.overdue,
          'No overdue invoices',
          true,
          subtitle: 'Great! You\'re all caught up.',
        );
      case 3:
        return _buildList(Store.i.paid, 'No paid invoices', false);
      default:
        return _buildList(Store.i.all, 'No invoices yet', true);
    }
  }

  // ── List builder ─────────────────────────────────────────────

  Widget _buildList(
    List<Invoice> invs,
    String emptyTitle,
    bool showCta, {
    String? subtitle,
  }) {
    if (invs.isEmpty) {
      return _emptyState(emptyTitle, subtitle, showCta);
    }
    final sorted = _sorted(invs);
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(0, 4, 0, 100),
      itemCount: sorted.length,
      separatorBuilder: (_, __) => Divider(
        height: 1,
        color: T.divider(context),
        indent: 20,
        endIndent: 20,
      ),
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
      Builder(builder: (context) {
        final hasInvoices = Store.i.all.isNotEmpty;
        final canCreate = showCta && !hasInvoices;
        final canViewAll = hasInvoices && !_searching && _tab != 0;
        return EmptyState(
          icon: Icons.receipt_long_outlined,
          message: title,
          subtitle: subtitle ??
              (canCreate
                  ? 'Start with a quick invoice.'
                  : 'Nothing to show here.'),
          ctaLabel: canCreate
              ? 'Create Invoice'
              : canViewAll
                  ? 'View All Invoices'
                  : null,
          ctaOnTap: canCreate
              ? _newInvoice
              : canViewAll
                  ? () => setState(() => _tab = 0)
                  : null,
        );
      });
}

// ── Invoice row ───────────────────────────────────────────────────

class _InvRow extends StatelessWidget {
  final Invoice inv;
  final VoidCallback onTap, onDel;
  const _InvRow({required this.inv, required this.onTap, required this.onDel});

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
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final dueDay = DateTime(inv.due.year, inv.due.month, inv.due.day);
        final d = today.difference(dueDay).inDays;
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
    final meta = inv.displayStatus == Status.draft
        ? 'Draft'
        : '${inv.displayNumber}  ·  $_dueLine';

    return Dismissible(
      key: Key(inv.id),
      direction: DismissDirection.endToStart,
      background: Semantics(
        label: 'Delete invoice',
        child: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 24),
          color: C.overdue,
          child: const Icon(
            Icons.delete_outline_rounded,
            color: C.white,
            size: 22,
          ),
        ),
      ),
      confirmDismiss: (_) => showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: T.card(context),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'Delete Invoice',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
          ),
          content: Text(
            inv.displayStatus == Status.draft
                ? 'Remove this draft?'
                : 'Remove ${inv.displayNumber}?',
            style: TextStyle(color: T.muted(context)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel', style: TextStyle(color: C.grey5)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text(
                'Delete',
                style: TextStyle(color: C.overdue, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
      onDismissed: (_) => onDel(),
      child: Tooltip(
        message: 'Open invoice. Swipe left to delete.',
        child: Semantics(
          button: true,
          label: 'Open invoice ${inv.displayNumber}',
          hint: 'Swipe left to delete',
          child: SpringTap(
            scale: 0.99,
            onTap: () {
              if (Prefs.haptics) HapticFeedback.selectionClick();
              onTap();
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 17),
              child: Row(
                children: [
                  // Left: client + quiet invoice metadata
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: T.text(context),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          meta,
                          style: TextStyle(
                            fontSize: 12,
                            color: urgent ? C.overdue : T.muted(context),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Right: amount + status
                  SizedBox(
                    width: 96,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          _amount,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: T.text(context),
                          ),
                        ),
                        const SizedBox(height: 5),
                        StatusPill(inv: inv),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
