import 'package:flutter/material.dart';
import '../theme.dart';
import '../models.dart';
import '../widgets.dart';
import 'client_detail.dart';

class ClientsPage extends StatefulWidget {
  final VoidCallback onAddClient;
  const ClientsPage({super.key, required this.onAddClient});

  @override
  State<ClientsPage> createState() => _ClientsPageState();
}

class _ClientsPageState extends State<ClientsPage> {
  final _searchC = TextEditingController();
  final _searchFocus = FocusNode();
  String _q = '';

  @override
  void initState() {
    super.initState();
    _searchFocus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _searchFocus.dispose();
    _searchC.dispose();
    super.dispose();
  }

  List<_ClientSummary> get _clients {
    final map = <String, _ClientSummary>{};

    for (final c in Store.i.clients) {
      if (c.name.isEmpty) continue;
      map[c.name.trim().toLowerCase()] = _ClientSummary(
        name: c.name,
        email: c.email,
        phone: c.phone,
        address: c.address,
        gstin: c.gstin,
      );
    }

    for (final inv in Store.i.all) {
      if (inv.client.name.isEmpty) continue;
      final k = inv.client.name.trim().toLowerCase();
      final s = map.putIfAbsent(
          k,
          () => _ClientSummary(
                name: inv.client.name,
                email: inv.client.email,
                phone: inv.client.phone,
                address: inv.client.address,
                gstin: inv.client.gstin,
              ));
      s.total++;
      if (inv.displayStatus == Status.paid) {
        s.paidCount++;
      } else {
        s.unpaidAmt += inv.balance;
      }
    }
    final list = map.values.toList()..sort((a, b) => a.name.compareTo(b.name));
    if (_q.isEmpty) return list;
    final q = _q.toLowerCase();
    return list
        .where((c) =>
            c.name.toLowerCase().contains(q) ||
            c.email.toLowerCase().contains(q))
        .toList();
  }

  void _openDetail(_ClientSummary c) {
    Navigator.push(
        context,
        slideRoute(ClientDetailPage(
          name: c.name,
          email: c.email,
          phone: c.phone,
          address: c.address,
          gstin: c.gstin,
          onRefresh: () => setState(() {}),
        )));
  }

  @override
  Widget build(BuildContext context) {
    final list = _clients;

    return Scaffold(
      backgroundColor: T.bg(context),
      body: SafeArea(
        child: Column(children: [
          // ── Top bar ──
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Row(children: [
              Text('Clients',
                  style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      color: T.text(context),
                      letterSpacing: 0)),
            ]),
          ),

          const SizedBox(height: 14),

          // ── Search ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: kSmooth,
              height: 48,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color:
                    _searchFocus.hasFocus ? T.card(context) : T.subtle(context),
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
                    color: _searchFocus.hasFocus
                        ? T.text(context)
                        : T.muted(context)),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    focusNode: _searchFocus,
                    controller: _searchC,
                    onChanged: (v) => setState(() => _q = v),
                    style: TextStyle(color: T.text(context), fontSize: 14),
                    decoration: InputDecoration(
                      isCollapsed: true,
                      filled: false,
                      hintText: 'Search clients…',
                      hintStyle:
                          TextStyle(color: T.faint(context), fontSize: 14),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      disabledBorder: InputBorder.none,
                    ),
                  ),
                ),
                if (_q.isNotEmpty)
                  IconButton(
                    tooltip: 'Clear search',
                    icon: const Icon(Icons.close_rounded,
                        size: 15, color: C.grey5),
                    onPressed: () {
                      _searchC.clear();
                      setState(() => _q = '');
                    },
                  )
                else
                  const SizedBox(width: 14),
              ]),
            ),
          ),

          const SizedBox(height: 12),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(children: [
              Text(
                '${list.length} client${list.length == 1 ? '' : 's'}',
                style: TextStyle(fontSize: 13, color: T.muted(context)),
              ),
            ]),
          ),

          const SizedBox(height: 12),

          // ── List ──
          Expanded(
            child: list.isEmpty
                ? _emptyState()
                : ListView.separated(
                    padding: const EdgeInsets.only(bottom: 100),
                    itemCount: list.length,
                    separatorBuilder: (_, __) => Divider(
                        height: 1, color: T.divider(context), indent: 20),
                    itemBuilder: (_, i) => _ClientRow(
                      client: list[i],
                      onTap: () => _openDetail(list[i]),
                    ),
                  ),
          ),
        ]),
      ),
    );
  }

  Widget _emptyState() => EmptyState(
        icon: Icons.people_outline_rounded,
        message: _q.isNotEmpty ? 'No clients match "$_q"' : 'No clients yet',
        subtitle: _q.isEmpty
            ? 'Save regular customers once and reuse them in invoices.'
            : 'Try a different name or email.',
        ctaLabel: _q.isEmpty ? 'Add client' : null,
        ctaOnTap: _q.isEmpty ? widget.onAddClient : null,
      );
}

// ── Client row ────────────────────────────────────────────────────

class _ClientRow extends StatelessWidget {
  final _ClientSummary client;
  final VoidCallback onTap;
  const _ClientRow({required this.client, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final hasOutstanding = client.unpaidAmt > 0;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(children: [
          // Avatar
          CircleAvatar(
            radius: 18,
            backgroundColor: T.subtle(context),
            child: Text(client.initials,
                style: TextStyle(
                    color: T.text(context),
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
          ),
          const SizedBox(width: 14),

          // Name + count
          Expanded(
              child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(client.name,
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: T.text(context))),
              const SizedBox(height: 3),
              Text('${client.total} invoice${client.total == 1 ? '' : 's'}',
                  style: TextStyle(fontSize: 12, color: T.muted(context))),
            ],
          )),

          // Outstanding
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(
              hasOutstanding ? amtK(client.unpaidAmt) : 'No due',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: hasOutstanding ? C.overdue : T.faint(context)),
            ),
            if (hasOutstanding)
              const Text('due',
                  style: TextStyle(fontSize: 10, color: C.overdue)),
          ]),

          const SizedBox(width: 10),
          Icon(Icons.chevron_right_rounded, size: 18, color: T.faint(context)),
        ]),
      ),
    );
  }
}

// ── Data model ────────────────────────────────────────────────────

class _ClientSummary {
  final String name, email, phone, address, gstin;
  int total = 0, paidCount = 0;
  double unpaidAmt = 0;
  _ClientSummary(
      {required this.name,
      required this.email,
      required this.phone,
      required this.address,
      required this.gstin});

  String get initials {
    final parts = name.trim().split(' ').where((w) => w.isNotEmpty).toList();
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();
  }
}
