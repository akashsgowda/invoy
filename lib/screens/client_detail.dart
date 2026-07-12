import 'package:flutter/material.dart';
import '../theme.dart';
import '../models.dart';
import '../widgets.dart';
import 'client_form.dart';
import 'create.dart';
import 'detail.dart';

class ClientDetailPage extends StatefulWidget {
  final String name, email, phone, address, gstin, state;
  final VoidCallback onRefresh;
  const ClientDetailPage({
    super.key,
    required this.name,
    required this.email,
    required this.phone,
    required this.address,
    this.gstin = '',
    this.state = '',
    required this.onRefresh,
  });
  @override
  State<ClientDetailPage> createState() => _ClientDetailPageState();
}

class _ClientDetailPageState extends State<ClientDetailPage> {
  late Customer _client;
  bool _openingInvoice = false;

  @override
  void initState() {
    super.initState();
    _client = Customer(
      name: widget.name,
      email: widget.email,
      phone: widget.phone,
      address: widget.address,
      gstin: widget.gstin,
      state: widget.state,
    );
  }

  // Getters removed for performance (computed locally in build)

  String get _initials {
    final parts =
        _client.name.trim().split(' ').where((w) => w.isNotEmpty).toList();
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return _client.name.isEmpty ? '?' : _client.name[0].toUpperCase();
  }

  Color get _avatarColor =>
      C.avatarColors[_client.name.hashCode.abs() % C.avatarColors.length];

  Future<void> _newInvoice() async {
    if (_openingInvoice) return;
    _openingInvoice = true;
    try {
      final inv = await Store.i.create();
      inv.client = _client.copy();
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
      if (changed == true && mounted) {
        setState(() {});
        widget.onRefresh();
      }
    } finally {
      _openingInvoice = false;
    }
  }

  Future<void> _editClient() async {
    final oldClient = _client.copy();
    final updated = await Navigator.push<Customer>(
      context,
      slideRoute(ClientFormPage(client: _client)),
    );
    if (!mounted) return;
    if (updated == null || updated.name.trim().isEmpty) return;
    try {
      await Store.i.updateClient(oldClient, updated);
      if (!mounted) return;
      widget.onRefresh();
      setState(() => _client = updated.copy());
      showAppSnack(context, 'Client updated');
    } catch (_) {
      if (mounted) showAppSnack(context, "Couldn't update this client");
    }
  }

  Future<void> _deleteClient() async {
    final key = _client.name.trim().toLowerCase();
    final hasInvoices = Store.i.all.any((i) => i.client.name.trim().toLowerCase() == key);
    if (hasInvoices) {
      showAppSnack(context, 'Clients with invoice history cannot be deleted');
      return;
    }
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: T.card(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Delete client?',
          style: TextStyle(
            color: T.text(context),
            fontWeight: FontWeight.w700,
            fontSize: 17,
          ),
        ),
        content: Text(
          'This permanently removes this saved client.',
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
      await Store.i.deleteClient(_client);
      if (!mounted) return;
      widget.onRefresh();
      final messenger = ScaffoldMessenger.of(context);
      final snack = appSnackBar(context, 'Client deleted');
      Navigator.pop(context);
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(snack);
    } catch (_) {
      if (mounted) showAppSnack(context, "Couldn't delete this client");
    }
  }

  @override
  Widget build(BuildContext context) {
    final key = _client.name.trim().toLowerCase();
    final invoices = Store.i.all.where((i) => i.client.name.trim().toLowerCase() == key).toList();
    final issuedInvoices = invoices.where((inv) => inv.displayStatus != Status.draft).toList();
    final totalInvoiced = issuedInvoices.fold(0.0, (sum, inv) => sum + inv.total);
    final totalRevenue = issuedInvoices.fold(0.0, (sum, inv) => sum + inv.collectedAmt);
    final outstanding = issuedInvoices.where((inv) => inv.displayStatus != Status.paid).fold(0.0, (sum, inv) => sum + inv.balance);

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
        title: Text(
          'Client',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: T.text(context),
          ),
        ),
        centerTitle: true,
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Client actions',
            icon: Icon(
              Icons.more_horiz_rounded,
              color: T.muted(context),
              size: 20,
            ),
            color: T.card(context),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            onSelected: (v) {
              if (v == 'edit') _editClient();
              if (v == 'delete') _deleteClient();
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'edit',
                child: Row(
                  children: [
                    Icon(Icons.edit_outlined, size: 16, color: T.text(context)),
                    const SizedBox(width: 10),
                    Text(
                      'Edit',
                      style: TextStyle(fontSize: 14, color: T.text(context)),
                    ),
                  ],
                ),
              ),
              if (invoices.isEmpty)
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete_outline, size: 16, color: C.overdue),
                      SizedBox(width: 10),
                      Text(
                        'Delete client',
                        style: TextStyle(fontSize: 14, color: C.overdue),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 120),
        children: [
          // ── Header ──
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 28),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 32,
                  backgroundColor: _avatarColor,
                  child: Text(
                    _initials,
                    style: const TextStyle(
                      color: C.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  _client.name,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: T.text(context),
                    letterSpacing: 0,
                  ),
                ),
                if (_client.email.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    _client.email,
                    style: TextStyle(fontSize: 13, color: T.muted(context)),
                  ),
                ],
                if (_client.phone.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    _client.phone,
                    style: TextStyle(fontSize: 13, color: T.muted(context)),
                  ),
                ],
              ],
            ),
          ),

          // ── Statement ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _statementCard(issuedInvoices.length, totalInvoiced, totalRevenue, outstanding),
          ),

          const SizedBox(height: 24),

          // ── Contact info ──
          if (_client.address.isNotEmpty ||
              _client.gstin.isNotEmpty ||
              _client.state.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                decoration: BoxDecoration(
                  color: T.card(context),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: T.border(context), width: 0.5),
                ),
                child: Column(
                  children: [
                    if (_client.email.isNotEmpty)
                      _infoRow(Icons.mail_outline_rounded, _client.email),
                    if (_client.email.isNotEmpty &&
                        (_client.address.isNotEmpty ||
                            _client.gstin.isNotEmpty))
                      Divider(height: 1, color: T.divider(context), indent: 52),
                    if (_client.address.isNotEmpty)
                      _infoRow(Icons.location_on_outlined, _client.address),
                    if (_client.address.isNotEmpty &&
                        (_client.gstin.isNotEmpty || _client.state.isNotEmpty))
                      Divider(height: 1, color: T.divider(context), indent: 52),
                    if (_client.state.isNotEmpty)
                      _infoRow(Icons.map_outlined, _client.state),
                    if (_client.state.isNotEmpty && _client.gstin.isNotEmpty)
                      Divider(height: 1, color: T.divider(context), indent: 52),
                    if (_client.gstin.isNotEmpty)
                      _infoRow(
                        Icons.receipt_long_outlined,
                        'GSTIN ${_client.gstin}',
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],

          // ── Invoices ──
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
            child: Text(
              'Invoices',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: T.muted(context),
                letterSpacing: 0.2,
              ),
            ),
          ),
          if (invoices.isEmpty)
            const EmptyState(
              icon: Icons.receipt_long_outlined,
              message: 'No invoices for this client',
              subtitle: 'Create an invoice when work starts.',
            )
          else
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: T.card(context),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: T.border(context), width: 0.5),
              ),
              child: Column(
                children: invoices.asMap().entries.map((e) {
                  final inv = e.value;
                  final isLast = e.key == invoices.length - 1;
                  return Column(
                    children: [
                      SpringTap(
                        onTap: () => Navigator.push(
                          context,
                          slideRoute(
                            DetailPage(
                              invoice: inv,
                              onRefresh: () {
                                if (!mounted) return;
                                setState(() {});
                                widget.onRefresh();
                              },
                            ),
                          ),
                        ),
                        scale: 0.99,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      inv.displayNumber,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: T.text(context),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      inv.isPartPaid
                                          ? '${amtK(inv.balance)} balance due'
                                          : inv.dueDateText,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color:
                                            inv.displayStatus == Status.overdue
                                                ? C.overdue
                                                : T.muted(context),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    inv.isPartPaid
                                        ? amtK(inv.balance)
                                        : amtK(inv.total),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: T.text(context),
                                    ),
                                  ),
                                  const SizedBox(height: 5),
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
                          indent: 16,
                        ),
                    ],
                  );
                }).toList(),
              ),
            ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: AppButton(
            label: 'Create Invoice',
            onTap: _newInvoice,
          ),
        ),
      ),
    );
  }

  Widget _statementCard(int issuedCount, double totalInvoiced, double totalRevenue, double outstanding) => Container(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 15),
        decoration: BoxDecoration(
          color: T.card(context),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: T.border(context), width: 0.5),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Statement',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: T.text(context),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Flexible(
                  child: Text(
                    '$issuedCount issued',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.right,
                    style: TextStyle(fontSize: 12, color: T.muted(context)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _statementRow('Billed', amtUi(totalInvoiced), outstanding),
            const SizedBox(height: 9),
            _statementRow('Received', amtUi(totalRevenue), outstanding),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Divider(height: 1, color: T.divider(context)),
            ),
            _statementRow('Balance', amtUi(outstanding), outstanding, strong: true),
          ],
        ),
      );

  Widget _statementRow(String label, String value, double outstanding, {bool strong = false}) =>
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
                color: strong && outstanding > 0
                    ? T.text(context)
                    : T.text(context),
              ),
            ),
          ),
        ],
      );

  Widget _infoRow(IconData icon, String text) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 16, color: T.muted(context)),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                text,
                style: TextStyle(fontSize: 13, color: T.text(context)),
              ),
            ),
          ],
        ),
      );
}
