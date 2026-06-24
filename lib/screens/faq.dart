import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme.dart';
import '../widgets.dart';

class _FaqItem {
  final String q, a;
  const _FaqItem(this.q, this.a);
}

class _FaqSection {
  final String title;
  final IconData icon;
  final List<_FaqItem> items;
  const _FaqSection(this.title, this.icon, this.items);
}

const _kSections = [
  _FaqSection('Invoices', Icons.receipt_long_rounded, [
    _FaqItem(
      'How do I create an invoice?',
      'Tap "Quick Invoice" on the Dashboard, or the + button on the Invoices tab. Add a client, line items, and tap Create Invoice.',
    ),
    _FaqItem(
      'How do I mark an invoice as paid?',
      'Open the invoice, tap "Settle invoice," then choose "Mark as paid" or "Record partial payment." Invoy keeps the remaining balance visible.',
    ),
    _FaqItem(
      'What does Overdue mean?',
      'An invoice is Overdue when it\'s unpaid and the due date has passed. Invoy calculates this automatically.',
    ),
    _FaqItem(
      'Will my data be deleted if I uninstall?',
      'Yes — Invoy stores data locally on your device. Uninstalling clears everything. Save PDFs of important invoices as a backup.',
    ),
  ]),
  _FaqSection('GST & Taxes', Icons.account_balance_rounded, [
    _FaqItem(
      'What is Split GST (CGST + SGST)?',
      'For sales within the same state, GST is split equally into CGST and SGST (e.g. 18% → 9% + 9%). Toggle this in Settings or per invoice.',
    ),
    _FaqItem(
      'Does Invoy file GST returns?',
      'No — Invoy generates invoices only. Use your PDFs as reference when filing on the GST portal or with your CA.',
    ),
  ]),
  _FaqSection('Troubleshooting', Icons.build_rounded, [
    _FaqItem(
      'The PDF isn\'t generating.',
      'Make sure the invoice has at least one line item. If it still fails, restart the app or open a GitHub issue.',
    ),
    _FaqItem(
      'WhatsApp isn\'t opening directly.',
      'Make sure the client\'s phone number is saved on the invoice. Without a number, Invoy falls back to the system share sheet.',
    ),
  ]),
];

class FaqPage extends StatefulWidget {
  const FaqPage({super.key});
  @override
  State<FaqPage> createState() => _FaqPageState();
}

class _FaqPageState extends State<FaqPage> {
  String? _openKey;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final bg = dark ? C.dkBg : const Color(0xFFF5F5F5);
    final surf = dark ? C.dkCard : C.white;
    final border = dark ? C.dkBorder : C.grey1;
    final textPrimary = dark ? C.white : C.black;
    final textSecondary =
        dark ? const Color(0xFF999999) : const Color(0xFF666666);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: dark ? C.dkSurf : C.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          tooltip: 'Back',
          icon: Icon(Icons.arrow_back_rounded, size: 18, color: textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('FAQ',
            style: TextStyle(
                fontSize: 17, fontWeight: FontWeight.w700, color: textPrimary)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(0.5),
          child: Divider(height: 0.5, color: border),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.only(top: 16, bottom: 40),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text('Quick answers to common questions.',
                style:
                    TextStyle(fontSize: 13, color: textSecondary, height: 1.5)),
          ),
          const SizedBox(height: 20),
          for (var si = 0; si < _kSections.length; si++) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(children: [
                Icon(_kSections[si].icon, size: 14, color: textSecondary),
                const SizedBox(width: 6),
                Text(_kSections[si].title.toUpperCase(),
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: textSecondary,
                        letterSpacing: 0.8)),
              ]),
            ),
            const SizedBox(height: 8),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: surf,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: border, width: 0.5),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Column(children: [
                  for (var ii = 0; ii < _kSections[si].items.length; ii++) ...[
                    if (ii > 0) Divider(height: 0.5, color: border),
                    _FaqTile(
                      item: _kSections[si].items[ii],
                      isOpen: _openKey == '$si-$ii',
                      dark: dark,
                      textPrimary: textPrimary,
                      textSecondary: textSecondary,
                      onTap: () => setState(() {
                        final key = '$si-$ii';
                        _openKey = _openKey == key ? null : key;
                      }),
                    ),
                  ],
                ]),
              ),
            ),
            const SizedBox(height: 24),
          ],
          _SupportCard(
              dark: dark,
              surf: surf,
              border: border,
              textPrimary: textPrimary,
              textSecondary: textSecondary),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _FaqTile extends StatelessWidget {
  final _FaqItem item;
  final bool isOpen, dark;
  final Color textPrimary, textSecondary;
  final VoidCallback onTap;
  const _FaqTile(
      {required this.item,
      required this.isOpen,
      required this.dark,
      required this.textPrimary,
      required this.textSecondary,
      required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        behavior: HitTestBehavior.opaque,
        child: AnimatedSize(
          duration: const Duration(milliseconds: 260),
          curve: kSmooth,
          alignment: Alignment.topCenter,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(
                    child: Text(item.q,
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: textPrimary,
                            height: 1.4))),
                const SizedBox(width: 12),
                AnimatedRotation(
                  turns: isOpen ? 0.25 : 0,
                  duration: const Duration(milliseconds: 260),
                  curve: kSmooth,
                  child: Icon(Icons.chevron_right_rounded,
                      size: 18, color: textSecondary),
                ),
              ]),
              if (isOpen) ...[
                const SizedBox(height: 10),
                Text(item.a,
                    style: TextStyle(
                        fontSize: 13, color: textSecondary, height: 1.6)),
              ],
            ]),
          ),
        ),
      );
}

class _SupportCard extends StatelessWidget {
  final bool dark;
  final Color surf, border, textPrimary, textSecondary;
  const _SupportCard(
      {required this.dark,
      required this.surf,
      required this.border,
      required this.textPrimary,
      required this.textSecondary});

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
            color: surf,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: border, width: 0.5)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                  color:
                      dark ? const Color(0xFF1C1C1C) : const Color(0xFFF0F0F0),
                  borderRadius: BorderRadius.circular(10)),
              child:
                  Icon(Icons.bug_report_outlined, size: 18, color: textPrimary),
            ),
            const SizedBox(width: 12),
            Text('Still need help?',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: textPrimary)),
          ]),
          const SizedBox(height: 10),
          Text(
              'Open an issue in the project repository with the steps to reproduce.',
              style:
                  TextStyle(fontSize: 13, color: textSecondary, height: 1.5)),
          const SizedBox(height: 14),
          GestureDetector(
            onTap: () {
              HapticFeedback.mediumImpact();
              Clipboard.setData(
                  const ClipboardData(text: 'Invoy issue tracker'));
              showAppSnack(context, 'Issue tracker copied');
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
              decoration: BoxDecoration(
                  color:
                      dark ? const Color(0xFF1C1C1C) : const Color(0xFFF5F5F5),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: border, width: 0.5)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Invoy issue tracker',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: textPrimary)),
                  Icon(Icons.copy_rounded, size: 15, color: textSecondary),
                ],
              ),
            ),
          ),
        ]),
      );
}
