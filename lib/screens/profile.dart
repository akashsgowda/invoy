import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme.dart';
import '../models.dart';
import '../widgets.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});
  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  bool _editing = false;
  late final TextEditingController _nameC, _bizC, _gstC, _upiC, _prefixC;

  @override
  void initState() {
    super.initState();
    _nameC = TextEditingController(text: Prefs.yourName.value);
    _bizC = TextEditingController(text: Prefs.bizName.value);
    _gstC = TextEditingController(text: Prefs.gstNum.value);
    _upiC = TextEditingController(text: Prefs.upiId.value);
    _prefixC = TextEditingController(text: Prefs.invPrefix.value);
  }

  @override
  void dispose() {
    _nameC.dispose();
    _bizC.dispose();
    _gstC.dispose();
    _upiC.dispose();
    _prefixC.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    await Prefs.update('yourName', _nameC.text.trim());
    await Prefs.update('bizName', _bizC.text.trim());
    await Prefs.update('gstNum', _gstC.text.trim());
    await Prefs.update('upiId', _upiC.text.trim());
    await Prefs.update(
        'invPrefix',
        _prefixC.text.trim().isEmpty
            ? 'INV'
            : _prefixC.text.trim().toUpperCase());
    setState(() => _editing = false);
  }

  String get _initials {
    final n = Prefs.yourName.value.trim();
    if (n.isEmpty) return 'U';
    final p = n.split(' ').where((w) => w.isNotEmpty).toList();
    return p.length >= 2
        ? '${p[0][0]}${p[1][0]}'.toUpperCase()
        : n[0].toUpperCase();
  }

  String get _qrStatus {
    if (!Prefs.showUpiQr) return 'Hidden on PDF';
    if (Prefs.upiQrImage.value.isNotEmpty) return 'Image set';
    if (Prefs.upiId.value.isNotEmpty) return 'Auto';
    return 'Not set';
  }

  Future<void> _pickUpiQrImage() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['png', 'jpg', 'jpeg', 'webp'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;

    final file = result.files.single;
    final bytes = file.bytes ??
        (file.path == null ? null : await File(file.path!).readAsBytes());
    if (bytes == null || bytes.isEmpty) {
      if (!mounted) return;
      showAppSnack(context, 'Could not read QR image');
      return;
    }
    if (bytes.length > 2 * 1024 * 1024) {
      if (!mounted) return;
      showAppSnack(context, 'Choose a smaller QR image');
      return;
    }

    await Prefs.setUpiQrImage(base64Encode(bytes), file.name);
    if (!mounted) return;
    setState(() {});
    showAppSnack(context, 'UPI QR saved');
  }

  Future<void> _removeUpiQrImage() async {
    await Prefs.setUpiQrImage('', '');
    if (!mounted) return;
    setState(() {});
    showAppSnack(context, 'UPI QR removed');
  }

  Future<void> _copyValue(String label, String value) async {
    final clean = value.trim();
    if (clean.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: clean));
    if (!mounted) return;
    showAppSnack(context, '$label copied');
  }

  void _openUpiQrSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (sheetContext, sheetSetState) => AppSheet(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('UPI QR',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: T.text(context))),
              const SizedBox(height: 14),
              _qrToggleRow(sheetSetState),
              const SizedBox(height: 14),
              _qrPreview(),
              const SizedBox(height: 14),
              _sheetAction(
                icon: Icons.image_outlined,
                title: Prefs.upiQrImage.value.isEmpty
                    ? 'Choose QR image'
                    : 'Change QR image',
                subtitle: 'Use an official QR from your UPI app',
                onTap: () {
                  Navigator.pop(context);
                  _pickUpiQrImage();
                },
              ),
              if (Prefs.upiQrImage.value.isNotEmpty) ...[
                Divider(height: 1, color: T.divider(context)),
                _sheetAction(
                  icon: Icons.close_rounded,
                  title: 'Remove QR image',
                  subtitle: 'Use generated QR instead',
                  onTap: () {
                    Navigator.pop(context);
                    _removeUpiQrImage();
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: T.bg(context),
      appBar: AppBar(
        backgroundColor: T.bg(context),
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          tooltip: 'Back',
          onPressed: () => Navigator.pop(context),
          icon:
              Icon(Icons.arrow_back_rounded, size: 18, color: T.text(context)),
        ),
        title: Text('Profile',
            style: TextStyle(
                color: T.text(context),
                fontSize: 16,
                fontWeight: FontWeight.w600)),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: _editing
                ? TextButton(
                    onPressed: _save,
                    child: Text('Save',
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: T.text(context))))
                : TextButton(
                    onPressed: () => setState(() => _editing = true),
                    child: Text('Edit',
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: T.text(context)))),
          ),
        ],
      ),
      body: ListView(children: [
        _profileHero(),
        const SizedBox(height: 28),

        // ── Business ──
        _sLabel('Business'),
        _block([
          _field('Your name', _nameC, Prefs.yourName.value),
          _field('Business name', _bizC, Prefs.bizName.value),
          _field('GSTIN', _gstC, Prefs.gstNum.value, hint: 'Not set'),
          _field('UPI ID', _upiC, Prefs.upiId.value, hint: 'Not set'),
          _qrAction(),
          _field('Invoice prefix', _prefixC, Prefs.invPrefix.value, last: true),
        ]),
        const SizedBox(height: 28),

        // ── Activity ──
        _sLabel('Activity'),
        _block([
          _info('Total invoices', '${Store.i.all.length}'),
          _info('Paid invoices', '${Store.i.paid.length}'),
          _info('Total revenue', amtUi(Store.i.totalRevenue)),
          _info('Member since', 'May 2026', last: true),
        ]),

        const SizedBox(height: 80),
      ]),
    );
  }

  // ── Helpers ──────────────────────────────────────────────────

  Widget _sLabel(String t) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
        child: Text(t,
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: T.muted(context),
                letterSpacing: 0)),
      );

  Widget _block(List<Widget> children) => Container(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: T.card(context),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: T.border(context), width: 0.5),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(children: children),
      );

  Widget _profileHero() {
    final name =
        Prefs.yourName.value.isNotEmpty ? Prefs.yourName.value : 'Your Name';
    final business = Prefs.bizName.value.isNotEmpty
        ? Prefs.bizName.value
        : 'Business details';
    final ready = Prefs.yourName.value.isNotEmpty &&
        Prefs.bizName.value.isNotEmpty &&
        Prefs.invPrefix.value.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: T.card(context),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: T.border(context), width: 0.5),
        ),
        child: Row(children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: T.inverse(context),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Center(
                child: Text(_initials,
                    style: TextStyle(
                        color: T.onInverse(context),
                        fontSize: 24,
                        fontWeight: FontWeight.w800))),
          ),
          const SizedBox(width: 15),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: T.text(context),
                      letterSpacing: 0)),
              const SizedBox(height: 4),
              Text(business,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 13, color: T.muted(context))),
              const SizedBox(height: 12),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: T.subtle(context),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: T.border(context), width: 0.5),
                ),
                child: Text(ready ? 'Ready to invoice' : 'Profile incomplete',
                    style: TextStyle(
                        color: T.text(context),
                        fontSize: 12,
                        fontWeight: FontWeight.w700)),
              ),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _qrAction() {
    return Column(children: [
      InkWell(
        onTap: _openUpiQrSheet,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(children: [
            Expanded(
              flex: 2,
              child: Text('UPI QR',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 14, color: T.muted(context))),
            ),
            const SizedBox(width: 14),
            Expanded(
              flex: 3,
              child: Text(_qrStatus,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: _qrStatus == 'Not set'
                          ? T.faint(context)
                          : T.text(context))),
            ),
            const SizedBox(width: 6),
            Icon(Icons.chevron_right_rounded,
                size: 18, color: T.faint(context)),
          ]),
        ),
      ),
      Divider(height: 1, indent: 20, color: T.divider(context)),
    ]);
  }

  Widget _qrToggleRow(StateSetter sheetSetState) => Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
        decoration: BoxDecoration(
          color: T.card(context),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: T.border(context), width: 0.5),
        ),
        child: Row(children: [
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Show on PDF',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: T.text(context))),
              const SizedBox(height: 3),
              Text('Adds payment QR to unpaid invoices',
                  style: TextStyle(fontSize: 12, color: T.muted(context))),
            ]),
          ),
          Switch.adaptive(
            value: Prefs.showUpiQr,
            onChanged: (v) async {
              await Prefs.setShowUpiQr(v);
              if (!mounted) return;
              sheetSetState(() {});
              setState(() {});
            },
            activeThumbColor: T.onInverse(context),
            activeTrackColor: T.inverse(context),
            inactiveThumbColor: T.faint(context),
            inactiveTrackColor: T.border(context),
          ),
        ]),
      );

  Widget _qrPreview() {
    if (Prefs.upiQrImage.value.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: T.subtle(context),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: T.border(context), width: 0.5),
        ),
        child: Text(
          Prefs.upiId.value.isEmpty
              ? 'No QR image or UPI ID set'
              : 'Generated from ${Prefs.upiId.value}',
          style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: T.muted(context)),
        ),
      );
    }

    try {
      final bytes = base64Decode(Prefs.upiQrImage.value);
      return Center(
        child: Container(
          width: 132,
          height: 132,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: T.border(context), width: 0.5),
          ),
          child: Image.memory(bytes, fit: BoxFit.contain),
        ),
      );
    } catch (_) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: T.subtle(context),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: T.border(context), width: 0.5),
        ),
        child: Text('QR image could not be previewed',
            style: TextStyle(fontSize: 13, color: T.muted(context))),
      );
    }
  }

  Widget _sheetAction({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) =>
      InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Row(children: [
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
                    Text(title,
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: T.text(context))),
                    const SizedBox(height: 3),
                    Text(subtitle,
                        style:
                            TextStyle(fontSize: 12, color: T.muted(context))),
                  ]),
            ),
            Icon(Icons.chevron_right_rounded,
                size: 18, color: T.faint(context)),
          ]),
        ),
      );

  Widget _field(String label, TextEditingController ctrl, String value,
      {String? hint, bool last = false}) {
    final empty = value.isEmpty;
    return Column(children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: _editing
            ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(label,
                    style: TextStyle(
                        fontSize: 11,
                        color: T.faint(context),
                        fontWeight: FontWeight.w500)),
                const SizedBox(height: 10),
                Container(
                  decoration: BoxDecoration(
                    color: T.subtle(context),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: T.border(context), width: 0.5),
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: TextField(
                    controller: ctrl,
                    style: TextStyle(fontSize: 15, color: T.text(context)),
                    decoration: InputDecoration(
                      hintText: hint ?? label,
                      hintStyle:
                          TextStyle(color: T.faint(context), fontSize: 15),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      disabledBorder: InputBorder.none,
                      isDense: false,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ])
            : Row(children: [
                Expanded(
                  flex: 2,
                  child: Text(label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 14, color: T.muted(context))),
                ),
                const SizedBox(width: 14),
                Expanded(
                  flex: 3,
                  child: empty
                      ? Text(
                          hint ?? '—',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.end,
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: T.faint(context)),
                        )
                      : Tooltip(
                          message: 'Tap to copy $label',
                          child: InkWell(
                            borderRadius: BorderRadius.circular(8),
                            onTap: () => _copyValue(label, value),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2),
                              child: Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    Flexible(
                                      child: Text(
                                        value,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        textAlign: TextAlign.end,
                                        style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: T.text(context)),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Icon(Icons.copy_rounded,
                                        size: 12, color: T.faint(context)),
                                  ]),
                            ),
                          ),
                        ),
                ),
              ]),
      ),
      if (!last) Divider(height: 1, indent: 20, color: T.divider(context)),
    ]);
  }

  Widget _info(String label, String value, {bool last = false}) =>
      Column(children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(children: [
            Expanded(
              child: Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 14, color: T.muted(context))),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: T.text(context))),
            ),
          ]),
        ),
        if (!last) Divider(height: 1, indent: 20, color: T.divider(context)),
      ]);
}
