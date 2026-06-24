import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../models.dart';
import '../pdf_builder.dart';
import '../theme.dart';
import '../widgets.dart';

class PdfPreviewPage extends StatefulWidget {
  final Invoice invoice;
  const PdfPreviewPage({super.key, required this.invoice});

  @override
  State<PdfPreviewPage> createState() => _PdfPreviewPageState();
}

class _PdfPreviewPageState extends State<PdfPreviewPage> {
  late Future<_RenderedPdf> _future;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _future = _render();
  }

  Future<_RenderedPdf> _render() async {
    final bytes =
        await buildPdf(widget.invoice).timeout(const Duration(seconds: 10));
    final pages = <Uint8List>[];
    final raster = Printing.raster(bytes, dpi: 120).timeout(
      const Duration(seconds: 12),
      onTimeout: (sink) => sink.close(),
    );
    await for (final page in raster) {
      pages.add(await page.toPng());
    }
    if (pages.isEmpty) {
      throw StateError('PDF preview timed out');
    }
    return _RenderedPdf(bytes: bytes, pages: pages);
  }

  Future<void> _share(Uint8List bytes) async {
    try {
      await Printing.sharePdf(
              bytes: bytes, filename: '${widget.invoice.num}.pdf')
          .timeout(const Duration(seconds: 20));
    } catch (_) {
      if (!mounted) return;
      _snack('Could not open share sheet');
    }
  }

  void _retry() {
    setState(() => _future = _render());
  }

  void _snack(String text) {
    showAppSnack(context, text);
  }

  Future<void> _save(Uint8List bytes) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final path = await savePdfBytes(bytes, widget.invoice.num);
      if (!mounted) return;
      _snack('Saved PDF to $path');
    } catch (_) {
      if (!mounted) return;
      _snack('Could not save PDF');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: T.bg(context),
        appBar: AppBar(
          backgroundColor: T.bg(context),
          elevation: 0,
          scrolledUnderElevation: 0,
          leading: IconButton(
            tooltip: 'Close preview',
            onPressed: () => Navigator.pop(context),
            icon: Icon(Icons.close_rounded, size: 20, color: T.text(context)),
          ),
          title: Text('PDF Preview',
              style: TextStyle(
                  color: T.text(context),
                  fontSize: 16,
                  fontWeight: FontWeight.w700)),
          centerTitle: true,
        ),
        body: FutureBuilder<_RenderedPdf>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  CircularProgressIndicator(
                      color: T.faint(context), strokeWidth: 1.5),
                  const SizedBox(height: 14),
                  Text('Preparing PDF',
                      style: TextStyle(color: T.muted(context), fontSize: 13)),
                ]),
              );
            }
            if (snap.hasError || !snap.hasData || snap.data!.pages.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.picture_as_pdf_outlined,
                        color: T.faint(context), size: 34),
                    const SizedBox(height: 12),
                    Text('Could not render PDF',
                        style: TextStyle(
                            color: T.text(context),
                            fontSize: 15,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    Text(
                        'Try again, or share the invoice from the previous screen.',
                        textAlign: TextAlign.center,
                        style:
                            TextStyle(color: T.muted(context), fontSize: 13)),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _retry,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: T.inverse(context),
                        foregroundColor: T.onInverse(context),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      child: const Text('Retry'),
                    ),
                  ]),
                ),
              );
            }

            final rendered = snap.data!;
            return Column(children: [
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(18, 14, 18, 22),
                  itemCount: rendered.pages.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 14),
                  itemBuilder: (_, i) => Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: T.border(context), width: 0.5),
                      boxShadow: T.dark(context)
                          ? const []
                          : const [
                              BoxShadow(
                                color: Color(0x12000000),
                                blurRadius: 18,
                                offset: Offset(0, 8),
                              ),
                            ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: InteractiveViewer(
                      minScale: 1,
                      maxScale: 4,
                      boundaryMargin: const EdgeInsets.all(80),
                      child: Image.memory(
                        rendered.pages[i],
                        fit: BoxFit.fitWidth,
                        width: double.infinity,
                        gaplessPlayback: true,
                      ),
                    ),
                  ),
                ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 8, 18, 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed:
                              _saving ? null : () => _save(rendered.bytes),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: T.text(context),
                            disabledForegroundColor: T.faint(context),
                            side: BorderSide(color: T.border(context)),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                            padding: const EdgeInsets.symmetric(vertical: 15),
                          ),
                          icon: _saving
                              ? SizedBox(
                                  width: 15,
                                  height: 15,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 1.5,
                                      color: T.faint(context)),
                                )
                              : const Icon(Icons.download_rounded, size: 17),
                          label: const Text('Download',
                              style: TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.w700)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _share(rendered.bytes),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: T.inverse(context),
                            foregroundColor: T.onInverse(context),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                            padding: const EdgeInsets.symmetric(vertical: 15),
                          ),
                          icon: const Icon(Icons.share_rounded, size: 17),
                          label: const Text('Share',
                              style: TextStyle(
                                  fontSize: 14, fontWeight: FontWeight.w700)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ]);
          },
        ),
      );
}

class _RenderedPdf {
  final Uint8List bytes;
  final List<Uint8List> pages;
  const _RenderedPdf({required this.bytes, required this.pages});
}
