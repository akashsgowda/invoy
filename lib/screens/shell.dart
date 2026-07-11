import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme.dart';
import '../models.dart';
import '../widgets.dart';
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
  late int _tab = Prefs.startTab;
  int _invoiceTab = 0;
  int _invoiceNavigationRequest = 0;
  late final Widget _dashboardPage;
  late final Widget _clientsPage;
  bool _loaded = Store.i.isLoaded;
  bool _loadError = false;
  bool _openingInvoice = false;
  bool _openingClient = false;

  @override
  void initState() {
    super.initState();
    _dashboardPage = DashboardPage(
      onSeeAll: () => _openInvoices(0),
      onOpenInvoices: _openInvoices,
    );
    _clientsPage = ClientsPage(onAddClient: _newClient);
    if (_loaded) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_loadData());
    });
  }

  Future<void> _loadData() async {
    try {
      await Store.i.load().timeout(const Duration(seconds: 12));
      if (mounted) {
        setState(() {
          _loaded = true;
          _loadError = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loaded = true;
          _loadError = true;
        });
      }
    }
  }

  void _retryLoad() {
    setState(() {
      _loaded = false;
      _loadError = false;
    });
    unawaited(_loadData());
  }

  void _refresh() {
    if (!mounted) return;
    setState(() {});
  }

  void _switchTab(int i) {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _tab = i;
      if (i == 1) {
        _invoiceTab = 0;
        _invoiceNavigationRequest++;
      }
    });
  }

  void _openInvoices(int filterTab) {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _invoiceTab = filterTab.clamp(0, 3);
      _invoiceNavigationRequest++;
      _tab = 1;
    });
  }

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
      if (changed == true && mounted) _refresh();
    } finally {
      _openingInvoice = false;
    }
  }

  Future<void> _newClient() async {
    if (_openingClient) return;
    _openingClient = true;
    try {
      final c = await Navigator.push<Customer>(
        context,
        slideRoute(const ClientFormPage()),
      );
      if (c == null || c.name.trim().isEmpty) return;
      await Store.i.saveClient(c);
      if (!mounted) return;
      _refresh();
    } finally {
      _openingClient = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return Scaffold(
        backgroundColor: T.bg(context),
        body: const SafeArea(child: _SkeletonLoader()),
      );
    }
    if (_loadError) {
      return _ShellLoadError(onRetry: _retryLoad);
    }
    final pages = <Widget>[
      _dashboardPage,
      InvoicesPage(
        onRefresh: _refresh,
        initialTab: _invoiceTab,
        navigationRequest: _invoiceNavigationRequest,
      ),
      _clientsPage,
    ];

    return Scaffold(
      backgroundColor: T.bg(context),
      body: IndexedStack(
        index: _tab,
        children: List.generate(
          pages.length,
          (i) => TickerMode(
            enabled: i == _tab,
            child: RepaintBoundary(child: pages[i]),
          ),
        ),
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
              width: 56,
              height: 56,
              child: SpringTap(
                onTap: _tab == 1 ? _newInvoice : () => _newClient(),
                scale: 0.945,
                hoverScale: 1.012,
                child: Tooltip(
                  message: _tab == 1 ? 'Create invoice' : 'Add client',
                  child: Semantics(
                    button: true,
                    label: _tab == 1 ? 'Create invoice' : 'Add client',
                    child: Container(
                      decoration: BoxDecoration(
                        color: T.inverse(context),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: T.onInverse(context).withValues(alpha: 0.12),
                          width: 0.8,
                        ),
                        boxShadow: T.buttonShadow(context),
                      ),
                      child: Icon(
                        Icons.add_rounded,
                        size: 25,
                        color: T.onInverse(context),
                      ),
                    ),
                  ),
                ),
              ),
            )
          : null,
    );
  }
}

class _ShellLoadError extends StatelessWidget {
  final VoidCallback onRetry;
  const _ShellLoadError({required this.onRetry});

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: T.bg(context),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Spacer(),
                Text(
                  'Could not load invoices',
                  style: TextStyle(
                    color: T.text(context),
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Local data took too long to open. Try once more.',
                  style: TextStyle(
                    color: T.muted(context),
                    fontSize: 14,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 22),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: onRetry,
                    child: const Text('Retry'),
                  ),
                ),
                const Spacer(),
              ],
            ),
          ),
        ),
      );
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
      height: 80 + bottom,
      color: T.bg(context),
      padding: EdgeInsets.fromLTRB(18, 6, 18, 10 + bottom),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: T.dock(context),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: T.border(context), width: 0.55),
          boxShadow: T.shadow(context),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(29),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final itemW = constraints.maxWidth / 3;
              return Stack(
                children: [
                  AnimatedPositioned(
                    duration:
                        Prefs.reduceMotion ? Duration.zero : kSegmentDuration,
                    curve: kSmooth,
                    left: itemW * tab + 6,
                    top: 6,
                    bottom: 6,
                    width: itemW - 12,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: T.inverse(context),
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(
                          color: T.onInverse(context).withValues(alpha: 0.12),
                          width: 0.7,
                        ),
                        boxShadow: T.buttonShadow(context),
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
                          onTap: onTap,
                        ),
                      ),
                      Expanded(
                        child: _NavItem(
                          icon: Icons.receipt_long_rounded,
                          label: 'Invoices',
                          i: 1,
                          tab: tab,
                          onTap: onTap,
                        ),
                      ),
                      Expanded(
                        child: _NavItem(
                          icon: Icons.groups_2_rounded,
                          label: 'Clients',
                          i: 2,
                          tab: tab,
                          onTap: onTap,
                        ),
                      ),
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
  const _NavItem({
    required this.icon,
    required this.label,
    required this.i,
    required this.tab,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final active = i == tab;
    final inactiveColor = T.dark(context)
        ? T.text(context).withValues(alpha: 0.68)
        : T.text(context).withValues(alpha: 0.58);
    final fg = active ? T.onInverse(context) : inactiveColor;

    return Tooltip(
      message: label,
      child: Semantics(
        button: true,
        selected: active,
        label: label,
        child: SpringTap(
          haptic: false,
          onTap: () {
            if (Prefs.haptics) HapticFeedback.selectionClick();
            onTap(i);
          },
          scale: 0.955,
          hoverScale: 1.006,
          child: SizedBox(
            height: 62,
            child: Center(
              child: AnimatedDefaultTextStyle(
                duration:
                    Prefs.reduceMotion ? Duration.zero : kSegmentTextDuration,
                curve: kSmooth,
                style: TextStyle(
                  color: fg,
                  fontSize: 11,
                  fontWeight: active ? FontWeight.w900 : FontWeight.w700,
                  letterSpacing: 0,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TweenAnimationBuilder<Color?>(
                      duration: Prefs.reduceMotion
                          ? Duration.zero
                          : kSegmentTextDuration,
                      curve: kSmooth,
                      tween: ColorTween(end: fg),
                      builder: (_, color, __) =>
                          Icon(icon, size: 18.5, color: color),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.clip,
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
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _pulse = Tween(
      begin: 0.3,
      end: 0.6,
    ).animate(CurvedAnimation(parent: _ac, curve: Curves.easeInOut));
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _bar(140, 22, _pulse.value),
              const SizedBox(height: 28),
              ...[1, 0.9, 0.8, 0.7, 0.6].map(
                (op) => Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Row(
                    children: [
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
                        ),
                      ),
                      _bar(48, 12, _pulse.value * op * 0.8),
                    ],
                  ),
                ),
              ),
            ],
          ),
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
