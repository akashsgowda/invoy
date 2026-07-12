import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'theme.dart';
import 'models.dart';

// ─── Format Helpers ──────────────────────────────────────────────

final NumberFormat _moneyFormat = NumberFormat('#,##,##0.00', 'en_IN');
final NumberFormat _compactBaseFormat = NumberFormat('#,##0', 'en_IN');
final DateFormat _dateFormat = DateFormat('d MMM yyyy');

final gstinInputFormatters = <TextInputFormatter>[
  FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
  LengthLimitingTextInputFormatter(15),
  _UpperCaseTextFormatter(),
];

String cleanGstin(String value) => value.trim().toUpperCase();

bool isValidGstin(String value) {
  final raw = cleanGstin(value);
  if (raw.isEmpty) return true;
  return RegExp(r'^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z][1-9A-Z]Z[0-9A-Z]$')
      .hasMatch(raw);
}

bool isValidUpiId(String value) {
  final raw = value.trim();
  if (raw.isEmpty) return true;
  return RegExp(r'^[A-Za-z0-9._-]{2,256}@[A-Za-z0-9.-]{2,64}$').hasMatch(raw);
}

class _UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) =>
      newValue.copyWith(text: newValue.text.toUpperCase());
}

String amt(double v) => '₹${_moneyFormat.format(v)}';

String amtCompact(double v) {
  final abs = v.abs();
  final sign = v < 0 ? '-' : '';
  if (abs >= 1000000000000) {
    return '$sign₹${_compactUnit(abs / 1000000000000)}T';
  }
  if (abs >= 10000000) return '$sign₹${_compactUnit(abs / 10000000)}Cr';
  if (abs >= 100000) return '$sign₹${_compactUnit(abs / 100000)}L';
  if (abs >= 1000) return '$sign₹${_compactUnit(abs / 1000)}K';
  return '$sign₹${_compactBaseFormat.format(abs)}';
}

String amtUi(double v, {int maxChars = 18}) {
  final full = amt(v);
  if (full.length <= maxChars) return full;
  return amtCompact(v);
}

String _compactUnit(double value) {
  final fixed = value >= 100
      ? value.toStringAsFixed(0)
      : value >= 10
          ? value.toStringAsFixed(1)
          : value.toStringAsFixed(2);
  return fixed.replaceFirst(RegExp(r'\.?0+$'), '');
}

String amtK(double v) {
  return amtCompact(v);
}

String fDate(DateTime d) => _dateFormat.format(d);

SnackBar appSnackBar(
  BuildContext context,
  String message, {
  Duration duration = const Duration(seconds: 2),
}) =>
    SnackBar(
      content: Text(
        message,
        style: TextStyle(
          color: T.onInverse(context),
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
      ),
      behavior: SnackBarBehavior.floating,
      backgroundColor: T.inverse(context),
      duration: duration,
      margin: const EdgeInsets.fromLTRB(18, 0, 18, 18),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    );

void showAppSnack(
  BuildContext context,
  String message, {
  Duration duration = const Duration(seconds: 2),
}) {
  final messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(appSnackBar(context, message, duration: duration));
}

// ─── Spring Tap ──────────────────────────────────────────────────
// Wrap ANY tappable widget with this for a spring press effect.
// Uses a single AnimationController — ultra cheap, safe on low-end.

class SpringTap extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double scale;
  final double hoverScale;
  final bool haptic;
  final Duration tapDelay;

  const SpringTap({
    super.key,
    required this.child,
    this.onTap,
    this.scale = 0.975,
    this.hoverScale = 1.008,
    this.haptic = true,
    this.tapDelay = Duration.zero,
  });

  @override
  State<SpringTap> createState() => _SpringTapState();
}

class _SpringTapState extends State<SpringTap>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ac;
  late final Animation<double> _scaleAnim;
  bool _hovered = false;

  @override
  void initState() {
    super.initState();
    _ac = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 90),
      reverseDuration: const Duration(milliseconds: 240),
    );
    _scaleAnim = Tween<double>(
      begin: 1.0,
      end: widget.scale,
    ).animate(
      CurvedAnimation(
        parent: _ac,
        curve: kSmooth,
        reverseCurve: kPop,
      ),
    );
  }

  @override
  void dispose() {
    _ac.dispose();
    super.dispose();
  }

  void _down(TapDownDetails _) {
    _ac.duration =
        Prefs.reduceMotion ? Duration.zero : const Duration(milliseconds: 90);
    if (widget.haptic && Prefs.haptics) HapticFeedback.selectionClick();
    _ac.forward();
  }

  void _up(TapUpDetails _) {
    _ac.reverseDuration =
        Prefs.reduceMotion ? Duration.zero : const Duration(milliseconds: 240);
    _ac.reverse();
    if (widget.tapDelay == Duration.zero) {
      widget.onTap?.call();
      return;
    }
    Future.delayed(widget.tapDelay, () {
      if (!mounted) return;
      widget.onTap?.call();
    });
  }

  void _cancel() => _ac.reverse();

  @override
  Widget build(BuildContext context) => MouseRegion(
        onEnter: widget.onTap == null
            ? null
            : (_) => setState(() => _hovered = true),
        onExit: widget.onTap == null
            ? null
            : (_) => setState(() => _hovered = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: widget.onTap == null ? null : _down,
          onTapUp: widget.onTap == null ? null : _up,
          onTapCancel: widget.onTap == null ? null : _cancel,
          child: AnimatedBuilder(
            animation: _scaleAnim,
            builder: (_, child) {
              final hoverScale =
                  _hovered && widget.onTap != null ? widget.hoverScale : 1.0;
              return Transform.scale(
                scale: _scaleAnim.value * hoverScale,
                child: child,
              );
            },
            child: widget.child,
          ),
        ),
      );
}

// ─── Avatar ──────────────────────────────────────────────────────

class InvAvatar extends StatelessWidget {
  final Invoice inv;
  final double radius;
  const InvAvatar({super.key, required this.inv, this.radius = 20});

  @override
  Widget build(BuildContext context) => CircleAvatar(
        radius: radius,
        backgroundColor: inv.avatarColor,
        child: Text(
          inv.initials,
          style: TextStyle(
            color: C.white,
            fontWeight: FontWeight.w600,
            fontSize: radius * 0.62,
          ),
        ),
      );
}

// ─── Status Pill ─────────────────────────────────────────────────

class StatusPill extends StatelessWidget {
  final Invoice inv;
  final bool emphatic;
  const StatusPill({super.key, required this.inv, this.emphatic = false});

  Color _bg(BuildContext context) {
    if (!emphatic) {
      return T.subtle(context);
    }
    if (T.dark(context)) return inv.statusBg;
    if (inv.isPartPaid) {
      return inv.isOverdue ? const Color(0xFFFDECEC) : const Color(0xFFEDEFF2);
    }
    switch (inv.displayStatus) {
      case Status.paid:
        return const Color(0xFFEAF7EF);
      case Status.overdue:
        return const Color(0xFFFDECEC);
      case Status.draft:
        return const Color(0xFFEDEFF2);
      default:
        return const Color(0xFFFFF4DE);
    }
  }

  Color _fg(BuildContext context) {
    if (emphatic) return inv.statusColor;
    if (inv.displayStatus != Status.draft || inv.isPartPaid) {
      return inv.statusColor;
    }
    return T.muted(context);
  }

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: _bg(context),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: T.border(context).withValues(alpha: 0.56),
            width: 0.45,
          ),
        ),
        child: Text(
          inv.statusLabel,
          style: TextStyle(
            color: _fg(context),
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 0,
          ),
        ),
      );
}

// ─── Bottom Sheet Wrapper ────────────────────────────────────────

class AppSheet extends StatelessWidget {
  final Widget child;
  final bool dark;
  const AppSheet({super.key, required this.child, this.dark = true});

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: T.surface(context),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border(top: BorderSide(color: T.border(context), width: 0.5)),
          boxShadow: T.softShadow(context),
        ),
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 8,
          bottom: MediaQuery.of(context).viewInsets.bottom + 32,
        ),
        child: SingleChildScrollView(
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
              child,
            ],
          ),
        ),
      );
}

class AppSearchField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final String hint;
  final ValueChanged<String> onChanged;
  final VoidCallback? onClear;
  final bool autofocus;

  const AppSearchField({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.hint,
    required this.onChanged,
    this.onClear,
    this.autofocus = false,
  });

  @override
  Widget build(BuildContext context) {
    final focused = focusNode.hasFocus;
    final hasText = controller.text.isNotEmpty;
    return AnimatedContainer(
      duration: Prefs.reduceMotion
          ? Duration.zero
          : const Duration(milliseconds: 180),
      curve: kSmooth,
      height: 50,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: focused ? T.surface(context) : T.card(context),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: focused
              ? T.accent(context).withValues(alpha: 0.26)
              : T.border(context).withValues(alpha: 0.78),
          width: 0.7,
        ),
        boxShadow: focused
            ? T.glow(context)
            : (T.dark(context) ? const [] : T.softShadow(context)),
      ),
      child: Row(
        children: [
          const SizedBox(width: 15),
          Icon(
            Icons.search_rounded,
            size: 19,
            color: focused ? T.text(context) : T.muted(context),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              focusNode: focusNode,
              controller: controller,
              autofocus: autofocus,
              onChanged: onChanged,
              style: TextStyle(color: T.text(context), fontSize: 14),
              decoration: InputDecoration(
                isCollapsed: true,
                filled: false,
                hintText: hint,
                hintStyle: TextStyle(color: T.faint(context), fontSize: 14),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
              ),
            ),
          ),
          AnimatedSwitcher(
            duration: Prefs.reduceMotion
                ? Duration.zero
                : const Duration(milliseconds: 140),
            switchInCurve: kSmooth,
            switchOutCurve: Curves.easeInCubic,
            child: hasText && onClear != null
                ? SpringTap(
                    key: const ValueKey('clear'),
                    onTap: onClear,
                    scale: 0.9,
                    child: Padding(
                      padding: const EdgeInsets.all(13),
                      child: Icon(
                        Icons.close_rounded,
                        size: 16,
                        color: T.muted(context),
                      ),
                    ),
                  )
                : const SizedBox(
                    key: ValueKey('empty'),
                    width: 15,
                  ),
          ),
        ],
      ),
    );
  }
}

enum AppButtonTone { primary, secondary, ghost, danger }

class AppButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final IconData? icon;
  final bool loading;
  final AppButtonTone tone;
  final double height;

  const AppButton({
    super.key,
    required this.label,
    required this.onTap,
    this.icon,
    this.loading = false,
    this.tone = AppButtonTone.primary,
    this.height = 52,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null && !loading;
    final primary = T.inverse(context);
    final onPrimary = T.onInverse(context);
    const destructive = C.overdue;
    final colors = switch (tone) {
      AppButtonTone.primary => (
          primary,
          onPrimary,
          [...T.buttonShadow(context), ...T.glow(context)],
        ),
      AppButtonTone.secondary => (
          T.card(context).withValues(alpha: T.dark(context) ? 0.78 : 0.96),
          T.text(context),
          T.dark(context) ? const <BoxShadow>[] : T.shadow(context),
        ),
      AppButtonTone.ghost => (
          Colors.transparent,
          T.text(context),
          const <BoxShadow>[],
        ),
      AppButtonTone.danger => (
          destructive,
          C.white,
          T.dark(context) ? const <BoxShadow>[] : T.buttonShadow(context),
        ),
    };
    final bg = enabled ? colors.$1 : T.subtle(context);
    final fg = enabled ? colors.$2 : T.muted(context);

    return SpringTap(
      onTap: enabled ? onTap : null,
      scale: 0.965,
      hoverScale: enabled ? 1.008 : 1,
      child: AnimatedContainer(
        duration: Prefs.reduceMotion
            ? Duration.zero
            : const Duration(milliseconds: 180),
        curve: kSmooth,
        height: height,
        width: double.infinity,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: tone == AppButtonTone.primary || tone == AppButtonTone.danger
                ? fg.withValues(alpha: 0.10)
                : T.border(context).withValues(alpha: 0.72),
            width: 0.7,
          ),
          boxShadow: enabled ? colors.$3 : const [],
        ),
        child: Stack(
          children: [
            if (tone == AppButtonTone.primary || tone == AppButtonTone.danger)
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        fg.withValues(alpha: 0.055),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            Center(
              child: AnimatedSwitcher(
                duration: Prefs.reduceMotion
                    ? Duration.zero
                    : const Duration(milliseconds: 140),
                child: loading
                    ? SizedBox(
                        key: const ValueKey('loading'),
                        width: 17,
                        height: 17,
                        child: CircularProgressIndicator(
                          strokeWidth: 1.7,
                          color: fg,
                        ),
                      )
                    : Row(
                        key: ValueKey(label),
                        mainAxisSize: MainAxisSize.max,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (icon != null) ...[
                            Icon(icon, color: fg, size: 18),
                            const SizedBox(width: 8),
                          ],
                          Flexible(
                            child: Text(
                              label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: fg,
                                fontSize: 13.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0,
                              ),
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Section Label ───────────────────────────────────────────────

class SecLabel extends StatelessWidget {
  final String text;
  const SecLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(0, 0, 0, 10),
        child: Text(
          text.toUpperCase(),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: T.faint(context),
            letterSpacing: 0.2,
          ),
        ),
      );
}

// ─── Card Container ──────────────────────────────────────────────

class AppCard extends StatelessWidget {
  final List<Widget> children;
  final bool dark;
  final EdgeInsets? padding;

  const AppCard({
    super.key,
    required this.children,
    required this.dark,
    this.padding,
  });

  @override
  Widget build(BuildContext context) => Container(
        padding: padding,
        decoration: BoxDecoration(
          color: T.card(context),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: T.border(context), width: 0.5),
          boxShadow: T.dark(context) ? const [] : T.softShadow(context),
        ),
        child: Column(children: children),
      );
}

// ─── Form Row ────────────────────────────────────────────────────

class FRow extends StatelessWidget {
  final String label, value;
  final bool dark;
  final VoidCallback? onTap;

  const FRow(this.label, this.value, this.dark, {super.key, this.onTap});

  @override
  Widget build(BuildContext context) => SpringTap(
        onTap: onTap,
        scale: 0.97,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            children: [
              Text(label,
                  style: TextStyle(fontSize: 14, color: T.muted(context))),
              const Spacer(),
              Text(
                value,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: T.faint(context),
                ),
              ),
              const SizedBox(width: 6),
              Icon(Icons.chevron_right_rounded,
                  size: 16, color: T.faint(context)),
            ],
          ),
        ),
      );
}

// ─── Action Row ──────────────────────────────────────────────────

class ARow extends StatelessWidget {
  final String label;
  final String? sub;
  final bool dark;
  final VoidCallback? onTap;

  const ARow({
    super.key,
    required this.label,
    this.sub,
    required this.dark,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) => SpringTap(
        onTap: onTap,
        scale: 0.97,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: T.text(context),
                    ),
                  ),
                  if (sub != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      sub!,
                      style: TextStyle(fontSize: 12, color: T.faint(context)),
                    ),
                  ],
                ],
              ),
              const Spacer(),
              Icon(Icons.chevron_right_rounded,
                  size: 16, color: T.faint(context)),
            ],
          ),
        ),
      );
}

// ─── Total Line ──────────────────────────────────────────────────

class TLine extends StatelessWidget {
  final String label, value;
  final bool dark, sub;
  final Color? color;

  const TLine(
    this.label,
    this.value,
    this.dark, {
    super.key,
    this.sub = false,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? (sub ? T.faint(context) : T.text(context));
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: sub ? 12 : 13, color: c),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: sub ? 12 : 13,
            color: c,
            fontWeight: sub ? FontWeight.w400 : FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

// ─── Divider ─────────────────────────────────────────────────────

class ADivider extends StatelessWidget {
  final double indent;
  const ADivider({super.key, this.indent = 20});

  @override
  Widget build(BuildContext context) =>
      Divider(height: 1, indent: indent, color: T.divider(context));
}

// ─── Toggle Row ──────────────────────────────────────────────────

class ToggleRow extends StatelessWidget {
  final String label;
  final String? sub;
  final bool value, dark;
  final void Function(bool) onChanged;

  const ToggleRow({
    super.key,
    required this.label,
    this.sub,
    required this.value,
    required this.dark,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 14, 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(fontSize: 14, color: T.text(context)),
                  ),
                  if (sub != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      sub!,
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
}

// ─── Empty State ─────────────────────────────────────────────────

class EmptyState extends StatefulWidget {
  final IconData icon;
  final String message;
  final String? subtitle;
  final String? ctaLabel;
  final VoidCallback? ctaOnTap;

  const EmptyState({
    super.key,
    required this.icon,
    required this.message,
    this.subtitle,
    this.ctaLabel,
    this.ctaOnTap,
  });

  @override
  State<EmptyState> createState() => _EmptyStateState();
}

class _EmptyStateState extends State<EmptyState>
    with SingleTickerProviderStateMixin {
  late AnimationController _ac;
  late Animation<double> _fade;
  late Animation<double> _slide;

  @override
  void initState() {
    super.initState();
    _ac = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..forward();
    _fade = CurvedAnimation(parent: _ac, curve: kSmooth);
    _slide = Tween(
      begin: 14.0,
      end: 0.0,
    ).animate(CurvedAnimation(parent: _ac, curve: kSmooth));
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
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      color: T.subtle(context),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: T.border(context), width: 0.5),
                    ),
                    child: Icon(widget.icon, size: 28, color: T.muted(context)),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    widget.message,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: T.muted(context),
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (widget.subtitle != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      widget.subtitle!,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: T.faint(context), fontSize: 13),
                    ),
                  ],
                  if (widget.ctaLabel != null && widget.ctaOnTap != null) ...[
                    const SizedBox(height: 24),
                    SpringTap(
                      onTap: widget.ctaOnTap,
                      child: Container(
                        width: 180,
                        height: 48,
                        decoration: BoxDecoration(
                          color: T.inverse(context),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Center(
                          child: Text(
                            widget.ctaLabel!,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: T.onInverse(context),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      );
}

// ─── Pick Sheet ──────────────────────────────────────────────────

class PickSheet extends StatelessWidget {
  final String title;
  final List<String> items;
  final int sel;
  final void Function(int) onSel;
  final bool dark;

  const PickSheet({
    super.key,
    required this.title,
    required this.items,
    required this.sel,
    required this.onSel,
    this.dark = true,
  });

  @override
  Widget build(BuildContext context) => AppSheet(
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
            ...items.asMap().entries.map(
                  (e) => SpringTap(
                    onTap: () {
                      onSel(e.key);
                      Navigator.pop(context);
                    },
                    scale: 0.97,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      child: Row(
                        children: [
                          Text(
                            e.value,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: e.key == sel
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                              color: e.key == sel
                                  ? T.text(context)
                                  : T.faint(context),
                            ),
                          ),
                          const Spacer(),
                          if (e.key == sel)
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

// ─── Edit Sheet ──────────────────────────────────────────────────

class EditSheet extends StatelessWidget {
  final String title;
  final TextEditingController ctrl;
  final String? hint;
  final bool dark;

  const EditSheet({
    super.key,
    required this.title,
    required this.ctrl,
    this.hint,
    this.dark = true,
  });

  @override
  Widget build(BuildContext context) => AppSheet(
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
            TextField(
              controller: ctrl,
              autofocus: true,
              style: TextStyle(color: T.text(context)),
              decoration: InputDecoration(hintText: hint ?? title),
            ),
            const SizedBox(height: 20),
            AppButton(
              label: 'Save',
              onTap: () => Navigator.pop(context, ctrl.text.trim()),
            ),
          ],
        ),
      );
}

// ─── Pay Sheet ───────────────────────────────────────────────────

class PaySheet extends StatefulWidget {
  final double remaining;
  final bool dark;
  final bool fullPayment;
  const PaySheet({
    super.key,
    required this.remaining,
    this.dark = true,
    this.fullPayment = false,
  });

  @override
  State<PaySheet> createState() => _PaySheetState();
}

class _PaySheetState extends State<PaySheet> {
  late final TextEditingController _amtC;
  DateTime _date = DateTime.now();
  PayMode _mode = PayMode.upi;
  String? _error;

  @override
  void initState() {
    super.initState();
    _amtC = TextEditingController(text: _moneyInput(widget.remaining));
  }

  @override
  void dispose() {
    _amtC.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: T.dark(context)
              ? const ColorScheme.dark(primary: Colors.white)
              : const ColorScheme.light(primary: Colors.black),
        ),
        child: child!,
      ),
    );
    if (!mounted || d == null) return;
    setState(() => _date = d);
  }

  String _moneyInput(double value) {
    if (value == value.roundToDouble()) return value.toStringAsFixed(0);
    return value.toStringAsFixed(2);
  }

  double _enteredAmount() {
    final raw = _amtC.text
        .trim()
        .replaceAll('₹', '')
        .replaceAll(',', '')
        .replaceAll(' ', '');
    return double.tryParse(raw) ?? 0;
  }

  String get _confirmLabel {
    if (widget.fullPayment) return 'Mark as paid';
    final amount = _enteredAmount();
    if (amount >= widget.remaining && widget.remaining > 0) {
      return 'Record full payment';
    }
    return 'Record partial payment';
  }

  void _fillFullBalance() {
    _amtC.text = _moneyInput(widget.remaining);
    _amtC.selection = TextSelection.collapsed(offset: _amtC.text.length);
    setState(() => _error = null);
  }

  void _submit() {
    final entered = widget.fullPayment ? widget.remaining : _enteredAmount();
    if (!entered.isFinite || entered <= 0) {
      setState(() => _error = 'Enter an amount received');
      return;
    }
    final amount = entered > widget.remaining ? widget.remaining : entered;
    Navigator.pop(context, Payment(amount: amount, date: _date, mode: _mode));
  }

  @override
  Widget build(BuildContext context) => AppSheet(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.fullPayment ? 'Mark as paid' : 'Record payment',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: T.text(context),
              ),
            ),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              decoration: BoxDecoration(
                color: T.subtle(context),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: T.border(context), width: 0.5),
              ),
              child: Row(
                children: [
                  Text(
                    'Balance due',
                    style: TextStyle(
                      color: T.muted(context),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      amtUi(widget.remaining),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        color: T.text(context),
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            if (!widget.fullPayment) ...[
              Row(
                children: [
                  Text(
                    'Amount received',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: T.faint(context),
                      letterSpacing: 0.2,
                    ),
                  ),
                  const Spacer(),
                  SpringTap(
                    onTap: _fillFullBalance,
                    scale: 0.96,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: T.subtle(context),
                        borderRadius: BorderRadius.circular(999),
                        border:
                            Border.all(color: T.border(context), width: 0.5),
                      ),
                      child: Text(
                        'Full balance',
                        style: TextStyle(
                          color: T.text(context),
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _amtC,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  LengthLimitingTextInputFormatter(24),
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                ],
                onChanged: (_) => setState(() => _error = null),
                style: TextStyle(color: T.text(context), fontSize: 15),
                decoration: InputDecoration(
                  prefixText: '₹ ',
                  hintText: _moneyInput(widget.remaining),
                ),
              ),
            ] else
              Text(
                'Choose how and when the full payment was received.',
                style: TextStyle(
                  color: T.muted(context),
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: const TextStyle(
                  color: C.overdue,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            const SizedBox(height: 16),
            SpringTap(
              onTap: _pickDate,
              scale: 0.97,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                decoration: BoxDecoration(
                  color: T.subtle(context),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: T.border(context), width: 0.5),
                ),
                child: Row(
                  children: [
                    Text(
                      'Date',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: T.faint(context),
                        letterSpacing: 0.2,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      fDate(_date),
                      style: TextStyle(
                        fontSize: 14,
                        color: T.text(context),
                        fontWeight: FontWeight.w500,
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
            ),
            const SizedBox(height: 16),
            Row(
              children: PayMode.values.map((m) {
                final active = _mode == m;
                return Expanded(
                  child: SpringTap(
                    onTap: () => setState(() => _mode = m),
                    scale: 0.95,
                    child: AnimatedContainer(
                      duration: Prefs.reduceMotion
                          ? Duration.zero
                          : const Duration(milliseconds: 180),
                      curve: kSmooth,
                      margin: const EdgeInsets.only(right: 6),
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      decoration: BoxDecoration(
                        color: active ? T.inverse(context) : T.subtle(context),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color:
                              active ? Colors.transparent : T.border(context),
                          width: 0.5,
                        ),
                      ),
                      child: Text(
                        m.name.toUpperCase(),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color:
                              active ? T.onInverse(context) : T.faint(context),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 28),
            AppButton(label: _confirmLabel, onTap: _submit),
          ],
        ),
      );
}
