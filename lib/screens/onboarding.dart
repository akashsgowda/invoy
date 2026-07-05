import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme.dart';
import '../models.dart';
import '../widgets.dart';

// ════════════════════════════════════════════════════════════════
// ONBOARD SCREEN
// ════════════════════════════════════════════════════════════════

class OnboardScreen extends StatefulWidget {
  const OnboardScreen({super.key});
  @override
  State<OnboardScreen> createState() => _OnboardScreenState();
}

class _OnboardScreenState extends State<OnboardScreen> {
  final _pageCtrl = PageController();
  final _nameC = TextEditingController();
  final _bizC = TextEditingController();
  final _bizAddressC = TextEditingController();
  final _bizStateC = TextEditingController();
  final _gstC = TextEditingController();
  final _upiC = TextEditingController();
  int _page = 0;
  bool _loading = false;
  bool _showUpiQr = true;
  String _upiQrData = '';
  String _upiQrName = '';

  @override
  void dispose() {
    _pageCtrl.dispose();
    _nameC.dispose();
    _bizC.dispose();
    _bizAddressC.dispose();
    _bizStateC.dispose();
    _gstC.dispose();
    _upiC.dispose();
    super.dispose();
  }

  void _toPage(int p) {
    setState(() => _page = p);
    _pageCtrl.animateToPage(
      p,
      duration: const Duration(milliseconds: 340),
      curve: kSpring,
    );
  }

  void _next() {
    // Validate on details page
    if (_page == 1 && _nameC.text.trim().isEmpty) {
      if (Prefs.haptics) HapticFeedback.mediumImpact();
      showAppSnack(context, 'Enter your name to continue');
      return;
    }
    if (_page < 3) _toPage(_page + 1);
  }

  void _back() {
    if (_page > 0) _toPage(_page - 1);
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

    if (!mounted) return;
    setState(() {
      _upiQrData = base64Encode(bytes);
      _upiQrName = file.name;
    });
  }

  void _removeUpiQrImage() {
    setState(() {
      _upiQrData = '';
      _upiQrName = '';
    });
  }

  Future<void> _finish() async {
    if (_loading) return;
    if (!isValidGstin(_gstC.text)) {
      if (Prefs.haptics) HapticFeedback.mediumImpact();
      showAppSnack(context, 'Enter a valid 15-character GSTIN');
      return;
    }
    setState(() => _loading = true);
    try {
      await Prefs.update('bizAddress', _bizAddressC.text.trim());
      await Prefs.update('bizState', _bizStateC.text.trim());
      await Prefs.setShowUpiQr(_showUpiQr);
      if (_upiQrData.isNotEmpty) {
        await Prefs.setUpiQrImage(_upiQrData, _upiQrName);
      }
      await Prefs.setOnboarded(
        _nameC.text.trim(),
        _bizC.text.trim(),
        cleanGstin(_gstC.text),
        _upiC.text.trim(),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
      showAppSnack(context, 'Could not finish setup');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: T.bg(context),
      // Dismiss keyboard on tap outside
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SafeArea(
          child: PageView(
            controller: _pageCtrl,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _WelcomePage(onStart: _next),
              _DetailsPage(
                nameC: _nameC,
                bizC: _bizC,
                onBack: _back,
                onNext: _next,
              ),
              _BusinessPage(
                bizAddressC: _bizAddressC,
                bizStateC: _bizStateC,
                gstC: _gstC,
                upiC: _upiC,
                qrName: _upiQrName,
                showUpiQr: _showUpiQr,
                onShowUpiQr: (v) => setState(() => _showUpiQr = v),
                onPickQr: _pickUpiQrImage,
                onRemoveQr: _removeUpiQrImage,
                onBack: _back,
                onNext: _next,
              ),
              _CompletePage(loading: _loading, onFinish: _finish),
            ],
          ),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// PAGE 1 — WELCOME
// ════════════════════════════════════════════════════════════════

class _WelcomePage extends StatefulWidget {
  final VoidCallback onStart;
  const _WelcomePage({required this.onStart});
  @override
  State<_WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<_WelcomePage>
    with SingleTickerProviderStateMixin {
  late AnimationController _ac;
  late Animation<double> _fade;
  late Animation<double> _slide;

  @override
  void initState() {
    super.initState();
    _ac = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..forward();
    _fade = CurvedAnimation(parent: _ac, curve: kSpring);
    _slide = Tween(
      begin: 32.0,
      end: 0.0,
    ).animate(CurvedAnimation(parent: _ac, curve: kSpring));
  }

  @override
  void dispose() {
    _ac.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
        opacity: _fade,
        child: AnimatedBuilder(
          animation: _slide,
          builder: (_, child) => Transform.translate(
              offset: Offset(0, _slide.value), child: child),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(28, 0, 28, 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Spacer(flex: 3),
                Text(
                  'Invoy',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: T.muted(context),
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Set up your invoice workspace.',
                  style: TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.w700,
                    color: T.text(context),
                    letterSpacing: 0,
                    height: 1.08,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Add your business details once. They will appear on invoices and PDFs.',
                  style: TextStyle(
                    fontSize: 15,
                    color: T.muted(context),
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 28),
                _SetupPreview(),
                const Spacer(flex: 3),
                _PrimaryBtn('Get started', widget.onStart),
                const SizedBox(height: 16),
                Center(
                  child: Text(
                    'Quick setup. You can edit these later.',
                    style: TextStyle(fontSize: 12, color: T.faint(context)),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}

class _SetupPreview extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: T.card(context),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: T.border(context), width: 0.5),
        ),
        child: Column(
          children: [
            _previewRow(context, 'Profile', 'Name and business'),
            Divider(height: 24, color: T.divider(context)),
            _previewRow(context, 'Tax', 'GST details if needed'),
            Divider(height: 24, color: T.divider(context)),
            _previewRow(context, 'Payment', 'UPI ID and QR for PDFs'),
          ],
        ),
      );

  Widget _previewRow(BuildContext context, String title, String subtitle) =>
      Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: T.text(context),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: T.text(context),
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: TextStyle(color: T.muted(context), fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      );
}

// ════════════════════════════════════════════════════════════════
// PAGE 2 — YOUR DETAILS
// ════════════════════════════════════════════════════════════════

class _DetailsPage extends StatelessWidget {
  final TextEditingController nameC, bizC;
  final VoidCallback onBack, onNext;
  const _DetailsPage({
    required this.nameC,
    required this.bizC,
    required this.onBack,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) => _PageShell(
        step: '1 of 2',
        onBack: onBack,
        cta: _PrimaryBtn('Continue', onNext),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Your details',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: T.text(context),
                letterSpacing: 0,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'These details appear on invoices and PDF files.',
              style: TextStyle(fontSize: 14, color: T.muted(context)),
            ),
            const SizedBox(height: 28),
            _OnboardField(
              ctrl: nameC,
              label: 'Your name',
              hint: 'Enter your full name',
              autofocus: true,
            ),
            const SizedBox(height: 16),
            _OnboardField(
              ctrl: bizC,
              label: 'Business name',
              hint: 'Enter business name',
            ),
            const SizedBox(height: 14),
            const _SmallNote(
                'Your name is required. Business name is optional.'),
          ],
        ),
      );
}

// ════════════════════════════════════════════════════════════════
// PAGE 3 — BUSINESS SETUP
// ════════════════════════════════════════════════════════════════

class _BusinessPage extends StatelessWidget {
  final TextEditingController bizAddressC, bizStateC, gstC, upiC;
  final String qrName;
  final bool showUpiQr;
  final ValueChanged<bool> onShowUpiQr;
  final VoidCallback onPickQr, onRemoveQr;
  final VoidCallback onBack, onNext;
  const _BusinessPage({
    required this.bizAddressC,
    required this.bizStateC,
    required this.gstC,
    required this.upiC,
    required this.qrName,
    required this.showUpiQr,
    required this.onShowUpiQr,
    required this.onPickQr,
    required this.onRemoveQr,
    required this.onBack,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) => _PageShell(
        step: '2 of 2',
        onBack: onBack,
        cta: Column(
          children: [
            _PrimaryBtn('Continue', onNext),
            const SizedBox(height: 12),
            _GhostBtn('Skip for now', onNext),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Tax and payment',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: T.text(context),
                letterSpacing: 0,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Optional details for GST invoices and faster payment.',
              style: TextStyle(fontSize: 14, color: T.muted(context)),
            ),
            const SizedBox(height: 28),
            _OnboardField(
              ctrl: bizAddressC,
              label: 'Business address',
              hint: 'Street, city, pincode',
              kb: TextInputType.streetAddress,
            ),
            const SizedBox(height: 16),
            _OnboardField(
              ctrl: bizStateC,
              label: 'Business state',
              hint: 'Karnataka',
              kb: TextInputType.text,
              caps: TextCapitalization.words,
            ),
            const SizedBox(height: 16),
            _OnboardField(
              ctrl: gstC,
              label: 'GSTIN',
              hint: '29ABCDE1234F1Z5',
              kb: TextInputType.text,
              caps: TextCapitalization.characters,
              inputFormatters: gstinInputFormatters,
            ),
            const SizedBox(height: 16),
            _OnboardField(
              ctrl: upiC,
              label: 'UPI ID',
              hint: 'yourname@upi',
              kb: TextInputType.emailAddress,
            ),
            const SizedBox(height: 16),
            _QrSetupCard(
              qrName: qrName,
              showUpiQr: showUpiQr,
              onShowUpiQr: onShowUpiQr,
              onPickQr: onPickQr,
              onRemoveQr: onRemoveQr,
            ),
            const SizedBox(height: 14),
            const _SmallNote(
              'Upload an official QR from your UPI app if generated QR does not scan properly.',
            ),
          ],
        ),
      );
}

class _QrSetupCard extends StatelessWidget {
  final String qrName;
  final bool showUpiQr;
  final ValueChanged<bool> onShowUpiQr;
  final VoidCallback onPickQr, onRemoveQr;

  const _QrSetupCard({
    required this.qrName,
    required this.showUpiQr,
    required this.onShowUpiQr,
    required this.onPickQr,
    required this.onRemoveQr,
  });

  @override
  Widget build(BuildContext context) {
    final hasQr = qrName.isNotEmpty;
    return Container(
      decoration: BoxDecoration(
        color: T.card(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: T.border(context), width: 0.5),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Show UPI QR on PDF',
                        style: TextStyle(
                          color: T.text(context),
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        hasQr ? 'Using uploaded QR image' : 'Uses UPI ID',
                        style: TextStyle(color: T.muted(context), fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Switch.adaptive(
                  value: showUpiQr,
                  onChanged: onShowUpiQr,
                  activeThumbColor: T.onInverse(context),
                  activeTrackColor: T.inverse(context),
                  inactiveThumbColor: T.faint(context),
                  inactiveTrackColor: T.border(context),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: T.divider(context)),
          SpringTap(
            onTap: hasQr ? onRemoveQr : onPickQr,
            scale: 0.985,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          hasQr ? 'QR image saved' : 'Upload UPI QR',
                          style: TextStyle(
                            color: T.text(context),
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          hasQr ? qrName : 'PNG, JPG or WebP',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: T.muted(context),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    hasQr ? 'Remove' : 'Choose',
                    style: TextStyle(
                      color: T.text(context),
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// PAGE 4 — COMPLETE
// ════════════════════════════════════════════════════════════════

class _CompletePage extends StatefulWidget {
  final bool loading;
  final VoidCallback onFinish;
  const _CompletePage({required this.loading, required this.onFinish});
  @override
  State<_CompletePage> createState() => _CompletePageState();
}

class _CompletePageState extends State<_CompletePage>
    with SingleTickerProviderStateMixin {
  late AnimationController _ac;
  late Animation<double> _scale;
  late Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ac = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();
    _scale = Tween(
      begin: 0.7,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _ac, curve: kSpring));
    _fade = CurvedAnimation(parent: _ac, curve: kSpring);
  }

  @override
  void dispose() {
    _ac.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
        opacity: _fade,
        child: ScaleTransition(
          scale: _scale,
          alignment: Alignment.center,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(28, 0, 28, 40),
            child: Column(
              children: [
                const Spacer(flex: 2),

                // Check mark
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: T.card(context),
                    shape: BoxShape.circle,
                    border: Border.all(color: T.border(context), width: 0.5),
                  ),
                  child: Icon(
                    Icons.check_rounded,
                    color: T.text(context),
                    size: 28,
                  ),
                ),
                const SizedBox(height: 28),

                // Name greeting
                Text(
                  'Setup complete.',
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w600,
                    color: T.text(context),
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Your workspace is ready.\nStart creating invoices.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    color: T.muted(context),
                    height: 1.5,
                  ),
                ),

                const Spacer(flex: 3),

                widget.loading
                    ? const SizedBox(
                        height: 54,
                        child: Center(
                          child: SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 1.5),
                          ),
                        ),
                      )
                    : _PrimaryBtn('Start invoicing', widget.onFinish),
              ],
            ),
          ),
        ),
      );
}

// ════════════════════════════════════════════════════════════════
// SHARED PAGE SHELL
// ════════════════════════════════════════════════════════════════

class _PageShell extends StatelessWidget {
  final String step;
  final VoidCallback onBack;
  final Widget child;
  final Widget cta;

  const _PageShell({
    required this.step,
    required this.onBack,
    required this.child,
    required this.cta,
  });

  @override
  Widget build(BuildContext context) => Column(
        children: [
          // Nav bar
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 20, 0),
            child: Row(
              children: [
                IconButton(
                  tooltip: 'Back',
                  onPressed: onBack,
                  icon: Icon(
                    Icons.arrow_back_rounded,
                    size: 18,
                    color: T.muted(context),
                  ),
                ),
                const Spacer(),
                Text(
                  step,
                  style: TextStyle(
                    fontSize: 12,
                    color: T.faint(context),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

          // Scrollable content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(28, 24, 28, 0),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              child: child,
            ),
          ),

          // CTA pinned at bottom
          Padding(
            padding: EdgeInsets.fromLTRB(
              28,
              16,
              28,
              MediaQuery.of(context).viewInsets.bottom > 0
                  ? MediaQuery.of(context).viewInsets.bottom + 16
                  : 32,
            ),
            child: cta,
          ),
        ],
      );
}

// ════════════════════════════════════════════════════════════════
// SHARED INPUT FIELD
// ════════════════════════════════════════════════════════════════

class _OnboardField extends StatefulWidget {
  final TextEditingController ctrl;
  final String label, hint;
  final TextInputType kb;
  final TextCapitalization caps;
  final List<TextInputFormatter>? inputFormatters;
  final bool autofocus;

  const _OnboardField({
    required this.ctrl,
    required this.label,
    required this.hint,
    this.kb = TextInputType.text,
    this.caps = TextCapitalization.words,
    this.inputFormatters,
    this.autofocus = false,
  });

  @override
  State<_OnboardField> createState() => _OnboardFieldState();
}

class _OnboardFieldState extends State<_OnboardField> {
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: _focus.hasFocus ? T.text(context) : T.faint(context),
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 8),
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: kSmooth,
            height: 52,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: T.card(context),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: _focus.hasFocus
                    ? T.text(context).withValues(alpha: 0.26)
                    : T.border(context).withValues(alpha: 0.78),
                width: 0.7,
              ),
              boxShadow: _focus.hasFocus ? T.softShadow(context) : const [],
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Center(
                child: TextField(
                  focusNode: _focus,
                  controller: widget.ctrl,
                  autofocus: widget.autofocus,
                  keyboardType: widget.kb,
                  textCapitalization: widget.caps,
                  inputFormatters: widget.inputFormatters,
                  style: TextStyle(color: T.text(context), fontSize: 15),
                  decoration: InputDecoration(
                    isCollapsed: true,
                    filled: false,
                    hintText: widget.hint,
                    hintStyle: TextStyle(color: T.faint(context), fontSize: 15),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    disabledBorder: InputBorder.none,
                  ),
                ),
              ),
            ),
          ),
        ],
      );
}

class _SmallNote extends StatelessWidget {
  final String text;
  const _SmallNote(this.text);

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: TextStyle(fontSize: 12, height: 1.4, color: T.faint(context)),
      );
}

// ════════════════════════════════════════════════════════════════
// SHARED BUTTONS
// ════════════════════════════════════════════════════════════════

class _PrimaryBtn extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _PrimaryBtn(this.label, this.onTap);

  @override
  Widget build(BuildContext context) => AppButton(label: label, onTap: onTap);
}

class _GhostBtn extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _GhostBtn(this.label, this.onTap);

  @override
  Widget build(BuildContext context) => AppButton(
        label: label,
        onTap: onTap,
        tone: AppButtonTone.ghost,
        height: 44,
      );
}
