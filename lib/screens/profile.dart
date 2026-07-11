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
  bool _saving = false;
  late final TextEditingController _nameC;
  late final TextEditingController _bizC;
  late final TextEditingController _bizAddressC;
  late final TextEditingController _bizStateC;
  late final TextEditingController _gstC;
  late final TextEditingController _upiC;
  late final TextEditingController _prefixC;

  @override
  void initState() {
    super.initState();
    _nameC = TextEditingController(text: Prefs.yourName.value);
    _bizC = TextEditingController(text: Prefs.bizName.value);
    _bizAddressC = TextEditingController(text: Prefs.bizAddress.value);
    _bizStateC = TextEditingController(text: Prefs.bizState.value);
    _gstC = TextEditingController(text: Prefs.gstNum.value);
    _upiC = TextEditingController(text: Prefs.upiId.value);
    _prefixC = TextEditingController(text: Prefs.invPrefix.value);
  }

  @override
  void dispose() {
    _nameC.dispose();
    _bizC.dispose();
    _bizAddressC.dispose();
    _bizStateC.dispose();
    _gstC.dispose();
    _upiC.dispose();
    _prefixC.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    if (!isValidGstin(_gstC.text)) {
      if (Prefs.haptics) HapticFeedback.mediumImpact();
      showAppSnack(context, 'Enter a valid 15-character GSTIN');
      return;
    }
    if (!isValidUpiId(_upiC.text)) {
      if (Prefs.haptics) HapticFeedback.mediumImpact();
      showAppSnack(context, 'Enter a valid UPI ID, like name@bank');
      return;
    }
    if (_gstC.text.trim().isNotEmpty) {
      if (_bizAddressC.text.trim().isEmpty) {
        showAppSnack(context, 'Add the registered business address');
        return;
      }
      if (gstStateCode(_bizStateC.text) == null) {
        showAppSnack(context, 'Enter a valid Indian business state');
        return;
      }
      if (!gstinMatchesState(_gstC.text, _bizStateC.text)) {
        showAppSnack(context, 'GSTIN does not match the business state');
        return;
      }
    }
    setState(() => _saving = true);
    try {
      final prefix = sanitizeInvoicePrefix(_prefixC.text);
      await Prefs.update('yourName', _nameC.text.trim());
      await Prefs.update('bizName', _bizC.text.trim());
      await Prefs.update('bizAddress', _bizAddressC.text.trim());
      await Prefs.update('bizState', _bizStateC.text.trim());
      await Prefs.update('gstNum', cleanGstin(_gstC.text));
      await Prefs.update('upiId', _upiC.text.trim());
      await Prefs.update('invPrefix', prefix);
      if (!mounted) return;
      _prefixC.text = prefix;
      setState(() => _editing = false);
      showAppSnack(context, 'Business details saved');
    } catch (_) {
      if (!mounted) return;
      showAppSnack(context, 'Could not save business details');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _cancelEdit() {
    _nameC.text = Prefs.yourName.value;
    _bizC.text = Prefs.bizName.value;
    _bizAddressC.text = Prefs.bizAddress.value;
    _bizStateC.text = Prefs.bizState.value;
    _gstC.text = Prefs.gstNum.value;
    _upiC.text = Prefs.upiId.value;
    _prefixC.text = Prefs.invPrefix.value;
    setState(() => _editing = false);
  }

  String get _qrStatus {
    if (!Prefs.showUpiQr) return 'Hidden on PDF';
    if (Prefs.upiQrImage.value.isNotEmpty) return 'Image set';
    if (Prefs.upiId.value.isNotEmpty) return 'Auto';
    return 'Not set';
  }

  String get _signatureStatus =>
      Prefs.signatureImage.value.isEmpty ? 'Not set' : 'Image set';

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

  Future<void> _pickSignatureImage() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['png', 'jpg', 'jpeg', 'webp'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.single;
    final bytes = file.bytes ??
        (file.path == null ? null : await File(file.path!).readAsBytes());
    if (bytes == null || bytes.isEmpty || bytes.length > 2 * 1024 * 1024) {
      if (!mounted) return;
      showAppSnack(context, 'Choose a signature image under 2 MB');
      return;
    }
    await Prefs.setSignatureImage(base64Encode(bytes), file.name);
    if (!mounted) return;
    setState(() {});
    showAppSnack(context, 'Invoice signature saved');
  }

  Future<void> _removeSignatureImage() async {
    await Prefs.setSignatureImage('', '');
    if (!mounted) return;
    setState(() {});
    showAppSnack(context, 'Invoice signature removed');
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
              Text(
                'UPI QR',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: T.text(context),
                ),
              ),
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

  void _openSignatureSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => AppSheet(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Invoice signature',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: T.text(context),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Used as the authorised signature on invoice PDFs.',
              style: TextStyle(fontSize: 12, color: T.muted(context)),
            ),
            if (Prefs.signatureImage.value.isNotEmpty) ...[
              const SizedBox(height: 16),
              _signaturePreview(),
            ],
            const SizedBox(height: 14),
            _sheetAction(
              icon: Icons.draw_outlined,
              title: Prefs.signatureImage.value.isEmpty
                  ? 'Choose signature image'
                  : 'Change signature image',
              subtitle: 'PNG, JPG or WebP under 2 MB',
              onTap: () {
                Navigator.pop(context);
                _pickSignatureImage();
              },
            ),
            if (Prefs.signatureImage.value.isNotEmpty) ...[
              Divider(height: 1, color: T.divider(context)),
              _sheetAction(
                icon: Icons.close_rounded,
                title: 'Remove signature image',
                subtitle: 'Remove it from future PDFs',
                onTap: () {
                  Navigator.pop(context);
                  _removeSignatureImage();
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _signaturePreview() {
    try {
      final bytes = base64Decode(Prefs.signatureImage.value);
      return Container(
        width: double.infinity,
        height: 92,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: T.border(context), width: 0.5),
        ),
        child: Image.memory(bytes, fit: BoxFit.contain),
      );
    } catch (_) {
      return Text(
        'Signature image could not be previewed',
        style: TextStyle(fontSize: 12, color: T.muted(context)),
      );
    }
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
          icon: Icon(
            Icons.arrow_back_rounded,
            size: 18,
            color: T.text(context),
          ),
        ),
        title: Text(
          'Business Profile',
          style: TextStyle(
            color: T.text(context),
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: ListView(
        children: [
          _profileHero(),
          if (!_editing) ...[
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: AppButton(
                label: 'Edit business details',
                onTap: () => setState(() => _editing = true),
              ),
            ),
          ],
          const SizedBox(height: 28),

          // ── Business ──
          _sLabel('Business'),
          _block([
            _field('Your name', _nameC, Prefs.yourName.value),
            _field('Business name', _bizC, Prefs.bizName.value),
            _field(
              'Business address',
              _bizAddressC,
              Prefs.bizAddress.value,
              hint: 'Not set',
            ),
            _field(
              'Business state',
              _bizStateC,
              Prefs.bizState.value,
              hint: 'Not set',
            ),
            _field(
              'GSTIN',
              _gstC,
              Prefs.gstNum.value,
              hint: 'Not set',
              inputFormatters: gstinInputFormatters,
            ),
            _field('UPI ID', _upiC, Prefs.upiId.value, hint: 'Not set'),
            _qrAction(),
            _signatureAction(),
            _field(
              'Invoice prefix',
              _prefixC,
              Prefs.invPrefix.value,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp('[A-Za-z0-9]')),
                LengthLimitingTextInputFormatter(kMaxInvoicePrefixLength),
              ],
              last: true,
            ),
          ]),
          const SizedBox(height: 28),

          // ── Activity ──
          _sLabel('Activity'),
          _activityGrid(),

          const SizedBox(height: 80),
        ],
      ),
      bottomNavigationBar: _editing
          ? SafeArea(
              child: Container(
                color: T.bg(context),
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
                child: Row(
                  children: [
                    Expanded(
                      child: AppButton(
                        label: 'Cancel',
                        onTap: _saving ? null : _cancelEdit,
                        tone: AppButtonTone.secondary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: AppButton(
                        label: 'Save Changes',
                        onTap: _saving ? null : _save,
                        loading: _saving,
                      ),
                    ),
                  ],
                ),
              ),
            )
          : null,
    );
  }

  // ── Helpers ──────────────────────────────────────────────────

  Widget _sLabel(String t) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
        child: Text(
          t,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: T.muted(context),
            letterSpacing: 0,
          ),
        ),
      );

  Widget _block(List<Widget> children) => Container(
        margin: const EdgeInsets.symmetric(horizontal: 20),
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

  Widget _profileHero() {
    final name = Prefs.yourName.value.isNotEmpty
        ? Prefs.yourName.value
        : 'Owner name not set';
    final business = Prefs.bizName.value.isNotEmpty
        ? Prefs.bizName.value
        : 'Business name not set';
    final gst = Prefs.gstNum.value.isEmpty ? 'GST not set' : 'GST ready';
    final upi = _qrStatus == 'Not set' ? 'UPI not set' : 'UPI ready';

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color:
              T.card(context).withValues(alpha: T.dark(context) ? 0.70 : 0.92),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: T.border(context).withValues(alpha: 0.68),
            width: 0.5,
          ),
          boxShadow: T.dark(context) ? const [] : T.softShadow(context),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Invoice identity',
              style: TextStyle(
                color: T.muted(context),
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              business,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: T.text(context),
                letterSpacing: 0,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 13, color: T.muted(context)),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: _miniChip('Prefix', Prefs.invPrefix.value)),
                const SizedBox(width: 10),
                Expanded(child: _miniChip('GST', gst)),
                const SizedBox(width: 10),
                Expanded(child: _miniChip('UPI', upi)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _miniChip(String label, String value) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
        decoration: BoxDecoration(
          color: T.subtle(context),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: T.border(context).withValues(alpha: 0.62),
            width: 0.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: T.muted(context),
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value.isEmpty ? '-' : value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: T.text(context),
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      );

  Widget _activityGrid() => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          children: [
            Expanded(child: _statCard('Invoices', '${Store.i.all.length}')),
            const SizedBox(width: 10),
            Expanded(child: _statCard('Paid', '${Store.i.paid.length}')),
            const SizedBox(width: 10),
            Expanded(
                child: _statCard('Revenue', amtCompact(Store.i.totalRevenue))),
          ],
        ),
      );

  Widget _statCard(String label, String value) => Container(
        height: 74,
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color:
              T.card(context).withValues(alpha: T.dark(context) ? 0.70 : 0.92),
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
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: T.muted(context),
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: T.text(context),
                fontSize: 14,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      );

  Widget _qrAction() {
    return Column(
      children: [
        SpringTap(
          onTap: _openUpiQrSheet,
          scale: 0.985,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Text(
                    'UPI QR',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 14, color: T.muted(context)),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  flex: 3,
                  child: Text(
                    _qrStatus,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.end,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: _qrStatus == 'Not set'
                          ? T.faint(context)
                          : T.text(context),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: T.faint(context),
                ),
              ],
            ),
          ),
        ),
        Divider(height: 1, indent: 20, color: T.divider(context)),
      ],
    );
  }

  Widget _signatureAction() => Column(
        children: [
          SpringTap(
            onTap: _openSignatureSheet,
            scale: 0.985,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: Text(
                      'Invoice signature',
                      style: TextStyle(fontSize: 14, color: T.muted(context)),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    flex: 3,
                    child: Text(
                      _signatureStatus,
                      textAlign: TextAlign.end,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: _signatureStatus == 'Not set'
                            ? T.faint(context)
                            : T.text(context),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: T.faint(context),
                  ),
                ],
              ),
            ),
          ),
          Divider(height: 1, indent: 20, color: T.divider(context)),
        ],
      );

  Widget _qrToggleRow(StateSetter sheetSetState) => Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
        decoration: BoxDecoration(
          color: T.card(context),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: T.border(context), width: 0.5),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Show on PDF',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: T.text(context),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'UPI payment QR, not a GST e-invoice QR',
                    style: TextStyle(fontSize: 12, color: T.muted(context)),
                  ),
                ],
              ),
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
          ],
        ),
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
            color: T.muted(context),
          ),
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
        child: Text(
          'QR image could not be previewed',
          style: TextStyle(fontSize: 13, color: T.muted(context)),
        ),
      );
    }
  }

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

  Widget _field(
    String label,
    TextEditingController ctrl,
    String value, {
    String? hint,
    List<TextInputFormatter>? inputFormatters,
    bool last = false,
  }) {
    final empty = value.isEmpty;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: _editing
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 11,
                        color: T.faint(context),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      decoration: BoxDecoration(
                        color: T.card(context),
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(
                          color: T.border(context).withValues(alpha: 0.78),
                          width: 0.7,
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      child: TextField(
                        controller: ctrl,
                        inputFormatters: inputFormatters,
                        style: TextStyle(fontSize: 15, color: T.text(context)),
                        decoration: InputDecoration(
                          hintText: hint ?? label,
                          hintStyle: TextStyle(
                            color: T.faint(context),
                            fontSize: 15,
                          ),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          disabledBorder: InputBorder.none,
                          isDense: false,
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 12,
                          ),
                        ),
                      ),
                    ),
                  ],
                )
              : Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 14, color: T.muted(context)),
                      ),
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
                                color: T.faint(context),
                              ),
                            )
                          : Tooltip(
                              message: 'Tap to copy $label',
                              child: SpringTap(
                                onTap: () => _copyValue(label, value),
                                scale: 0.985,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 2,
                                  ),
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
                                            color: T.text(context),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Icon(
                                        Icons.copy_rounded,
                                        size: 12,
                                        color: T.faint(context),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                    ),
                  ],
                ),
        ),
        if (!last) Divider(height: 1, indent: 20, color: T.divider(context)),
      ],
    );
  }
}
