import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets.dart';

class ClientFormPage extends StatefulWidget {
  final Customer? client;
  const ClientFormPage({super.key, this.client});

  @override
  State<ClientFormPage> createState() => _ClientFormPageState();
}

class _ClientFormPageState extends State<ClientFormPage> {
  late final TextEditingController _nameC;
  late final TextEditingController _emailC;
  late final TextEditingController _phoneC;
  late final TextEditingController _gstinC;
  late final TextEditingController _addrC;
  late final TextEditingController _stateC;

  bool get _editing => widget.client != null;

  @override
  void initState() {
    super.initState();
    final c = widget.client ?? Customer();
    _nameC = TextEditingController(text: c.name);
    _emailC = TextEditingController(text: c.email);
    _phoneC = TextEditingController(text: c.phone);
    _gstinC = TextEditingController(text: c.gstin);
    _addrC = TextEditingController(text: c.address);
    _stateC = TextEditingController(text: c.state);
  }

  @override
  void dispose() {
    _nameC.dispose();
    _emailC.dispose();
    _phoneC.dispose();
    _gstinC.dispose();
    _addrC.dispose();
    _stateC.dispose();
    super.dispose();
  }

  void _save() {
    if (_nameC.text.trim().isEmpty) {
      if (Prefs.haptics) HapticFeedback.mediumImpact();
      showAppSnack(context, 'Enter a client name');
      return;
    }
    if (!isValidGstin(_gstinC.text)) {
      if (Prefs.haptics) HapticFeedback.mediumImpact();
      showAppSnack(context, 'Enter a valid 15-character GSTIN');
      return;
    }
    final gstin = cleanGstin(_gstinC.text);
    if (gstin.isNotEmpty) {
      if (_addrC.text.trim().isEmpty) {
        showAppSnack(context, 'Add the registered billing address');
        return;
      }
      if (gstStateCode(_stateC.text) == null) {
        showAppSnack(context, 'Enter a valid Indian state');
        return;
      }
      if (!gstinMatchesState(gstin, _stateC.text)) {
        showAppSnack(context, 'GSTIN does not match the selected state');
        return;
      }
    }

    Navigator.pop(
      context,
      Customer(
        name: _nameC.text.trim(),
        email: _emailC.text.trim(),
        phone: _phoneC.text.trim(),
        address: _addrC.text.trim(),
        gstin: gstin,
        state: _stateC.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: T.bg(context),
        appBar: AppBar(
          backgroundColor: T.bg(context),
          elevation: 0,
          scrolledUnderElevation: 0,
          leading: IconButton(
            tooltip: _editing ? 'Back' : 'Close',
            onPressed: () => Navigator.pop(context),
            icon: Icon(
              _editing ? Icons.arrow_back_rounded : Icons.close_rounded,
              size: 20,
              color: T.text(context),
            ),
          ),
          title: Text(
            _editing ? 'Edit Client' : 'Add Client',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: T.text(context),
            ),
          ),
          centerTitle: true,
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 120),
          children: [
            _fieldLabel('Client name'),
            const SizedBox(height: 8),
            TextField(
              controller: _nameC,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              style: TextStyle(color: T.text(context), fontSize: 14),
              decoration: _fieldDecoration('Example Studio'),
            ),
            const SizedBox(height: 20),
            _fieldLabel('Email'),
            const SizedBox(height: 8),
            TextField(
              controller: _emailC,
              keyboardType: TextInputType.emailAddress,
              style: TextStyle(color: T.text(context), fontSize: 14),
              decoration: _fieldDecoration('client@example.com'),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _fieldLabel('Phone'),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _phoneC,
                        keyboardType: TextInputType.phone,
                        style: TextStyle(color: T.text(context), fontSize: 14),
                        decoration: _fieldDecoration('0000000000'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _fieldLabel('GSTIN'),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _gstinC,
                        textCapitalization: TextCapitalization.characters,
                        inputFormatters: gstinInputFormatters,
                        style: TextStyle(color: T.text(context), fontSize: 14),
                        decoration: _fieldDecoration('22AAAAA0000A1Z5'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _fieldLabel('Address'),
            const SizedBox(height: 8),
            TextField(
              controller: _addrC,
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
              style: TextStyle(color: T.text(context), fontSize: 14),
              decoration: _fieldDecoration('123 Example Street'),
            ),
            const SizedBox(height: 20),
            _fieldLabel('State / Place of supply'),
            const SizedBox(height: 8),
            TextField(
              controller: _stateC,
              textCapitalization: TextCapitalization.words,
              style: TextStyle(color: T.text(context), fontSize: 14),
              decoration: _fieldDecoration('Karnataka'),
            ),
          ],
        ),
        bottomNavigationBar: SafeArea(
          child: Container(
            color: T.bg(context),
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: AppButton(
              label: _editing ? 'Save Changes' : 'Save Client',
              onTap: _save,
            ),
          ),
        ),
      );

  Widget _fieldLabel(String t) => Text(
        t,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: T.muted(context),
          letterSpacing: 0,
        ),
      );

  InputDecoration _fieldDecoration(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: T.faint(context), fontSize: 14),
        filled: true,
        fillColor: T.card(context),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(22),
          borderSide: BorderSide(color: T.border(context), width: 0.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(22),
          borderSide: BorderSide(color: T.border(context), width: 0.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(22),
          borderSide: BorderSide(
            color: T.accent(context).withValues(alpha: 0.26),
            width: 1,
          ),
        ),
      );
}
