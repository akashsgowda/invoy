import 'package:flutter/material.dart';
import '../theme.dart';
import '../models.dart';
import '../widgets.dart';
import '../data_export.dart';
import 'templates.dart';

enum SettingsSection { general, appearance, defaults, data }

class SettingsPage extends StatefulWidget {
  final SettingsSection section;
  const SettingsPage({super.key, this.section = SettingsSection.general});
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  @override
  Widget build(BuildContext context) {
    final title = switch (widget.section) {
      SettingsSection.appearance => 'Appearance',
      SettingsSection.defaults => 'Invoice Defaults',
      SettingsSection.data => 'Data & Backup',
      SettingsSection.general => 'App Preferences',
    };
    final showAppearance = widget.section == SettingsSection.appearance;
    final showDefaults = widget.section == SettingsSection.defaults;
    final showData = widget.section == SettingsSection.data;
    final showGeneral = widget.section == SettingsSection.general;

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
          title,
          style: TextStyle(
            color: T.text(context),
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 88),
        children: [
          // ── Appearance ──
          if (showAppearance) ...[
            _sLabel('Appearance'),
            _block([
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Theme',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: T.text(context),
                      ),
                    ),
                    const SizedBox(height: 14),
                    _ThemeToggle(onChanged: () => setState(() {})),
                  ],
                ),
              ),
            ]),
            const SizedBox(height: 28),
          ],

          // ── Invoice defaults ──
          if (showDefaults) ...[
            _sLabel('Invoice defaults'),
            _block([
              _picker(
                'Default GST rate',
                Prefs.defaultGst == 0
                    ? 'No GST'
                    : '${Prefs.defaultGst.toStringAsFixed(0)}%',
                onTap: _pickGst,
              ),
              if (Prefs.defaultGst > 0) ...[
                _div(),
                _toggle(
                  'Default tax type: CGST + SGST',
                  Prefs.splitGst,
                  (v) async {
                    await Prefs.setSplitGst(v);
                    if (!mounted) return;
                    setState(() {});
                  },
                  sub: 'Turn off for IGST on interstate invoices',
                ),
              ],
              _div(),
              _picker(
                'Payment terms',
                _termsLabel(Prefs.defaultTermDays),
                onTap: _pickTerms,
              ),
              _div(),
              _picker(
                'PDF style',
                Prefs.defaultTemplate.value,
                onTap: _openTemplates,
              ),
            ]),
            const SizedBox(height: 28),
          ],

          // ── Data ──
          if (showData) ...[
            _sLabel('Data'),
            _block([
              _dataSafety(),
              _div(),
              _action('Export invoices', 'CSV file', onTap: _exportCsv),
              _div(),
              _action('GST summary', 'CSV report', onTap: _exportGstSummary),
              _div(),
              _action('Backup app data', 'Full restore file',
                  onTap: _backupData),
              _div(),
              _action(
                'Restore backup',
                'Replace local data',
                onTap: _restoreBackup,
              ),
            ]),
            const SizedBox(height: 28),
          ],

          // ── About ──
          if (showGeneral) ...[
            _sLabel('Home'),
            _block([
              _picker(
                'Start screen',
                _startScreenLabel(Prefs.startTab),
                onTap: _pickStartScreen,
              ),
              _div(),
              _toggle(
                'Show recent invoices',
                Prefs.showDashboardRecent,
                (v) async {
                  await Prefs.setShowDashboardRecent(v);
                  if (!mounted) return;
                  setState(() {});
                },
                sub: 'Hide this for a cleaner Quick Invoice dashboard.',
              ),
            ]),
            const SizedBox(height: 28),
            _sLabel('Interaction'),
            _block([
              _toggle(
                'Haptics',
                Prefs.haptics,
                (v) async {
                  await Prefs.setHaptics(v);
                  if (!mounted) return;
                  setState(() {});
                },
                sub: 'Small vibration feedback on taps.',
              ),
              _div(),
              _toggle(
                'Reduce motion',
                Prefs.reduceMotion,
                (v) async {
                  await Prefs.setReduceMotion(v);
                  if (!mounted) return;
                  setState(() {});
                },
                sub: 'Use shorter transitions and calmer tap effects.',
              ),
            ]),
            const SizedBox(height: 28),
            _sLabel('App'),
            _block([
              _info('Version', '1.0.0'),
              _div(),
              SpringTap(
                onTap: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (_) => AlertDialog(
                      backgroundColor: T.card(context),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      title: Text(
                        'Reset app?',
                        style: TextStyle(
                          color: T.text(context),
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                      content: Text(
                        'Clears onboarding. Your data stays.',
                        style: TextStyle(color: T.muted(context), fontSize: 14),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: Text(
                            'Cancel',
                            style: TextStyle(color: T.faint(context)),
                          ),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text(
                            'Reset',
                            style: TextStyle(
                              color: C.overdue,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                  if (confirm == true) {
                    await Prefs.update('onboarded', '0');
                    Prefs.onboarded.value = false;
                    if (!context.mounted) return;
                    Navigator.pop(context);
                  }
                },
                scale: 0.985,
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 17),
                  child: Row(
                    children: [
                      Text(
                        'Reset onboarding',
                        style: TextStyle(fontSize: 14, color: C.overdue),
                      ),
                      Spacer(),
                      Icon(
                        Icons.chevron_right_rounded,
                        size: 18,
                        color: C.overdue,
                      ),
                    ],
                  ),
                ),
              ),
            ]),
          ],

          const SizedBox(height: 12),
        ],
      ),
    );
  }

  // ── Pickers ──────────────────────────────────────────────────

  String _termsLabel(int d) {
    switch (d) {
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
        return 'Net $d';
    }
  }

  String _startScreenLabel(int tab) {
    switch (tab.clamp(0, 2)) {
      case 1:
        return 'Invoices';
      case 2:
        return 'Clients';
      default:
        return 'Home';
    }
  }

  void _pickStartScreen() async {
    final labels = ['Home', 'Invoices', 'Clients'];
    final result = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _PickerSheet(
        title: 'Start screen',
        items: labels,
        sel: Prefs.startTab.clamp(0, 2),
      ),
    );
    if (result != null) {
      await Prefs.setStartTab(result);
      if (!mounted) return;
      setState(() {});
    }
  }

  void _pickTerms() async {
    final opts = [0, 7, 14, 30, 60];
    final labels = opts.map(_termsLabel).toList();
    final result = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _PickerSheet(
        title: 'Payment terms',
        items: labels,
        sel: opts.indexOf(Prefs.defaultTermDays),
      ),
    );
    if (result != null) {
      await Prefs.setDefaultTermDays(opts[result]);
      if (!mounted) return;
      setState(() {});
    }
  }

  void _pickGst() async {
    final opts = [0.0, 5.0, 12.0, 18.0, 28.0];
    final labels = ['No GST', '5%', '12%', '18%', '28%'];
    final result = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _PickerSheet(
        title: 'Default GST rate',
        items: labels,
        sel: opts.indexWhere((v) => v == Prefs.defaultGst).clamp(0, 4),
      ),
    );
    if (result != null) {
      await Prefs.setDefaultGst(opts[result]);
      if (!mounted) return;
      setState(() {});
    }
  }

  void _openTemplates() {
    Navigator.push(context, slideRoute(const TemplatesPage())).then((_) {
      if (mounted) setState(() {});
    });
  }

  Future<void> _exportCsv() async {
    final action = await _pickDataAction('Export invoices');
    if (action == null) return;
    try {
      final path = action == _DataAction.save
          ? await exportInvoicesCsv()
          : await shareInvoicesCsv();
      if (!mounted) return;
      showAppSnack(
        context,
        action == _DataAction.save
            ? _savedMessage(path, 'CSV saved')
            : 'CSV ready to share',
      );
    } catch (_) {
      if (!mounted) return;
      showAppSnack(context, 'Could not export CSV');
    }
  }

  Future<void> _backupData() async {
    final action = await _pickDataAction('Backup app data');
    if (action == null) return;
    try {
      final backedUpAt = DateTime.now();
      final path = action == _DataAction.save
          ? await exportBackupJson(backedUpAt: backedUpAt)
          : await shareBackupJson(backedUpAt: backedUpAt);
      await Prefs.setLastBackupAt(backedUpAt);
      if (!mounted) return;
      setState(() {});
      showAppSnack(
        context,
        action == _DataAction.save
            ? _savedMessage(path, 'Backup saved')
            : 'Backup ready to share',
      );
    } catch (_) {
      if (!mounted) return;
      showAppSnack(context, 'Could not create backup');
    }
  }

  Future<void> _exportGstSummary() async {
    final action = await _pickDataAction('GST summary');
    if (action == null) return;
    try {
      final path = action == _DataAction.save
          ? await exportGstSummaryCsv()
          : await shareGstSummaryCsv();
      if (!mounted) return;
      showAppSnack(
        context,
        action == _DataAction.save
            ? _savedMessage(path, 'GST summary saved')
            : 'GST summary ready to share',
      );
    } catch (_) {
      if (!mounted) return;
      showAppSnack(context, 'Could not export GST summary');
    }
  }

  Future<void> _restoreBackup() async {
    try {
      final preview = await pickBackupPreview();
      if (preview == null) return;
      if (!mounted) return;

      final confirm = await _confirmRestore(preview);
      if (confirm != true) return;

      await Store.i.restoreBackup(
        invoices: preview.invoices,
        clients: preview.clients,
        savedItems: preview.savedItems,
        prefs: preview.prefs,
      );
      if (!mounted) return;
      setState(() {});
      showAppSnack(context, 'Backup restored');
    } on FormatException {
      if (!mounted) return;
      showAppSnack(context, 'That backup file looks invalid');
    } catch (_) {
      if (!mounted) return;
      showAppSnack(context, 'Could not restore backup');
    }
  }

  Future<bool?> _confirmRestore(BackupPreview preview) {
    final name = preview.path.split('/').last;
    final date = preview.createdAt == null ? null : fDate(preview.createdAt!);
    return showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => AppSheet(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Restore backup?',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: T.text(context),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'This replaces the current invoices, clients, settings and payment QR on this device. Export a backup first if you want to keep the current data.',
              style: TextStyle(
                fontSize: 13,
                height: 1.45,
                color: T.muted(context),
              ),
            ),
            const SizedBox(height: 18),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: T.card(context),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: T.border(context), width: 0.5),
              ),
              child: Column(
                children: [
                  _restoreRow('File', name),
                  const SizedBox(height: 10),
                  _restoreRow('Invoices', '${preview.invoiceCount}'),
                  const SizedBox(height: 10),
                  _restoreRow('Clients', '${preview.clientCount}'),
                  if (preview.savedItems.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    _restoreRow('Saved items', '${preview.savedItems.length}'),
                  ],
                  if (date != null) ...[
                    const SizedBox(height: 10),
                    _restoreRow('Created', date),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: AppButton(
                    label: 'Cancel',
                    onTap: () => Navigator.pop(context, false),
                    tone: AppButtonTone.secondary,
                    height: 50,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AppButton(
                    label: 'Restore',
                    onTap: () => Navigator.pop(context, true),
                    height: 50,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _restoreRow(String label, String value) => Row(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: T.muted(context),
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
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: T.text(context),
              ),
            ),
          ),
        ],
      );

  String _savedMessage(String path, String fallback) {
    return path.contains('/Download') ? '$fallback to Downloads' : fallback;
  }

  String get _lastBackupLabel {
    final raw = Prefs.lastBackupAt.value;
    final date = DateTime.tryParse(raw);
    if (date == null) return 'Never';
    return fDate(date);
  }

  Future<_DataAction?> _pickDataAction(String title) {
    return showModalBottomSheet<_DataAction>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => AppSheet(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: T.text(context),
              ),
            ),
            const SizedBox(height: 16),
            _sheetAction(
              icon: Icons.save_alt_rounded,
              title: 'Save to Downloads',
              subtitle: 'Keep a file on this device',
              onTap: () => Navigator.pop(context, _DataAction.save),
            ),
            Divider(height: 1, color: T.divider(context)),
            _sheetAction(
              icon: Icons.near_me_rounded,
              title: 'Share file',
              subtitle: 'Send using another app',
              onTap: () => Navigator.pop(context, _DataAction.share),
            ),
          ],
        ),
      ),
    );
  }

  // ── Helpers ──────────────────────────────────────────────────

  Widget _sLabel(String t) => Padding(
        padding: const EdgeInsets.fromLTRB(0, 0, 0, 10),
        child: Text(
          t,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: T.muted(context),
            letterSpacing: 0,
          ),
        ),
      );

  Widget _block(List<Widget> children) => Container(
        decoration: BoxDecoration(
          color:
              T.card(context).withValues(alpha: T.dark(context) ? 0.72 : 0.92),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: T.border(context).withValues(alpha: 0.68),
            width: 0.5,
          ),
          boxShadow: T.dark(context) ? const [] : T.softShadow(context),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(children: children),
      );

  Widget _div() =>
      Divider(height: 1, indent: 16, endIndent: 16, color: T.divider(context));

  Widget _dataSafety() => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Last backup',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: T.text(context),
                  ),
                ),
                const Spacer(),
                Text(
                  _lastBackupLabel,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: T.muted(context),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 5),
            Text(
              'Backup includes invoices, clients, saved items, settings and payment QR.',
              style: TextStyle(fontSize: 12, color: T.faint(context)),
            ),
          ],
        ),
      );

  Widget _toggle(
    String label,
    bool value,
    void Function(bool) onChanged, {
    String? sub,
  }) =>
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 14, 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight:
                          sub == null ? FontWeight.w400 : FontWeight.w600,
                      color: T.text(context),
                    ),
                  ),
                  if (sub != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      sub,
                      style: TextStyle(fontSize: 12, color: T.faint(context)),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            Switch.adaptive(
              value: value,
              onChanged: onChanged,
              activeThumbColor: T.onInverse(context),
              activeTrackColor: T.inverse(context),
              inactiveThumbColor: T.faint(context),
              inactiveTrackColor: T.border(context),
            ),
          ],
        ),
      );

  Widget _picker(String label, String value, {VoidCallback? onTap}) =>
      SpringTap(
        onTap: onTap,
        scale: 0.985,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 17),
          child: Row(
            children: [
              Expanded(
                flex: 2,
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 14, color: T.text(context)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 3,
                child: Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                  style: TextStyle(fontSize: 14, color: T.faint(context)),
                ),
              ),
              const SizedBox(width: 6),
              Icon(Icons.chevron_right_rounded,
                  size: 16, color: T.faint(context)),
            ],
          ),
        ),
      );

  Widget _info(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 17),
        child: Row(
          children: [
            Expanded(
              flex: 2,
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 14, color: T.text(context)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 3,
              child: Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.right,
                style: TextStyle(fontSize: 14, color: T.faint(context)),
              ),
            ),
          ],
        ),
      );

  Widget _action(String label, String value, {required VoidCallback onTap}) =>
      SpringTap(
        onTap: onTap,
        scale: 0.985,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 17),
          child: Row(
            children: [
              Expanded(
                flex: 2,
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 14, color: T.text(context)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 3,
                child: Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                  style: TextStyle(fontSize: 14, color: T.faint(context)),
                ),
              ),
              const SizedBox(width: 6),
              Icon(
                Icons.chevron_right_rounded,
                size: 16,
                color: T.faint(context),
              ),
            ],
          ),
        ),
      );

  Widget _sheetAction({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) =>
      SpringTap(
        onTap: onTap,
        scale: 0.975,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: T.subtle(context),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: T.border(context), width: 0.5),
                ),
                child: Icon(icon, size: 18, color: T.text(context)),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: T.text(context),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: TextStyle(fontSize: 12, color: T.muted(context)),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded,
                  size: 18, color: T.faint(context)),
            ],
          ),
        ),
      );
}

enum _DataAction { save, share }

// ── Theme Toggle ─────────────────────────────────────────────────

class _ThemeToggle extends StatefulWidget {
  final VoidCallback onChanged;
  const _ThemeToggle({required this.onChanged});
  @override
  State<_ThemeToggle> createState() => _ThemeToggleState();
}

class _ThemeToggleState extends State<_ThemeToggle> {
  @override
  Widget build(BuildContext context) {
    final options = [ThemeMode.light, ThemeMode.dark, ThemeMode.system];
    final labels = ['Light', 'Dark', 'Auto'];
    final current = Prefs.themeMode.value;
    final index = options.indexOf(current).clamp(0, 2);

    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: T.card(context).withValues(alpha: T.dark(context) ? 0.72 : 0.90),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: T.border(context).withValues(alpha: 0.68),
          width: 0.5,
        ),
        boxShadow: T.dark(context) ? const [] : T.softShadow(context),
      ),
      padding: const EdgeInsets.all(4),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final itemW = constraints.maxWidth / 3;
          return Stack(
            children: [
              AnimatedPositioned(
                duration: Prefs.reduceMotion
                    ? Duration.zero
                    : const Duration(milliseconds: 220),
                curve: kSmooth,
                left: itemW * index,
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
                children: List.generate(3, (i) {
                  final active = i == index;
                  return Expanded(
                    child: SpringTap(
                      scale: 0.955,
                      haptic: false,
                      onTap: () async {
                        if (active) return;
                        await Prefs.setTheme(options[i]);
                        if (!mounted) return;
                        setState(() {});
                        widget.onChanged();
                      },
                      child: Center(
                        child: AnimatedDefaultTextStyle(
                          duration: Prefs.reduceMotion
                              ? Duration.zero
                              : const Duration(milliseconds: 220),
                          curve: kSmooth,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight:
                                active ? FontWeight.w800 : FontWeight.w700,
                            color: active
                                ? T.onInverse(context)
                                : T.muted(context),
                          ),
                          child: Text(labels[i], textAlign: TextAlign.center),
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
    );
  }
}

// ── Picker Sheet ─────────────────────────────────────────────────

class _PickerSheet extends StatefulWidget {
  final String title;
  final List<String> items;
  final int sel;
  const _PickerSheet({
    required this.title,
    required this.items,
    required this.sel,
  });
  @override
  State<_PickerSheet> createState() => _PickerSheetState();
}

class _PickerSheetState extends State<_PickerSheet> {
  late int _sel;
  @override
  void initState() {
    super.initState();
    _sel = widget.sel;
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
          bottom: MediaQuery.of(context).viewInsets.bottom + 32,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 3,
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                color: T.border(context),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                widget.title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: T.text(context),
                ),
              ),
            ),
            const SizedBox(height: 16),
            ...widget.items.asMap().entries.map(
                  (e) => SpringTap(
                    onTap: () {
                      setState(() => _sel = e.key);
                      Navigator.pop(context, e.key);
                    },
                    scale: 0.975,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      child: Row(
                        children: [
                          Text(
                            e.value,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: e.key == _sel
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                              color: e.key == _sel
                                  ? T.text(context)
                                  : T.faint(context),
                            ),
                          ),
                          const Spacer(),
                          if (e.key == _sel)
                            Icon(Icons.check_rounded,
                                size: 16, color: T.text(context)),
                        ],
                      ),
                    ),
                  ),
                ),
          ],
        ),
      );
}

// ── Legacy alias ─────────────────────────────────────────────────

class SettingsSheet extends StatelessWidget {
  final VoidCallback onChanged;
  const SettingsSheet({super.key, required this.onChanged});
  @override
  Widget build(BuildContext context) => const SettingsPage();
}
