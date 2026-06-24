import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme.dart';
import '../models.dart';
import 'client_form.dart';
import 'create.dart';
import 'dashboard.dart';
import 'invoices.dart';
import 'clients.dart';

class Shell extends StatefulWidget {
  const Shell({super.key});
  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int _tab = 0;
  int _invoiceTab = 0;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_loadData());
    });
  }

  Future<void> _loadData() async {
    try {
      await Store.i.load().timeout(const Duration(seconds: 6));
    } catch (e) {
      debugPrint('Store load timed out or failed: $e');
    }
    if (mounted) setState(() => _loaded = true);
  }

  void _refresh() {
    setState(() {});
  }

  void _switchTab(int i) => setState(() {
        _tab = i;
        if (i == 1) _invoiceTab = 0;
      });
  void _openInvoices(int filterTab) => setState(() {
        _invoiceTab = filterTab.clamp(0, 3);
        _tab = 1;
      });

  void _newInvoice() {
    Store.i.create().then((inv) {
      if (!mounted) return;
      Navigator.push(
          context,
          slideRoute(CreatePage(
            invoice: inv,
            onSaved: (v) async {
              await Store.i.add(v);
              _refresh();
            },
          ))).then((_) => _refresh());
    });
  }

  Future<void> _newClient() async {
    final c = await Navigator.push<Customer>(
        context, slideRoute(const ClientFormPage()));
    if (c == null || c.name.trim().isEmpty) return;
    await Store.i.saveClient(c);
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return Scaffold(
          backgroundColor: T.bg(context),
          body: const SafeArea(child: _SkeletonLoader()));
    }
    final pages = [
      DashboardPage(
          onSeeAll: () => _openInvoices(0), onOpenInvoices: _openInvoices),
      InvoicesPage(
        key: ValueKey(_invoiceTab),
        onRefresh: _refresh,
        initialTab: _invoiceTab,
      ),
      ClientsPage(onAddClient: _newClient),
    ];

    return Scaffold(
      backgroundColor: T.bg(context),
      body: IndexedStack(
        index: _tab,
        children: pages,
      ),
      bottomNavigationBar: _BottomNav(
        tab: _tab,
        onTap: (i) {
          if (i == _tab) return;
          _switchTab(i);
        },
      ),
      floatingActionButton: (_tab == 1 || _tab == 2)
          ? SizedBox(
              width: 50,
              height: 50,
              child: FloatingActionButton(
                heroTag: _tab == 1 ? 'invoice_fab' : 'client_fab',
                tooltip: _tab == 1 ? 'Create invoice' : 'Add client',
                onPressed: _tab == 1 ? _newInvoice : () => _newClient(),
                backgroundColor: T.inverse(context),
                foregroundColor: T.onInverse(context),
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                child: const Icon(Icons.add_rounded, size: 24),
              ),
            )
          : null,
    );
  }
}

// ─── Bottom Nav ──────────────────────────────────────────────────

class _BottomNav extends StatelessWidget {
  final int tab;
  final void Function(int) onTap;
  const _BottomNav({required this.tab, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Container(
      height: 84 + bottom,
      color: T.bg(context),
      padding: EdgeInsets.fromLTRB(18, 8, 18, 12 + bottom),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: T.raised(context),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: T.border(context), width: 0.5),
          boxShadow: T.shadow(context),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final itemW = constraints.maxWidth / 3;
              final indicatorW = itemW - 18;
              return Stack(
                children: [
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 220),
                    curve: kSmooth,
                    left: tab * itemW + 9,
                    top: 9,
                    width: indicatorW,
                    height: 46,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: T.inverse(context),
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      Expanded(
                          child: _NavItem(
                              icon: Icons.home_rounded,
                              label: 'Home',
                              i: 0,
                              tab: tab,
                              onTap: onTap)),
                      Expanded(
                          child: _NavItem(
                              icon: Icons.receipt_long_rounded,
                              label: 'Invoices',
                              i: 1,
                              tab: tab,
                              onTap: onTap)),
                      Expanded(
                          child: _NavItem(
                              icon: Icons.groups_2_rounded,
                              label: 'Clients',
                              i: 2,
                              tab: tab,
                              onTap: onTap)),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final int i, tab;
  final void Function(int) onTap;
  const _NavItem(
      {required this.icon,
      required this.label,
      required this.i,
      required this.tab,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    final active = i == tab;

    return Tooltip(
      message: label,
      child: Semantics(
        button: true,
        selected: active,
        label: label,
        child: GestureDetector(
          onTap: () {
            if (active) return;
            HapticFeedback.selectionClick();
            onTap(i);
          },
          behavior: HitTestBehavior.opaque,
          child: SizedBox(
            height: 64,
            child: Center(
              child: AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 180),
                curve: kSmooth,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: active ? T.onInverse(context) : Colors.transparent,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AnimatedScale(
                      duration: const Duration(milliseconds: 180),
                      curve: kSmooth,
                      scale: active ? 1.0 : 0.96,
                      child: Icon(
                        icon,
                        size: 21,
                        color: active ? T.onInverse(context) : T.faint(context),
                      ),
                    ),
                    ClipRect(
                      child: AnimatedSize(
                        duration: const Duration(milliseconds: 180),
                        curve: kSmooth,
                        alignment: Alignment.centerLeft,
                        child: SizedBox(
                          width: active ? 62 : 0,
                          child: Padding(
                            padding: const EdgeInsets.only(left: 8),
                            child: Text(
                              label,
                              maxLines: 1,
                              overflow: TextOverflow.clip,
                              softWrap: false,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Skeleton Loader ─────────────────────────────────────────────

class _SkeletonLoader extends StatefulWidget {
  const _SkeletonLoader();
  @override
  State<_SkeletonLoader> createState() => _SkeletonLoaderState();
}

class _SkeletonLoaderState extends State<_SkeletonLoader>
    with SingleTickerProviderStateMixin {
  late AnimationController _ac;
  late Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _ac = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
    _pulse = Tween(begin: 0.3, end: 0.6)
        .animate(CurvedAnimation(parent: _ac, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ac.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _pulse,
        builder: (_, __) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _bar(140, 22, _pulse.value),
            const SizedBox(height: 28),
            ...[1, 0.9, 0.8, 0.7, 0.6].map((op) => Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Row(children: [
                    _circle(36, _pulse.value * op),
                    const SizedBox(width: 14),
                    Expanded(
                        child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _bar(120, 12, _pulse.value * op),
                        const SizedBox(height: 8),
                        _bar(80, 10, _pulse.value * op * 0.7),
                      ],
                    )),
                    _bar(48, 12, _pulse.value * op * 0.8),
                  ]),
                )),
          ]),
        ),
      );

  Widget _bar(double w, double h, double opacity) => Container(
        width: w,
        height: h,
        decoration: BoxDecoration(
          color: T.text(context).withValues(alpha: opacity),
          borderRadius: BorderRadius.circular(6),
        ),
      );

  Widget _circle(double size, double opacity) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: T.text(context).withValues(alpha: opacity),
        ),
      );
}
