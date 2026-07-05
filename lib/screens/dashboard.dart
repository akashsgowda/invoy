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

class _DashboardMetrics {
  final double revenue;
  final double prevRevenue;
  final double pending;
  final double overdue;
  final int pendingCount;
  final int overdueCount;
  final List<DateTime> trendPoints;
  final List<double> trendData;

  const _DashboardMetrics({
    required this.revenue,
    required this.prevRevenue,
    required this.pending,
    required this.overdue,
    required this.pendingCount,
    required this.overdueCount,
    required this.trendPoints,
    required this.trendData,
  });

  factory _DashboardMetrics.build(List<Invoice> all, _Period period) {
    final now = DateTime.now();
    final filtered = <Invoice>[];
    var revenue = 0.0;
    var prevRevenue = 0.0;
    var pending = 0.0;
    var overdue = 0.0;
    var pendingCount = 0;
    var overdueCount = 0;

    bool sameMonth(DateTime date, DateTime target) =>
        date.year == target.year && date.month == target.month;

    bool inCurrent(Invoice inv) {
      switch (period) {
        case _Period.thisMonth:
          return sameMonth(inv.date, now);
        case _Period.lastMonth:
          return sameMonth(inv.date, DateTime(now.year, now.month - 1));
        case _Period.thisYear:
          return inv.date.year == now.year;
        case _Period.allTime:
          return true;
      }
    }

    bool inPrevious(Invoice inv) {
      switch (period) {
        case _Period.thisMonth:
          return sameMonth(inv.date, DateTime(now.year, now.month - 1));
        case _Period.lastMonth:
          return sameMonth(inv.date, DateTime(now.year, now.month - 2));
        case _Period.thisYear:
          return inv.date.year == now.year - 1;
        case _Period.allTime:
          return false;
      }
    }

    for (final inv in all) {
      if (inPrevious(inv)) {
        prevRevenue += inv.collectedAmt;
      }
      if (!inCurrent(inv)) continue;
      filtered.add(inv);
      revenue += inv.collectedAmt;
    }

    for (final inv in all) {
      final status = inv.displayStatus;
      if (status == Status.pending) {
        pending += inv.balance;
        pendingCount++;
      } else if (status == Status.overdue) {
        overdue += inv.balance;
        overdueCount++;
      }
    }

    final points = _trendPointsFor(all, period, now);
    final buckets = <int, double>{};
    for (final inv in filtered) {
      final key = period == _Period.thisYear || period == _Period.allTime
          ? inv.date.year * 100 + inv.date.month
          : inv.date.year * 10000 + inv.date.month * 100 + inv.date.day;
      buckets[key] = (buckets[key] ?? 0) + inv.collectedAmt;
    }

    var running = 0.0;
    final data = <double>[];
    for (final point in points) {
      final key = period == _Period.thisYear || period == _Period.allTime
          ? point.year * 100 + point.month
          : point.year * 10000 + point.month * 100 + point.day;
      running += buckets[key] ?? 0;
      data.add(running);
    }

    return _DashboardMetrics(
      revenue: revenue,
      prevRevenue: prevRevenue,
      pending: pending,
      overdue: overdue,
      pendingCount: pendingCount,
      overdueCount: overdueCount,
      trendPoints: points,
      trendData: data,
    );
  }

  static List<DateTime> _trendPointsFor(
    List<Invoice> all,
    _Period period,
    DateTime now,
  ) {
    switch (period) {
      case _Period.thisMonth:
        return List.generate(
          now.day,
          (i) => DateTime(now.year, now.month, i + 1),
        );
      case _Period.lastMonth:
        final d = DateTime(now.year, now.month - 1);
        final days = DateTime(d.year, d.month + 1, 0).day;
        return List.generate(days, (i) => DateTime(d.year, d.month, i + 1));
      case _Period.thisYear:
        return List.generate(now.month, (i) => DateTime(now.year, i + 1));
      case _Period.allTime:
        if (all.isEmpty) {
          return List.generate(6, (i) => DateTime(now.year, now.month - 5 + i));
        }
        var first = all.first.date;
        for (final inv in all.skip(1)) {
          if (inv.date.isBefore(first)) first = inv.date;
        }
        final firstMonth = DateTime(first.year, first.month);
        final monthCount = (now.year - firstMonth.year) * 12 +
            now.month -
            firstMonth.month +
            1;
        return List.generate(monthCount.clamp(1, 12), (i) {
          final offset = monthCount > 12 ? monthCount - 12 + i : i;
          return DateTime(firstMonth.year, firstMonth.month + offset);
        });
    }
  }
}

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
  List<Invoice>? _metricsSource;
  _Period? _metricsPeriod;
  _DashboardMetrics? _metricsCache;

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
        'Dec',
      ][m - 1];

  _DashboardMetrics _metrics() {
    final all = Store.i.all;
    if (identical(_metricsSource, all) &&
        _metricsPeriod == _period &&
        _metricsCache != null) {
      return _metricsCache!;
    }
    final metrics = _DashboardMetrics.build(all, _period);
    _metricsSource = all;
    _metricsPeriod = _period;
    _metricsCache = metrics;
    return metrics;
  }

  List<String> _trendLabels(_DashboardMetrics metrics) {
    final points = metrics.trendPoints;
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

  void _r() {
    if (!mounted) return;
    setState(() {});
  }

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
    final data = _metrics().trendData;
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
    Navigator.push(context, slideRoute(const SettingsPage())).then((_) {
      if (mounted) _r();
    });
  }

  void _openDefaults() {
    Navigator.push(
      context,
      slideRoute(const SettingsPage(section: SettingsSection.defaults)),
    ).then((_) {
      if (mounted) _r();
    });
  }

  void _openAppearance() {
    final options = [ThemeMode.light, ThemeMode.dark, ThemeMode.system];
    final labels = ['Light', 'Dark', 'Auto'];
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => AppSheet(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Appearance',
              style: TextStyle(
                color: T.text(context),
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 14),
            ...List.generate(options.length, (i) {
              final active = Prefs.themeMode.value == options[i];
              return SpringTap(
                onTap: () async {
                  await Prefs.setTheme(options[i]);
                  if (!mounted) return;
                  Navigator.pop(context);
                  _r();
                },
                scale: 0.975,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          labels[i],
                          style: TextStyle(
                            color: T.text(context),
                            fontSize: 14,
                            fontWeight:
                                active ? FontWeight.w900 : FontWeight.w700,
                          ),
                        ),
                      ),
                      if (active)
                        Icon(Icons.check_rounded,
                            size: 18, color: T.text(context)),
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  void _openData() {
    Navigator.push(
      context,
      slideRoute(const SettingsPage(section: SettingsSection.data)),
    ).then((_) {
      if (mounted) _r();
    });
  }

  void _openProfile() {
    Navigator.push(context, slideRoute(const ProfilePage())).then((_) {
      if (mounted) _r();
    });
  }

  void _openTemplates() {
    Navigator.push(
      context,
      slideRoute(const TemplatesPage()),
    ).then((_) {
      if (mounted) _r();
    });
  }

  void _quickInvoice() {
    Store.i.create().then((inv) {
      if (!mounted) return;
      Navigator.push(
        context,
        slideRoute(
          CreatePage(
            invoice: inv,
            onSaved: (v) async {
              await Store.i.add(v);
              if (!mounted) return;
              _r();
            },
          ),
        ),
      );
    });
  }

  // ── % change indicator ───────────────────────────────────────
  Widget _trendChange(_DashboardMetrics metrics, {required bool onDarkCard}) {
    if (_period == _Period.allTime) return const SizedBox.shrink();
    final prev = metrics.prevRevenue;
    final curr = metrics.revenue;
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
        label = pct > 200 ? 'Higher than ${_prevLabel()}' : 'Up $pct%';
        color = activeColor;
      } else if (pct < 0) {
        label = pct.abs() > 90
            ? 'Lower than ${_prevLabel()}'
            : 'Down ${pct.abs()}%';
        color = activeColor;
      } else {
        label = '— Same as ${_prevLabel()}';
        color = onDarkCard ? C.white.withValues(alpha: 0.68) : C.grey5;
      }
    }
    return Padding(
      padding: const EdgeInsets.only(top: 5),
      child: Text(
        label,
        textAlign: TextAlign.right,
        style: TextStyle(
          color: color.withValues(alpha: onDarkCard ? 0.82 : 0.74),
          fontSize: 11.5,
          fontWeight: FontWeight.w800,
        ),
      ),
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

  // ── Build ────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final all = Store.i.all;
    final metrics = _metrics();
    final recent = all.take(3).toList();
    final showRecent = Prefs.showDashboardRecent;

    return Scaffold(
      backgroundColor: T.bg(context),
      endDrawer: _AccountDrawer(
        onSettings: _openSettings,
        onDefaults: _openDefaults,
        onAppearance: _openAppearance,
        onData: _openData,
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
                  child: Row(
                    children: [
                      // Period picker — spring tap
                      SpringTap(
                        onTap: _pickPeriod,
                        scale: 0.94,
                        child: Tooltip(
                          message: 'Change time period',
                          child: Semantics(
                            button: true,
                            label: 'Change dashboard time period',
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _periodLabel,
                                  style: TextStyle(
                                    color: T.text(context),
                                    fontSize: 17,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Icon(
                                  Icons.keyboard_arrow_down_rounded,
                                  color: T.faint(context),
                                  size: 20,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const Spacer(),
                      Builder(
                        builder: (drawerContext) => _menuButton(drawerContext),
                      ),
                    ],
                  ),
                ),

                _revenueHero(metrics),

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
                _quickInvoiceButton(),
                if (showRecent) ...[
                  const SizedBox(height: 32),

                  // Recent header
                  Row(
                    children: [
                      Text(
                        'Recent',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: T.text(context),
                        ),
                      ),
                      const Spacer(),
                      // See all — spring tap
                      SpringTap(
                        onTap: _seeAll,
                        scale: 0.90,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 4,
                          ),
                          child: Text(
                            'See all',
                            style: TextStyle(
                              fontSize: 13,
                              color: T.muted(context),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  _recentList(recent),
                ],
                const SizedBox(height: 100),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Widget helpers ───────────────────────────────────────────

  Widget _recentList(List<Invoice> recent) {
    if (recent.isEmpty) {
      return EmptyState(
        icon: Icons.receipt_long_outlined,
        message: 'No invoices yet',
        subtitle: 'Create one quick invoice to see it here.',
        ctaLabel: 'Quick Invoice',
        ctaOnTap: _quickInvoice,
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: T.card(context).withValues(alpha: T.dark(context) ? 0.72 : 0.82),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: T.border(context).withValues(alpha: 0.70),
          width: 0.5,
        ),
      ),
      child: Column(
        children: recent.asMap().entries.map((e) {
          final inv = e.value;
          final isLast = e.key == recent.length - 1;
          return Column(
            children: [
              SpringTap(
                scale: 0.985,
                onTap: () => Navigator.push(
                  context,
                  slideRoute(DetailPage(invoice: inv, onRefresh: _r)),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 15, 16, 15),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              inv.client.isEmpty
                                  ? 'Draft invoice'
                                  : inv.clientDisplay,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w800,
                                color: T.text(context),
                                letterSpacing: 0,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              '${inv.dueDateText}  ·  ${inv.num}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                color: T.muted(context),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 14),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            inv.isPartPaid
                                ? amtK(inv.balance)
                                : amtK(inv.total),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.right,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                              color: T.text(context),
                              letterSpacing: 0,
                            ),
                          ),
                          const SizedBox(height: 6),
                          StatusPill(inv: inv),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              if (!isLast)
                Divider(
                  height: 1,
                  color: T.divider(context),
                  indent: 18,
                  endIndent: 18,
                ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _revenueHero(_DashboardMetrics metrics) {
    final data = metrics.trendData;
    final points = metrics.trendPoints;
    final labels = _trendLabels(metrics);
    final dark = T.dark(context);
    final text = T.text(context);
    final muted = T.muted(context);
    final grid = T.border(context).withValues(alpha: dark ? 0.42 : 0.74);
    final pointBg = T.bg(context);
    final lineColor = T.accent(context);
    final compactAmount = metrics.revenue.abs() >= 100000;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Collected in $_periodLabel',
                      style: TextStyle(
                        color: muted,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 9),
                    Text(
                      compactAmount
                          ? amtCompact(metrics.revenue)
                          : amt(metrics.revenue),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: text,
                        fontSize: 42,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0,
                      ),
                    ),
                    if (compactAmount) ...[
                      const SizedBox(height: 4),
                      Text(
                        amt(metrics.revenue),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: muted,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _trendChange(metrics, onDarkCard: false),
            ],
          ),
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
                  const Duration(milliseconds: 900),
                  _clearTrendSelection,
                ),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: RepaintBoundary(
                        child: CustomPaint(
                          painter: _RevenueTrendPainter(
                            data,
                            selectedIndex: _selectedTrendIndex,
                            grid: grid,
                            line: lineColor,
                            fill: lineColor.withValues(
                              alpha: dark ? 0.13 : 0.06,
                            ),
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
                        child: _chartValueChip(
                          points[_selectedTrendIndex!],
                          data[_selectedTrendIndex!],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 13),
          Row(
            children: [
              Text(labels[0], style: TextStyle(fontSize: 11, color: muted)),
              const Spacer(),
              Text(labels[1], style: TextStyle(fontSize: 11, color: muted)),
              const Spacer(),
              Text(labels[2], style: TextStyle(fontSize: 11, color: muted)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _chartValueChip(DateTime date, double value) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: T.inverse(context),
          borderRadius: BorderRadius.circular(999),
          boxShadow: T.dark(context) ? const [] : T.shadow(context),
        ),
        child: Text(
          '${_chartLabel(date)} · ${amtUi(value)}',
          style: TextStyle(
            color: T.onInverse(context),
            fontSize: 11,
            fontWeight: FontWeight.w800,
          ),
        ),
      );

  Widget _quickInvoiceButton() {
    final dark = T.dark(context);
    final bg = dark ? const Color(0xFFF7F7F8) : const Color(0xFF101010);
    final fg = dark ? C.black : C.white;

    return SpringTap(
      onTap: _quickInvoice,
      scale: 0.965,
      hoverScale: 1.008,
      child: Tooltip(
        message: 'Create invoice',
        child: Semantics(
          button: true,
          label: 'Create quick invoice',
          child: AnimatedContainer(
            duration: Prefs.reduceMotion
                ? Duration.zero
                : const Duration(milliseconds: 180),
            curve: kSmooth,
            width: double.infinity,
            height: 62,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: dark
                    ? C.black.withValues(alpha: 0.06)
                    : C.white.withValues(alpha: 0.10),
                width: 0.8,
              ),
              boxShadow: dark
                  ? const [
                      BoxShadow(
                        color: Color(0x70000000),
                        blurRadius: 26,
                        offset: Offset(0, 14),
                      ),
                    ]
                  : const [
                      BoxShadow(
                        color: Color(0x22000000),
                        blurRadius: 28,
                        offset: Offset(0, 14),
                      ),
                    ],
            ),
            child: Stack(
              children: [
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(28),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          fg.withValues(alpha: dark ? 0.02 : 0.08),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
                Center(
                  child: Text(
                    'Quick Invoice',
                    style: TextStyle(
                      color: fg,
                      fontSize: 15.5,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _menuButton(BuildContext drawerContext) => SpringTap(
        onTap: () => Scaffold.of(drawerContext).openEndDrawer(),
        scale: 0.945,
        hoverScale: 1.012,
        child: Tooltip(
          message: 'Open menu',
          child: Semantics(
            button: true,
            label: 'Open menu',
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: T.card(context).withValues(alpha: 0.86),
                shape: BoxShape.circle,
                border: Border.all(
                  color: T.border(context).withValues(alpha: 0.70),
                  width: 0.5,
                ),
                boxShadow: T.dark(context) ? const [] : T.softShadow(context),
              ),
              child: Icon(Icons.menu_rounded, color: T.text(context), size: 20),
            ),
          ),
        ),
      );
}

class _AccountDrawer extends StatelessWidget {
  final VoidCallback onSettings;
  final VoidCallback onDefaults;
  final VoidCallback onAppearance;
  final VoidCallback onData;
  final VoidCallback onProfile;
  final VoidCallback onTemplates;
  const _AccountDrawer({
    required this.onSettings,
    required this.onDefaults,
    required this.onAppearance,
    required this.onData,
    required this.onProfile,
    required this.onTemplates,
  });

  @override
  Widget build(BuildContext context) {
    final business =
        Prefs.bizName.value.isEmpty ? 'Not set' : Prefs.bizName.value;
    final gst = Prefs.defaultGst == 0
        ? 'No GST'
        : '${Prefs.defaultGst.toStringAsFixed(0)}% GST';
    final theme = switch (Prefs.themeMode.value) {
      ThemeMode.dark => 'Dark',
      ThemeMode.system => 'Auto',
      _ => 'Light',
    };

    return SizedBox(
      width: MediaQuery.sizeOf(context).width * 0.84,
      child: Drawer(
        backgroundColor: T.bg(context),
        elevation: 0,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Menu',
                      style: TextStyle(
                        color: T.text(context),
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const Spacer(),
                    SpringTap(
                      onTap: () => Navigator.pop(context),
                      scale: 0.9,
                      child: Container(
                        width: 36,
                        height: 36,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: T.card(context).withValues(alpha: 0.86),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: T.border(context).withValues(alpha: 0.70),
                            width: 0.5,
                          ),
                        ),
                        child: Icon(
                          Icons.close_rounded,
                          color: T.muted(context),
                          size: 18,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                _menuGrid(context, [
                  _MenuAction('Business', business, onProfile),
                  _MenuAction('Defaults', '$gst · ${Prefs.defaultTermDays}d',
                      onDefaults),
                  _MenuAction(
                      'Templates', Prefs.defaultTemplate.value, onTemplates),
                  _MenuAction('Appearance', theme, onAppearance),
                  _MenuAction('Data', 'Export & restore', onData),
                  _MenuAction('Preferences', 'Home & motion', onSettings),
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

  Widget _menuGrid(BuildContext context, List<_MenuAction> actions) =>
      GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: actions.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.52,
        ),
        itemBuilder: (context, index) {
          final action = actions[index];
          return SpringTap(
            onTap: () {
              Navigator.pop(context);
              Future.microtask(action.onTap);
            },
            scale: 0.955,
            child: AnimatedContainer(
              duration: Prefs.reduceMotion
                  ? Duration.zero
                  : const Duration(milliseconds: 180),
              curve: kSmooth,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: T
                    .card(context)
                    .withValues(alpha: T.dark(context) ? 0.70 : 0.88),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: T.border(context).withValues(alpha: 0.68),
                  width: 0.5,
                ),
                boxShadow: T.dark(context) ? const [] : T.softShadow(context),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    action.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: T.text(context),
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    action.value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: T.muted(context),
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );

  Widget _footerNote(BuildContext context) => Row(
        children: [
          Expanded(
            child: Text(
              'Simple invoices for quick billing',
              style: TextStyle(
                color: T.faint(context),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      );
}

class _MenuAction {
  final String title;
  final String value;
  final VoidCallback onTap;
  const _MenuAction(this.title, this.value, this.onTap);
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
        canvas,
        Offset(chart.left, y),
        Offset(chart.right, y),
        gridPaint,
      );
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
          ..strokeCap = StrokeCap.round,
      );
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
        cp1.dx,
        cp1.dy,
        cp2.dx,
        cp2.dy,
        pts[i + 1].dx,
        pts[i + 1].dy,
      );
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
          colors: [fill, fill.withValues(alpha: 0)],
        ).createShader(chart)
        ..style = PaintingStyle.fill,
    );

    canvas.drawPath(
      path,
      Paint()
        ..color = line
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

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
          ..strokeWidth = 1,
      );
      canvas.drawCircle(p, 6, Paint()..color = pointBg);
      canvas.drawCircle(
        p,
        5,
        Paint()
          ..color = line
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.receipt_long_outlined,
                  size: 48, color: T.border(context)),
              const SizedBox(height: 14),
              Text(
                'Switch to the Invoices tab',
                style: TextStyle(fontSize: 14, color: T.muted(context)),
              ),
              const SizedBox(height: 18),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Go back'),
              ),
            ],
          ),
        ),
      );
}
