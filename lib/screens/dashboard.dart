import 'package:flutter/material.dart';
import '../theme.dart';
import '../models.dart';
import '../widgets.dart';
import 'create.dart';
import 'detail.dart';
import 'profile.dart';
import 'settings.dart';
import 'templates.dart';

enum _Period { thisMonth, lastMonth, thisYear, allTime }

class DashboardPage extends StatefulWidget {
  final VoidCallback? onSeeAll;
  final void Function(int invoiceTab)? onOpenInvoices;
  const DashboardPage({super.key, this.onSeeAll, this.onOpenInvoices});
  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  _Period _period = _Period.thisMonth;
  int? _selectedTrendIndex;

  // ── Period helpers ───────────────────────────────────────────

  String get _periodLabel {
    final now = DateTime.now();
    switch (_period) {
      case _Period.thisMonth:
        return '${_mon(now.month)} ${now.year}';
      case _Period.lastMonth:
        final d = DateTime(now.year, now.month - 1);
        return '${_mon(d.month)} ${d.year}';
      case _Period.thisYear:
        return '${now.year}';
      case _Period.allTime:
        return 'All time';
    }
  }

  String _mon(int m) => [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec'
      ][m - 1];

  List<Invoice> get _filtered {
    final all = Store.i.all;
    final now = DateTime.now();
    switch (_period) {
      case _Period.thisMonth:
        return all
            .where((i) => i.date.year == now.year && i.date.month == now.month)
            .toList();
      case _Period.lastMonth:
        final d = DateTime(now.year, now.month - 1);
        return all
            .where((i) => i.date.year == d.year && i.date.month == d.month)
            .toList();
      case _Period.thisYear:
        return all.where((i) => i.date.year == now.year).toList();
      case _Period.allTime:
        return List.from(all);
    }
  }

  List<Invoice> get _prevFiltered {
    final all = Store.i.all;
    final now = DateTime.now();
    switch (_period) {
      case _Period.thisMonth:
        final d = DateTime(now.year, now.month - 1);
        return all
            .where((i) => i.date.year == d.year && i.date.month == d.month)
            .toList();
      case _Period.lastMonth:
        final d = DateTime(now.year, now.month - 2);
        return all
            .where((i) => i.date.year == d.year && i.date.month == d.month)
            .toList();
      case _Period.thisYear:
        return all.where((i) => i.date.year == now.year - 1).toList();
      case _Period.allTime:
        return [];
    }
  }

  double get _revenue => _filtered.fold(0, (s, i) => s + i.collectedAmt);
  double get _prevRevenue =>
      _prevFiltered.fold(0, (s, i) => s + i.collectedAmt);
  double get _pending => _filtered
      .where((i) => i.displayStatus == Status.pending)
      .fold(0, (s, i) => s + i.balance);
  double get _overdue => _filtered
      .where((i) => i.displayStatus == Status.overdue)
      .fold(0, (s, i) => s + i.balance);
  int get _pendingCount =>
      _filtered.where((i) => i.displayStatus == Status.pending).length;
  int get _overdueCount =>
      _filtered.where((i) => i.displayStatus == Status.overdue).length;

  // ── Revenue trend for the selected period ────────────────────
  List<DateTime> get _trendPoints {
    final now = DateTime.now();
    switch (_period) {
      case _Period.thisMonth:
        return List.generate(
            now.day, (i) => DateTime(now.year, now.month, i + 1));
      case _Period.lastMonth:
        final d = DateTime(now.year, now.month - 1);
        final days = DateTime(d.year, d.month + 1, 0).day;
        return List.generate(days, (i) => DateTime(d.year, d.month, i + 1));
      case _Period.thisYear:
        return List.generate(now.month, (i) => DateTime(now.year, i + 1));
      case _Period.allTime:
        if (Store.i.all.isEmpty) {
          return List.generate(6, (i) => DateTime(now.year, now.month - 5 + i));
        }
        final dates = Store.i.all.map((i) => i.date).toList()
          ..sort((a, b) => a.compareTo(b));
        final first = DateTime(dates.first.year, dates.first.month);
        final monthCount =
            (now.year - first.year) * 12 + now.month - first.month + 1;
        return List.generate(monthCount.clamp(1, 12), (i) {
          final offset = monthCount > 12 ? monthCount - 12 + i : i;
          return DateTime(first.year, first.month + offset);
        });
    }
  }

  List<double> get _trendData {
    final points = _trendPoints;
    var running = 0.0;
    return points.map((d) {
      final amount = _period == _Period.thisYear || _period == _Period.allTime
          ? _collectedInMonth(d)
          : _collectedOnDay(d);
      running += amount;
      return running;
    }).toList();
  }

  double _collectedOnDay(DateTime day) => _filtered
      .where((i) =>
          i.date.year == day.year &&
          i.date.month == day.month &&
          i.date.day == day.day)
      .fold<double>(0, (s, i) => s + i.collectedAmt);

  double _collectedInMonth(DateTime month) => _filtered
      .where((i) => i.date.year == month.year && i.date.month == month.month)
      .fold<double>(0, (s, i) => s + i.collectedAmt);

  List<String> get _trendLabels {
    final points = _trendPoints;
    if (points.isEmpty) return const ['', '', ''];
    final mid = points[(points.length - 1) ~/ 2];
    return [
      _chartLabel(points.first),
      _chartLabel(mid),
      _chartLabel(points.last),
    ];
  }

  String _chartLabel(DateTime d) {
    if (_period == _Period.thisYear || _period == _Period.allTime) {
      return _mon(d.month);
    }
    return '${d.day} ${_mon(d.month)}';
  }

  void _r() => setState(() {});

  void _pickPeriod() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => PickSheet(
        title: 'Time period',
        items: const ['This month', 'Last month', 'This year', 'All time'],
        sel: _period.index,
        onSel: (i) => setState(() {
          _period = _Period.values[i];
          _selectedTrendIndex = null;
        }),
        dark: T.dark(context),
      ),
    );
  }

  void _selectTrendAt(double dx, double width) {
    final data = _trendData;
    if (data.isEmpty || width <= 0) return;
    final pct = (dx / width).clamp(0.0, 1.0);
    final index = (pct * (data.length - 1)).round().clamp(0, data.length - 1);
    setState(() => _selectedTrendIndex = index);
  }

  void _clearTrendSelection() {
    if (_selectedTrendIndex != null) setState(() => _selectedTrendIndex = null);
  }

  void _seeAll() {
    if (widget.onOpenInvoices != null) {
      widget.onOpenInvoices!(0);
      return;
    }
    if (widget.onSeeAll != null) {
      widget.onSeeAll!();
    } else {
      Navigator.push(context, slideRoute(_InvoicesProxy()));
    }
  }

  void _openSettings() {
    Navigator.push(context, slideRoute(const SettingsPage())).then((_) => _r());
  }

  void _openProfile() {
    Navigator.push(context, slideRoute(const ProfilePage())).then((_) => _r());
  }

  void _openTemplates() {
    Navigator.push(context, slideRoute(const TemplatesPage()))
        .then((_) => _r());
  }

  void _quickInvoice() {
    Store.i.create().then((inv) {
      if (!mounted) return;
      Navigator.push(
          context,
          slideRoute(CreatePage(
            invoice: inv,
            onSaved: (v) {
              Store.i.add(v);
              _r();
            },
          )));
    });
  }

  // ── % change indicator ───────────────────────────────────────
  Widget _trendChange({required bool onDarkCard}) {
    if (_period == _Period.allTime) return const SizedBox.shrink();
    final prev = _prevRevenue;
    final curr = _revenue;
    if (prev == 0 && curr == 0) return const SizedBox.shrink();

    String label;
    Color color;

    if (prev == 0) {
      label = 'New this period';
      color = onDarkCard ? C.white.withValues(alpha: 0.68) : C.grey5;
    } else {
      final pct = ((curr - prev) / prev * 100).round();
      final activeColor = onDarkCard
          ? C.white.withValues(alpha: 0.78)
          : T.text(context).withValues(alpha: 0.72);
      if (pct > 0) {
        label = '↑ $pct%  vs ${_prevLabel()}';
        color = activeColor;
      } else if (pct < 0) {
        label = '↓ ${pct.abs()}%  vs ${_prevLabel()}';
        color = activeColor;
      } else {
        label = '— Same as ${_prevLabel()}';
        color = onDarkCard ? C.white.withValues(alpha: 0.68) : C.grey5;
      }
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: onDarkCard ? 0.12 : 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.16), width: 0.5),
      ),
      child: Text(label,
          style: TextStyle(
              color: color, fontSize: 12, fontWeight: FontWeight.w700)),
    );
  }

  String _prevLabel() {
    final now = DateTime.now();
    switch (_period) {
      case _Period.thisMonth:
        return _mon(DateTime(now.year, now.month - 1).month);
      case _Period.lastMonth:
        return _mon(DateTime(now.year, now.month - 2).month);
      case _Period.thisYear:
        return '${now.year - 1}';
      case _Period.allTime:
        return '';
    }
  }

  String _initials() {
    final n = Prefs.yourName.value.trim();
    if (n.isEmpty) return 'U';
    final p = n.split(' ').where((w) => w.isNotEmpty).toList();
    return p.length >= 2
        ? '${p[0][0]}${p[1][0]}'.toUpperCase()
        : n[0].toUpperCase();
  }

  // ── Build ────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final recent = Store.i.all.take(3).toList();

    return Scaffold(
      backgroundColor: T.bg(context),
      endDrawer: _AccountDrawer(
        initials: _initials(),
        onSettings: _openSettings,
        onProfile: _openProfile,
        onTemplates: _openTemplates,
      ),
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          SafeArea(
            bottom: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Top bar ──
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                  child: Row(children: [
                    // Period picker — spring tap
                    SpringTap(
                      onTap: _pickPeriod,
                      scale: 0.94,
                      child: Tooltip(
                        message: 'Change time period',
                        child: Semantics(
                          button: true,
                          label: 'Change dashboard time period',
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Text(_periodLabel,
                                style: TextStyle(
                                    color: T.text(context),
                                    fontSize: 17,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0)),
                            const SizedBox(width: 4),
                            Icon(Icons.keyboard_arrow_down_rounded,
                                color: T.faint(context), size: 20),
                          ]),
                        ),
                      ),
                    ),
                    const Spacer(),
                    Builder(
                      builder: (drawerContext) => _menuButton(drawerContext),
                    ),
                  ]),
                ),

                _revenueHero(),

                const SizedBox(height: 24),
              ],
            ),
          ),

          // ── Body ──
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _receivablesPanel(),
                const SizedBox(height: 16),

                _quickInvoiceButton(),
                const SizedBox(height: 32),

                // Recent header
                Row(children: [
                  Text('Recent',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: T.text(context))),
                  const Spacer(),
                  // See all — spring tap
                  SpringTap(
                    onTap: _seeAll,
                    scale: 0.90,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 4),
                      child: Text('See all',
                          style:
                              TextStyle(fontSize: 13, color: T.muted(context))),
                    ),
                  ),
                ]),
                const SizedBox(height: 12),

                // Recent list — spring tap on each row
                recent.isEmpty
                    ? EmptyState(
                        icon: Icons.receipt_long_outlined,
                        message: 'No invoices yet',
                        subtitle: 'Create one quick invoice to see it here.',
                        ctaLabel: 'Quick Invoice',
                        ctaOnTap: _quickInvoice,
                      )
                    : Container(
                        decoration: BoxDecoration(
                          color: T.card(context),
                          borderRadius: BorderRadius.circular(16),
                          border:
                              Border.all(color: T.border(context), width: 0.5),
                        ),
                        child: Column(
                          children: recent.asMap().entries.map((e) {
                            final inv = e.value;
                            final isLast = e.key == recent.length - 1;
                            return Column(children: [
                              SpringTap(
                                scale: 0.98,
                                onTap: () => Navigator.push(
                                    context,
                                    slideRoute(DetailPage(
                                        invoice: inv, onRefresh: _r))),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 18, vertical: 16),
                                  child: Row(children: [
                                    InvAvatar(inv: inv, radius: 20),
                                    const SizedBox(width: 14),
                                    Expanded(
                                        child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(inv.clientDisplay,
                                            style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                                color: T.text(context))),
                                        const SizedBox(height: 4),
                                        Text(
                                          '${inv.dueDateText}  ·  ${inv.num}',
                                          style: TextStyle(
                                              fontSize: 11,
                                              color: T.muted(context)),
                                        ),
                                      ],
                                    )),
                                    const SizedBox(width: 12),
                                    SizedBox(
                                      width: 94,
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.end,
                                        children: [
                                          Text(
                                              inv.isPartPaid
                                                  ? amtK(inv.balance)
                                                  : amtK(inv.total),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              textAlign: TextAlign.right,
                                              style: TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w600,
                                                  color: T.text(context))),
                                          const SizedBox(height: 5),
                                          StatusPill(inv: inv),
                                        ],
                                      ),
                                    ),
                                  ]),
                                ),
                              ),
                              if (!isLast)
                                Divider(
                                    height: 1,
                                    color: T.divider(context),
                                    indent: 18),
                            ]);
                          }).toList(),
                        ),
                      ),

                const SizedBox(height: 100),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Widget helpers ───────────────────────────────────────────

  Widget _revenueHero() {
    final data = _trendData;
    final points = _trendPoints;
    final labels = _trendLabels;
    final dark = T.dark(context);
    final text = T.text(context);
    final muted = T.muted(context);
    final grid = T.border(context).withValues(alpha: dark ? 0.42 : 0.74);
    final pointBg = T.bg(context);
    final isDown = _period != _Period.allTime &&
        _prevRevenue > 0 &&
        _revenue < _prevRevenue;
    final lineColor = isDown ? muted : text;
    final compactAmount = _revenue.abs() >= 100000;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Collected in $_periodLabel',
                  style: TextStyle(
                      color: muted, fontSize: 13, fontWeight: FontWeight.w700)),
              const SizedBox(height: 9),
              Text(compactAmount ? amtCompact(_revenue) : amt(_revenue),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: text,
                      fontSize: 42,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0)),
              if (compactAmount) ...[
                const SizedBox(height: 4),
                Text(amt(_revenue),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: muted,
                        fontSize: 12,
                        fontWeight: FontWeight.w700)),
              ],
            ]),
          ),
          const SizedBox(width: 12),
          _trendChange(onDarkCard: false),
        ]),
        const SizedBox(height: 14),
        SizedBox(
          height: 92,
          width: double.infinity,
          child: LayoutBuilder(
            builder: (context, constraints) => GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (d) =>
                  _selectTrendAt(d.localPosition.dx, constraints.maxWidth),
              onHorizontalDragUpdate: (d) =>
                  _selectTrendAt(d.localPosition.dx, constraints.maxWidth),
              onHorizontalDragEnd: (_) => Future.delayed(
                  const Duration(milliseconds: 900), _clearTrendSelection),
              child: Stack(children: [
                Positioned.fill(
                  child: RepaintBoundary(
                    child: CustomPaint(
                      painter: _RevenueTrendPainter(
                        data,
                        selectedIndex: _selectedTrendIndex,
                        grid: grid,
                        line: lineColor,
                        fill: lineColor.withValues(alpha: dark ? 0.13 : 0.06),
                        pointBg: pointBg,
                        emptyLine: T.faint(context).withValues(alpha: 0.42),
                      ),
                    ),
                  ),
                ),
                if (_selectedTrendIndex != null &&
                    _selectedTrendIndex! < data.length &&
                    _selectedTrendIndex! < points.length)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: _chartValueChip(points[_selectedTrendIndex!],
                        data[_selectedTrendIndex!]),
                  ),
              ]),
            ),
          ),
        ),
        if (data.any((v) => v > 0))
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Align(
              alignment: Alignment.centerRight,
              child: Text('Tap chart for exact value',
                  style: TextStyle(fontSize: 10, color: T.faint(context))),
            ),
          ),
        const SizedBox(height: 7),
        Row(children: [
          Text(labels[0], style: TextStyle(fontSize: 11, color: muted)),
          const Spacer(),
          Text(labels[1], style: TextStyle(fontSize: 11, color: muted)),
          const Spacer(),
          Text(labels[2], style: TextStyle(fontSize: 11, color: muted)),
        ]),
      ]),
    );
  }

  Widget _chartValueChip(DateTime date, double value) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: T.inverse(context),
          borderRadius: BorderRadius.circular(999),
          boxShadow: T.dark(context) ? const [] : T.shadow(context),
        ),
        child: Text('${_chartLabel(date)} · ${amtUi(value)}',
            style: TextStyle(
                color: T.onInverse(context),
                fontSize: 11,
                fontWeight: FontWeight.w800)),
      );

  Widget _receivablesPanel() {
    final total = _pending + _overdue;
    final openCount = _pendingCount + _overdueCount;
    final dark = T.dark(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: T.card(context),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: T.border(context), width: 0.5),
        boxShadow: dark
            ? const []
            : const [
                BoxShadow(
                  color: Color(0x0A000000),
                  blurRadius: 22,
                  offset: Offset(0, 12),
                ),
              ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 11, 12, 7),
          child: Row(children: [
            Expanded(
              child: Text(
                openCount == 0
                    ? 'Nothing pending'
                    : '$openCount invoice${openCount == 1 ? '' : 's'} to collect',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: T.muted(context),
                    fontSize: 12,
                    fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 96,
              child: Text(amtCompact(total),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                  style: TextStyle(
                      color: T.text(context),
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0)),
            ),
          ]),
        ),
        _openBalanceRow(
          title: 'Pending',
          amount: _pending,
          count: _pendingCount,
          icon: Icons.schedule_rounded,
          onTap: () => widget.onOpenInvoices?.call(1),
        ),
        Divider(height: 1, indent: 62, color: T.divider(context)),
        _openBalanceRow(
          title: 'Overdue',
          amount: _overdue,
          count: _overdueCount,
          icon: Icons.priority_high_rounded,
          onTap: () => widget.onOpenInvoices?.call(2),
        ),
      ]),
    );
  }

  Widget _openBalanceRow({
    required String title,
    required double amount,
    required int count,
    required IconData icon,
    required VoidCallback onTap,
  }) =>
      SpringTap(
        onTap: onTap,
        scale: 0.98,
        child: Container(
          padding: const EdgeInsets.fromLTRB(10, 12, 8, 12),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(20)),
          child: Row(children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: T.subtle(context),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: T.divider(context), width: 0.5),
              ),
              child: Icon(icon, size: 19, color: T.text(context)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: TextStyle(
                            color: T.text(context),
                            fontSize: 14,
                            fontWeight: FontWeight.w800)),
                    const SizedBox(height: 3),
                    Text(
                        count == 0
                            ? 'No invoices'
                            : '$count invoice${count == 1 ? '' : 's'}',
                        style:
                            TextStyle(color: T.faint(context), fontSize: 12)),
                  ]),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 88,
              child: Text(amtCompact(amount),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                  style: TextStyle(
                      color: T.text(context),
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0)),
            ),
            const SizedBox(width: 8),
            Icon(Icons.chevron_right_rounded,
                size: 18, color: T.faint(context)),
          ]),
        ),
      );

  Widget _quickInvoiceButton() => SpringTap(
        onTap: _quickInvoice,
        scale: 0.97,
        child: Container(
          width: double.infinity,
          height: 66,
          decoration: BoxDecoration(
            color: T.inverse(context),
            borderRadius: BorderRadius.circular(18),
            boxShadow: T.dark(context)
                ? const []
                : const [
                    BoxShadow(
                      color: Color(0x14000000),
                      blurRadius: 24,
                      offset: Offset(0, 12),
                    ),
                  ],
          ),
          child: Stack(children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: T.onInverse(context).withValues(alpha: 0.10),
                    width: 1,
                  ),
                ),
              ),
            ),
            Center(
              child: Text('Quick Invoice',
                  style: TextStyle(
                      color: T.onInverse(context),
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0)),
            ),
          ]),
        ),
      );

  Widget _menuButton(BuildContext drawerContext) => SpringTap(
        onTap: () => Scaffold.of(drawerContext).openEndDrawer(),
        scale: 0.94,
        child: Tooltip(
          message: 'Open menu',
          child: Semantics(
            button: true,
            label: 'Open menu',
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: T.card(context),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: T.border(context), width: 0.5),
              ),
              child: Icon(Icons.menu_rounded, color: T.text(context), size: 20),
            ),
          ),
        ),
      );
}

class _AccountDrawer extends StatelessWidget {
  final String initials;
  final VoidCallback onSettings;
  final VoidCallback onProfile;
  final VoidCallback onTemplates;
  const _AccountDrawer({
    required this.initials,
    required this.onSettings,
    required this.onProfile,
    required this.onTemplates,
  });

  @override
  Widget build(BuildContext context) {
    final name =
        Prefs.yourName.value.isEmpty ? 'Your profile' : Prefs.yourName.value;
    final business =
        Prefs.bizName.value.isEmpty ? 'Invoy account' : Prefs.bizName.value;
    final gst = Prefs.defaultGst == 0
        ? 'No GST'
        : '${Prefs.defaultGst.toStringAsFixed(0)}% GST';

    return SizedBox(
      width: MediaQuery.sizeOf(context).width * 0.86,
      child: Drawer(
        backgroundColor: T.bg(context),
        elevation: 0,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Text('Invoy',
                      style: TextStyle(
                          color: T.text(context),
                          fontSize: 21,
                          fontWeight: FontWeight.w800)),
                  const Spacer(),
                  SpringTap(
                    onTap: () => Navigator.pop(context),
                    scale: 0.9,
                    child: Container(
                      width: 36,
                      height: 36,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: T.card(context),
                        borderRadius: BorderRadius.circular(12),
                        border:
                            Border.all(color: T.border(context), width: 0.5),
                      ),
                      child: Icon(Icons.close_rounded,
                          color: T.muted(context), size: 18),
                    ),
                  ),
                ]),
                const SizedBox(height: 20),
                _accountCard(context, name: name, business: business),
                const SizedBox(height: 14),
                _quickActions(
                  context,
                  profileLabel: name,
                  settingsLabel: '$gst default',
                ),
                const SizedBox(height: 24),
                _sectionLabel(context, 'Workspace'),
                const SizedBox(height: 10),
                _menuGroup(context, [
                  _menuRow(
                    context,
                    title: 'PDF template',
                    value: Prefs.defaultTemplate.value,
                    onTap: onTemplates,
                  ),
                  _appearanceRow(context),
                  _menuRow(
                    context,
                    title: 'Invoice defaults',
                    value: '$gst - ${Prefs.defaultTermDays} days',
                    onTap: onSettings,
                  ),
                ]),
                const Spacer(),
                _footerNote(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _accountCard(BuildContext context,
          {required String name, required String business}) =>
      SpringTap(
        onTap: () {
          Navigator.pop(context);
          Future.microtask(onProfile);
        },
        scale: 0.98,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: T.card(context),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: T.border(context), width: 0.5),
            boxShadow: T.dark(context)
                ? const []
                : const [
                    BoxShadow(
                      color: Color(0x0A000000),
                      blurRadius: 22,
                      offset: Offset(0, 12),
                    ),
                  ],
          ),
          child: Row(children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: T.inverse(context),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Center(
                child: Text(initials,
                    style: TextStyle(
                        color: T.onInverse(context),
                        fontSize: 15,
                        fontWeight: FontWeight.w800)),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: T.text(context),
                            fontSize: 16,
                            fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    Text(business,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style:
                            TextStyle(color: T.muted(context), fontSize: 12)),
                  ]),
            ),
            Text('Edit',
                style: TextStyle(
                    color: T.text(context),
                    fontSize: 12,
                    fontWeight: FontWeight.w800)),
          ]),
        ),
      );

  Widget _quickActions(BuildContext context,
          {required String profileLabel, required String settingsLabel}) =>
      Row(children: [
        Expanded(
          child: _actionTile(
            context,
            title: 'Profile',
            value: profileLabel,
            onTap: onProfile,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _actionTile(
            context,
            title: 'Settings',
            value: settingsLabel,
            onTap: onSettings,
          ),
        ),
      ]);

  Widget _actionTile(BuildContext context,
          {required String title,
          required String value,
          required VoidCallback onTap}) =>
      SpringTap(
        onTap: () {
          Navigator.pop(context);
          Future.microtask(onTap);
        },
        scale: 0.97,
        child: Container(
          height: 82,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: T.card(context),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: T.border(context), width: 0.5),
          ),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title,
                style: TextStyle(
                    color: T.text(context),
                    fontSize: 14,
                    fontWeight: FontWeight.w800)),
            const Spacer(),
            Text(value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: T.muted(context), fontSize: 12)),
          ]),
        ),
      );

  Widget _sectionLabel(BuildContext context, String text) => Text(text,
      style: TextStyle(
          color: T.muted(context), fontSize: 12, fontWeight: FontWeight.w800));

  Widget _menuGroup(BuildContext context, List<Widget> rows) => Container(
        decoration: BoxDecoration(
          color: T.card(context),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: T.border(context), width: 0.5),
        ),
        child: Column(
          children: [
            for (var i = 0; i < rows.length; i++) ...[
              rows[i],
              if (i != rows.length - 1)
                Divider(
                    height: 1,
                    color: T.divider(context),
                    indent: 16,
                    endIndent: 16),
            ],
          ],
        ),
      );

  Widget _appearanceRow(BuildContext context) =>
      ValueListenableBuilder<ThemeMode>(
        valueListenable: Prefs.themeMode,
        builder: (context, mode, _) {
          final label = switch (mode) {
            ThemeMode.dark => 'Dark',
            ThemeMode.system => 'System',
            _ => 'Light',
          };
          return _menuRow(
            context,
            title: 'Appearance',
            value: label,
            showChevron: false,
            closeOnTap: false,
            onTap: () {
              final next =
                  mode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
              Prefs.setTheme(next);
            },
          );
        },
      );

  Widget _menuRow(BuildContext context,
          {required String title,
          required String value,
          required VoidCallback onTap,
          bool closeOnTap = true,
          bool showChevron = true}) =>
      InkWell(
        onTap: () {
          if (closeOnTap) Navigator.pop(context);
          Future.microtask(onTap);
        },
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Row(children: [
            Expanded(
              child: Text(title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: T.text(context),
                      fontSize: 14,
                      fontWeight: FontWeight.w800)),
            ),
            const SizedBox(width: 12),
            Flexible(
              child: Text(value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                  style: TextStyle(
                      color: T.muted(context),
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
            ),
            if (showChevron) ...[
              const SizedBox(width: 8),
              Icon(Icons.chevron_right_rounded,
                  size: 18, color: T.faint(context)),
            ],
          ]),
        ),
      );

  Widget _footerNote(BuildContext context) => Row(children: [
        Expanded(
          child: Text('Simple invoices for quick billing',
              style: TextStyle(
                  color: T.faint(context),
                  fontSize: 12,
                  fontWeight: FontWeight.w700)),
        ),
      ]);
}

// ════════════════════════════════════════════════════════════════
// REVENUE TREND
// ════════════════════════════════════════════════════════════════

class _RevenueTrendPainter extends CustomPainter {
  final List<double> data;
  final int? selectedIndex;
  final Color grid, line, fill, pointBg, emptyLine;
  _RevenueTrendPainter(
    this.data, {
    this.selectedIndex,
    required this.grid,
    required this.line,
    required this.fill,
    required this.pointBg,
    required this.emptyLine,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final chart = Rect.fromLTWH(0, 8, size.width, size.height - 16);
    final gridPaint = Paint()
      ..color = grid
      ..strokeWidth = 0.7
      ..style = PaintingStyle.stroke;
    for (final f in [0.22, 0.50, 0.78]) {
      final y = chart.top + chart.height * f;
      _drawDashedLine(
          canvas, Offset(chart.left, y), Offset(chart.right, y), gridPaint);
    }

    if (data.isEmpty) return;
    final maxVal = data.reduce((a, b) => a > b ? a : b);
    if (maxVal == 0) {
      final y = chart.top + chart.height * 0.66;
      canvas.drawLine(
          Offset(chart.left, y),
          Offset(chart.right, y),
          Paint()
            ..color = emptyLine
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.4
            ..strokeCap = StrokeCap.round);
      return;
    }

    final pts = <Offset>[];
    for (var i = 0; i < data.length; i++) {
      final x = data.length == 1
          ? chart.left
          : chart.left + i / (data.length - 1) * chart.width;
      final y = chart.bottom - (data[i] / maxVal) * chart.height;
      pts.add(Offset(x, y.clamp(chart.top, chart.bottom).toDouble()));
    }

    final path = Path()..moveTo(pts[0].dx, pts[0].dy);
    for (var i = 0; i < pts.length - 1; i++) {
      final cp1 = Offset((pts[i].dx + pts[i + 1].dx) / 2, pts[i].dy);
      final cp2 = Offset((pts[i].dx + pts[i + 1].dx) / 2, pts[i + 1].dy);
      path.cubicTo(
          cp1.dx, cp1.dy, cp2.dx, cp2.dy, pts[i + 1].dx, pts[i + 1].dy);
    }

    final fillPath = Path.from(path)
      ..lineTo(chart.right, chart.bottom)
      ..lineTo(chart.left, chart.bottom)
      ..close();
    canvas.drawPath(
        fillPath,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              fill,
              fill.withValues(alpha: 0),
            ],
          ).createShader(chart)
          ..style = PaintingStyle.fill);

    canvas.drawPath(
        path,
        Paint()
          ..color = line
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round);

    canvas.drawCircle(pts.last, 4.5, Paint()..color = line);
    canvas.drawCircle(pts.last, 2.2, Paint()..color = pointBg);

    final selected = selectedIndex;
    if (selected != null && selected >= 0 && selected < pts.length) {
      final p = pts[selected];
      canvas.drawLine(
          Offset(p.dx, chart.top),
          Offset(p.dx, chart.bottom),
          Paint()
            ..color = line.withValues(alpha: 0.24)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1);
      canvas.drawCircle(p, 6, Paint()..color = pointBg);
      canvas.drawCircle(
          p,
          5,
          Paint()
            ..color = line
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2);
      canvas.drawCircle(p, 2.2, Paint()..color = line);
    }
  }

  void _drawDashedLine(Canvas canvas, Offset start, Offset end, Paint paint) {
    const dash = 6.0;
    const gap = 7.0;
    var x = start.dx;
    while (x < end.dx) {
      final next = (x + dash).clamp(start.dx, end.dx).toDouble();
      canvas.drawLine(Offset(x, start.dy), Offset(next, end.dy), paint);
      x += dash + gap;
    }
  }

  @override
  bool shouldRepaint(_RevenueTrendPainter old) =>
      old.data != data ||
      old.selectedIndex != selectedIndex ||
      old.grid != grid ||
      old.line != line ||
      old.fill != fill ||
      old.pointBg != pointBg ||
      old.emptyLine != emptyLine;
}

// ── Proxy ─────────────────────────────────────────────────────────

class _InvoicesProxy extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: T.bg(context),
        appBar: AppBar(
          backgroundColor: T.bg(context),
          leading: IconButton(
            tooltip: 'Back',
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back_rounded, size: 18),
          ),
          title: const Text('All Invoices'),
          centerTitle: true,
        ),
        body: Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.receipt_long_outlined, size: 48, color: T.border(context)),
          const SizedBox(height: 14),
          Text('Switch to the Invoices tab',
              style: TextStyle(fontSize: 14, color: T.muted(context))),
          const SizedBox(height: 18),
          ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Go back')),
        ])),
      );
}
