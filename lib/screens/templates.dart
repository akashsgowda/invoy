import 'package:flutter/material.dart';
import '../theme.dart';
import '../models.dart';
import '../widgets.dart';

class TemplatesPage extends StatefulWidget {
  const TemplatesPage({super.key});
  @override
  State<TemplatesPage> createState() => _TemplatesPageState();
}

class _TemplatesPageState extends State<TemplatesPage> {
  late String _sel;

  @override
  void initState() {
    super.initState();
    _sel = Prefs.defaultTemplate.value;
  }

  Future<void> _select(String name) async {
    if (_sel == name) return;
    setState(() => _sel = name);
    await Prefs.setDefaultTemplate(name);
    if (!mounted) return;
    showAppSnack(context, '$name set as default');
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: T.bg(context),
        appBar: AppBar(
          backgroundColor: T.bg(context),
          elevation: 0,
          scrolledUnderElevation: 0,
          leading: IconButton(
            tooltip: 'Back',
            onPressed: () => Navigator.pop(context),
            icon: Icon(Icons.arrow_back_rounded,
                size: 18, color: T.text(context)),
          ),
          title: Text(
            'PDF Style',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: T.text(context),
            ),
          ),
          centerTitle: true,
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 88),
          children: [
            Text(
              'Default style',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: T.muted(context),
              ),
            ),
            const SizedBox(height: 10),
            ...kTemplates.map(
              (t) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _TemplateRow(
                  tpl: t,
                  active: _sel == t.name,
                  onTap: () => _select(t.name),
                ),
              ),
            ),
          ],
        ),
      );
}

class _TemplateRow extends StatelessWidget {
  final InvTemplate tpl;
  final bool active;
  final VoidCallback onTap;
  const _TemplateRow({
    required this.tpl,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => SpringTap(
        onTap: onTap,
        scale: 0.975,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: kSmooth,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: T.card(context),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: active ? T.text(context) : T.border(context),
              width: active ? 1 : 0.5,
            ),
          ),
          child: Row(
            children: [
              _TemplatePreview(tpl: tpl),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tpl.name,
                      style: TextStyle(
                        color: T.text(context),
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      tpl.description,
                      style: TextStyle(color: T.muted(context), fontSize: 12),
                    ),
                  ],
                ),
              ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: kSmooth,
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: active ? T.inverse(context) : Colors.transparent,
                  shape: BoxShape.circle,
                  border: active
                      ? null
                      : Border.all(color: T.border(context), width: 1),
                ),
                child: active
                    ? Icon(
                        Icons.check_rounded,
                        color: T.onInverse(context),
                        size: 14,
                      )
                    : null,
              ),
            ],
          ),
        ),
      );
}

class _TemplatePreview extends StatelessWidget {
  final InvTemplate tpl;
  const _TemplatePreview({required this.tpl});

  @override
  Widget build(BuildContext context) => Container(
        width: 52,
        height: 64,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: T.border(context), width: 0.5),
          boxShadow: T.dark(context)
              ? const []
              : const [
                  BoxShadow(
                    color: Color(0x0F000000),
                    blurRadius: 10,
                    offset: Offset(0, 4),
                  ),
                ],
        ),
        clipBehavior: Clip.antiAlias,
        child: CustomPaint(painter: _TemplatePreviewPainter(tpl)),
      );
}

class _TemplatePreviewPainter extends CustomPainter {
  final InvTemplate tpl;
  const _TemplatePreviewPainter(this.tpl);

  @override
  void paint(Canvas canvas, Size size) {
    final ink = Paint()..color = const Color(0xFF111111);
    final primary = Paint()..color = tpl.primary;
    final accent = Paint()..color = tpl.accent;
    final soft = Paint()..color = const Color(0xFFE5E7EB);
    final mid = Paint()..color = const Color(0xFF9CA3AF);

    RRect rr(double x, double y, double w, double h, double r) =>
        RRect.fromRectAndRadius(Rect.fromLTWH(x, y, w, h), Radius.circular(r));

    void line(double x, double y, double w, {Paint? paint, double h = 2}) {
      canvas.drawRRect(rr(x, y, w, h, h / 2), paint ?? soft);
    }

    switch (tpl.name) {
      case 'Minimal':
        line(7, 9, 16, paint: primary, h: 3);
        line(7, 17, 32, paint: soft);
        line(7, 23, 24, paint: soft);
        canvas.drawLine(
          const Offset(7, 33),
          Offset(size.width - 7, 33),
          Paint()..color = const Color(0xFFD1D5DB),
        );
        line(7, 41, 38, paint: accent);
        line(7, 48, 26, paint: soft);
        line(size.width - 25, 56, 18, paint: primary, h: 3);
        break;
      case 'Ledger':
        canvas.drawRRect(rr(6, 7, size.width - 12, 15, 4), primary);
        line(10, 12, 17, paint: Paint()..color = Colors.white, h: 2);
        line(
          size.width - 22,
          12,
          12,
          paint: Paint()..color = Colors.white,
          h: 2,
        );
        canvas.drawRRect(rr(7, 28, 11, 8, 3), accent);
        canvas.drawRRect(rr(21, 28, 11, 8, 3), accent);
        canvas.drawRRect(rr(35, 28, 10, 8, 3), accent);
        for (final y in [44.0, 51.0, 58.0]) {
          canvas.drawLine(Offset(7, y), Offset(size.width - 7, y), mid);
        }
        break;
      case 'Compact':
        canvas.drawRRect(
          rr(13, 4, size.width - 26, size.height - 8, 2),
          Paint()..color = Colors.white,
        );
        canvas.drawRRect(
          rr(13, 4, size.width - 26, size.height - 8, 2),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 0.8
            ..color = const Color(0xFFE5E7EB),
        );
        line(18, 11, 16, paint: ink, h: 2.4);
        for (final x in [18.0, 26.0, 34.0]) {
          line(x, 21, 4, paint: primary, h: 1.2);
        }
        line(18, 30, 18, paint: primary, h: 3);
        for (final y in [40.0, 47.0, 54.0]) {
          line(18, y, 18, paint: soft, h: 1.3);
        }
        break;
      default:
        canvas.drawRect(Rect.fromLTWH(0, 0, size.width, 14), ink);
        line(7, 22, 20, paint: ink, h: 3);
        line(7, 31, 38, paint: soft);
        line(7, 39, 38, paint: soft);
        canvas.drawRRect(rr(7, 49, 38, 7, 2), soft);
    }
  }

  @override
  bool shouldRepaint(_TemplatePreviewPainter oldDelegate) =>
      oldDelegate.tpl != tpl;
}
