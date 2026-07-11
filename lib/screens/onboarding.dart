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
  final _nameC = TextEditingController();
  final _bizC = TextEditingController();
  final _bizAddressC = TextEditingController();
  final _bizStateC = TextEditingController();
  final _gstC = TextEditingController();
  final _upiC = TextEditingController();
  int _page = 0;
  int _direction = 1;
  bool _showUpiQr = true;
  String _upiQrData = '';
  String _upiQrName = '';
  bool _finishing = false;

  @override
  void dispose() {
    _nameC.dispose();
    _bizC.dispose();
    _bizAddressC.dispose();
    _bizStateC.dispose();
    _gstC.dispose();
    _upiC.dispose();
    super.dispose();
  }

  void _toPage(int p) {
    if (p == _page) return;
    setState(() {
      _direction = p > _page ? 1 : -1;
      _page = p;
    });
  }

  void _next() {
    // Validate on details page
    if (_page == 1 && _nameC.text.trim().isEmpty) {
      if (Prefs.haptics) HapticFeedback.mediumImpact();
      showAppSnack(context, 'Enter your name to continue');
      return;
    }
    if (_page == 2 && !isValidGstin(_gstC.text)) {
      if (Prefs.haptics) HapticFeedback.mediumImpact();
      showAppSnack(context, 'Enter a valid 15-character GSTIN');
      return;
    }
    if (_page == 2 && _gstC.text.trim().isNotEmpty) {
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
    if (_page == 2 && !isValidUpiId(_upiC.text)) {
      if (Prefs.haptics) HapticFeedback.mediumImpact();
      showAppSnack(context, 'Enter a valid UPI ID, like name@bank');
      return;
    }
    if (_page < 3) _toPage(_page + 1);
  }

  void _back() {
    if (_finishing) return;
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
    if (_finishing) return;
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
    FocusScope.of(context).unfocus();
    setState(() => _finishing = true);
    try {
      await Prefs.update('bizAddress', _bizAddressC.text.trim());
      await Prefs.update('bizState', _bizStateC.text.trim());
      await Prefs.setShowUpiQr(_showUpiQr);
      if (_upiQrData.isNotEmpty) {
        await Prefs.setUpiQrImage(_upiQrData, _upiQrName);
      }
      await Prefs.update('yourName', _nameC.text.trim());
      await Prefs.update('bizName', _bizC.text.trim());
      await Prefs.update('gstNum', cleanGstin(_gstC.text));
      await Prefs.update('upiId', _upiC.text.trim());
      await Prefs.update('onboarded', '1');
      if (!mounted) return;
      if (Prefs.haptics) HapticFeedback.lightImpact();
      Prefs.onboarded.value = true;
    } catch (_) {
      if (!mounted) return;
      setState(() => _finishing = false);
      showAppSnack(context, 'Could not finish setup');
    }
  }

  @override
  Widget build(BuildContext context) {
    final page = switch (_page) {
      0 => _WelcomePage(key: const ValueKey('welcome'), onStart: _next),
      1 => _DetailsPage(
          key: const ValueKey('details'),
          nameC: _nameC,
          bizC: _bizC,
          progressFrom: _direction < 0 ? 1 : 0,
          onBack: _back,
          onNext: _next,
        ),
      2 => _BusinessPage(
          key: const ValueKey('business'),
          bizAddressC: _bizAddressC,
          bizStateC: _bizStateC,
          gstC: _gstC,
          upiC: _upiC,
          qrName: _upiQrName,
          showUpiQr: _showUpiQr,
          progressFrom: 0.5,
          onShowUpiQr: (v) => setState(() => _showUpiQr = v),
          onPickQr: _pickUpiQrImage,
          onRemoveQr: _removeUpiQrImage,
          onBack: _back,
          onNext: _next,
        ),
      _ => _CompletePage(
          key: const ValueKey('complete'),
          loading: _finishing,
          onFinish: _finish,
        ),
    };

    return Scaffold(
      backgroundColor: T.bg(context),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SafeArea(
          child: AnimatedSwitcher(
            duration: Prefs.reduceMotion
                ? Duration.zero
                : const Duration(milliseconds: 320),
            reverseDuration: Prefs.reduceMotion
                ? Duration.zero
                : const Duration(milliseconds: 240),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, animation) {
              final curved = CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
              );
              final slide = Tween<Offset>(
                begin: Offset(0.035 * _direction, 0),
                end: Offset.zero,
              ).animate(curved);
              return FadeTransition(
                opacity: curved,
                child: SlideTransition(position: slide, child: child),
              );
            },
            child: page,
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
  const _WelcomePage({super.key, required this.onStart});
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
          child: _CenteredOnboardLayout(
            bottom: Column(
              children: [
                _PrimaryBtn('Get started', widget.onStart),
                const SizedBox(height: 10),
                Text(
                  'Takes less than a minute.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: T.faint(context)),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Invoy',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: T.text(context),
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 28),
                Text(
                  'Set up once.\nInvoice faster.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.w800,
                    color: T.text(context),
                    letterSpacing: 0,
                    height: 1.06,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Add your business details now. You can update them anytime.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: T.muted(context),
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}

// ════════════════════════════════════════════════════════════════
// PAGE 2 — YOUR DETAILS
// ════════════════════════════════════════════════════════════════

class _DetailsPage extends StatelessWidget {
  final TextEditingController nameC, bizC;
  final double progressFrom;
  final VoidCallback onBack, onNext;
  const _DetailsPage({
    super.key,
    required this.nameC,
    required this.bizC,
    required this.progressFrom,
    required this.onBack,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) => _StepLayout(
        step: '1 of 2',
        progressFrom: progressFrom,
        progress: 0.5,
        onBack: onBack,
        bottom: _PrimaryBtn('Continue', onNext),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Your details',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: T.text(context),
                letterSpacing: 0,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'These details appear on invoices and PDF files.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: T.muted(context)),
            ),
            const SizedBox(height: 26),
            _OnboardPanel(
              child: Column(
                children: [
                  _OnboardField(
                    ctrl: nameC,
                    label: 'Your name',
                    hint: 'Enter your full name',
                  ),
                  const SizedBox(height: 16),
                  _OnboardField(
                    ctrl: bizC,
                    label: 'Business name',
                    hint: 'Enter business name',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
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
  final double progressFrom;
  final ValueChanged<bool> onShowUpiQr;
  final VoidCallback onPickQr, onRemoveQr;
  final VoidCallback onBack, onNext;
  const _BusinessPage({
    super.key,
    required this.bizAddressC,
    required this.bizStateC,
    required this.gstC,
    required this.upiC,
    required this.qrName,
    required this.showUpiQr,
    required this.progressFrom,
    required this.onShowUpiQr,
    required this.onPickQr,
    required this.onRemoveQr,
    required this.onBack,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) => _StepLayout(
        step: '2 of 2',
        progressFrom: progressFrom,
        progress: 1,
        onBack: onBack,
        bottom: _PrimaryBtn('Continue', onNext),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Tax and payment',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: T.text(context),
                letterSpacing: 0,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Optional details for GST invoices and faster payment.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: T.muted(context)),
            ),
            const SizedBox(height: 22),
            _OnboardPanel(
              child: Column(
                children: [
                  _OnboardField(
                    ctrl: bizAddressC,
                    label: 'Business address',
                    hint: 'Street, city, pincode',
                    kb: TextInputType.streetAddress,
                  ),
                  const SizedBox(height: 14),
                  _OnboardField(
                    ctrl: bizStateC,
                    label: 'Business state',
                    hint: 'Karnataka',
                    kb: TextInputType.text,
                    caps: TextCapitalization.words,
                  ),
                  const SizedBox(height: 14),
                  _OnboardField(
                    ctrl: gstC,
                    label: 'GSTIN',
                    hint: '29ABCDE1234F1Z5',
                    kb: TextInputType.text,
                    caps: TextCapitalization.characters,
                    inputFormatters: gstinInputFormatters,
                  ),
                  const SizedBox(height: 14),
                  _OnboardField(
                    ctrl: upiC,
                    label: 'UPI ID',
                    hint: 'yourname@upi',
                    kb: TextInputType.emailAddress,
                  ),
                ],
              ),
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
                      AnimatedSwitcher(
                        duration: Prefs.reduceMotion
                            ? Duration.zero
                            : const Duration(milliseconds: 180),
                        child: Text(
                          hasQr
                              ? 'Payment QR only, not an IRP e-invoice QR'
                              : 'Generated from your UPI ID for payment',
                          key: ValueKey(hasQr),
                          style:
                              TextStyle(color: T.muted(context), fontSize: 12),
                        ),
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
                  AnimatedSwitcher(
                    duration: Prefs.reduceMotion
                        ? Duration.zero
                        : const Duration(milliseconds: 180),
                    child: Text(
                      hasQr ? 'Remove' : 'Choose',
                      key: ValueKey('qr-action-$hasQr'),
                      style: TextStyle(
                        color: T.text(context),
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
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

// Version-one completion moment, kept intentionally simple.
class _CompletePage extends StatefulWidget {
  final bool loading;
  final VoidCallback onFinish;

  const _CompletePage({
    super.key,
    required this.loading,
    required this.onFinish,
  });

  @override
  State<_CompletePage> createState() => _CompletePageState();
}

class _CompletePageState extends State<_CompletePage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: Prefs.reduceMotion
          ? Duration.zero
          : const Duration(milliseconds: 600),
    )..forward();
    _scale = Tween<double>(
      begin: Prefs.reduceMotion ? 1 : 0.7,
      end: 1,
    ).animate(CurvedAnimation(parent: _controller, curve: kSpring));
    _fade = CurvedAnimation(parent: _controller, curve: kSpring);
  }

  @override
  void dispose() {
    _controller.dispose();
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
                    ? SizedBox(
                        height: 54,
                        child: Center(
                          child: SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 1.5,
                              color: T.text(context),
                            ),
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

class _CenteredOnboardLayout extends StatelessWidget {
  final Widget child;
  final Widget bottom;

  const _CenteredOnboardLayout({
    required this.child,
    required this.bottom,
  });

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) => Column(
          children: [
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(28, 20, 28, 20),
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 430),
                    child: _FadeSlideIn(order: 0, dy: 18, child: child),
                  ),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                28,
                12,
                28,
                MediaQuery.of(context).viewInsets.bottom > 0
                    ? MediaQuery.of(context).viewInsets.bottom + 16
                    : 32,
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 430),
                child: _FadeSlideIn(order: 3, dy: 10, child: bottom),
              ),
            ),
          ],
        ),
      );
}

class _StepLayout extends StatelessWidget {
  final String step;
  final double progressFrom;
  final double progress;
  final VoidCallback onBack;
  final Widget child;
  final Widget bottom;

  const _StepLayout({
    required this.step,
    required this.progressFrom,
    required this.progress,
    required this.onBack,
    required this.child,
    required this.bottom,
  });

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) => Column(
          children: [
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
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 12, 28, 0),
              child: _ProgressLine(from: progressFrom, value: progress),
            ),
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(28, 18, 28, 18),
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 430),
                    child: _FadeSlideIn(
                      key: ValueKey('content-$step'),
                      order: 0,
                      dy: 18,
                      child: child,
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                28,
                12,
                28,
                MediaQuery.of(context).viewInsets.bottom > 0
                    ? MediaQuery.of(context).viewInsets.bottom + 16
                    : 32,
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 430),
                child: _FadeSlideIn(
                  key: ValueKey('cta-$step'),
                  order: 2,
                  dy: 10,
                  child: bottom,
                ),
              ),
            ),
          ],
        ),
      );
}

class _OnboardPanel extends StatelessWidget {
  final Widget child;
  const _OnboardPanel({required this.child});

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: T.card(context),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: T.border(context), width: 0.5),
          boxShadow: T.dark(context) ? const [] : T.softShadow(context),
        ),
        child: child,
      );
}

class _ProgressLine extends StatelessWidget {
  final double from;
  final double value;
  const _ProgressLine({required this.from, required this.value});

  @override
  Widget build(BuildContext context) => Semantics(
        label: 'Setup progress',
        value: '${(value.clamp(0, 1) * 100).round()} percent',
        child: TweenAnimationBuilder<double>(
          tween: Tween(
            begin: from.clamp(0, 1).toDouble(),
            end: value.clamp(0, 1).toDouble(),
          ),
          duration: Prefs.reduceMotion
              ? Duration.zero
              : const Duration(milliseconds: 440),
          curve: Curves.easeOutCubic,
          builder: (context, animatedValue, _) => ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: SizedBox(
              height: 4,
              child: LayoutBuilder(
                builder: (context, constraints) => Stack(
                  children: [
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(color: T.border(context)),
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: SizedBox(
                        key: const ValueKey('onboarding-progress-fill'),
                        width: constraints.maxWidth * animatedValue,
                        height: 4,
                        child: DecoratedBox(
                          decoration: BoxDecoration(color: T.text(context)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
}

class _FadeSlideIn extends StatelessWidget {
  final Widget child;
  final int order;
  final double dy;

  const _FadeSlideIn({
    super.key,
    required this.child,
    this.order = 0,
    this.dy = 16,
  });

  @override
  Widget build(BuildContext context) {
    if (Prefs.reduceMotion) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 430 + order * 70),
      curve: kSmooth,
      child: child,
      builder: (context, value, child) {
        final start = (order * 0.14).clamp(0.0, 0.7);
        final eased = ((value - start) / (1 - start)).clamp(0.0, 1.0);
        return Opacity(
          opacity: eased,
          child: Transform.translate(
            offset: Offset(0, (1 - eased) * dy),
            child: child,
          ),
        );
      },
    );
  }
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

  const _OnboardField({
    required this.ctrl,
    required this.label,
    required this.hint,
    this.kb = TextInputType.text,
    this.caps = TextCapitalization.words,
    this.inputFormatters,
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
