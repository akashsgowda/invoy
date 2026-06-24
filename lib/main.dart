import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'theme.dart';
import 'models.dart';
import 'screens/onboarding.dart';
import 'screens/shell.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
  ));
  runApp(const InvoyApp());
}

// ════════════════════════════════════════════════════════════════
// APP
// ════════════════════════════════════════════════════════════════

class InvoyApp extends StatelessWidget {
  const InvoyApp({super.key});

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<ThemeMode>(
        valueListenable: Prefs.themeMode,
        builder: (_, mode, __) => MaterialApp(
          title: 'Invoy',
          debugShowCheckedModeBanner: false,
          themeMode: mode,
          theme: buildTheme(false),
          darkTheme: buildTheme(true),
          themeAnimationDuration: const Duration(milliseconds: 220),
          themeAnimationCurve: kSmooth,
          builder: (context, child) {
            final dark = Theme.of(context).brightness == Brightness.dark;
            return AnnotatedRegion<SystemUiOverlayStyle>(
              value: SystemUiOverlayStyle(
                statusBarColor: Colors.transparent,
                statusBarIconBrightness:
                    dark ? Brightness.light : Brightness.dark,
                statusBarBrightness: dark ? Brightness.dark : Brightness.light,
                systemNavigationBarColor:
                    dark ? C.black : const Color(0xFFF4F5F7),
                systemNavigationBarIconBrightness:
                    dark ? Brightness.light : Brightness.dark,
              ),
              child: child ?? const SizedBox.shrink(),
            );
          },
          home: const _BootstrapRoot(),
        ),
      );
}

// ════════════════════════════════════════════════════════════════
// BOOTSTRAP — do critical startup after Flutter has rendered
// ════════════════════════════════════════════════════════════════

class _BootstrapRoot extends StatefulWidget {
  const _BootstrapRoot();

  @override
  State<_BootstrapRoot> createState() => _BootstrapRootState();
}

class _BootstrapRootState extends State<_BootstrapRoot> {
  late Future<void> _future;

  @override
  void initState() {
    super.initState();
    _future = _bootstrapAfterFirstFrame();
  }

  Future<void> _bootstrapAfterFirstFrame() async {
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    await _bootstrap();
  }

  Future<void> _bootstrap() async {
    await DB.init().timeout(const Duration(seconds: 10));
    await Prefs.load().timeout(const Duration(seconds: 4));
  }

  void _retry() {
    setState(() => _future = _bootstrap());
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<void>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const _StartupScreen();
          }
          if (snap.hasError) {
            return _StartupError(onRetry: _retry);
          }
          return const _Root();
        },
      );
}

class _StartupScreen extends StatelessWidget {
  const _StartupScreen();

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: T.bg(context),
        body: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                  strokeWidth: 1.6, color: T.muted(context)),
            ),
            const SizedBox(height: 18),
            Text('Starting Invoy',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: T.text(context))),
          ]),
        ),
      );
}

class _StartupError extends StatelessWidget {
  final VoidCallback onRetry;
  const _StartupError({required this.onRetry});

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: T.bg(context),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Spacer(),
                Text('Invoy could not start',
                    style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: T.text(context))),
                const SizedBox(height: 10),
                Text(
                    'Something took too long while opening local app data. Try again once.',
                    style: TextStyle(
                        fontSize: 14, height: 1.5, color: T.muted(context))),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: onRetry,
                    child: const Text('Try again'),
                  ),
                ),
                const Spacer(),
              ],
            ),
          ),
        ),
      );
}

// ════════════════════════════════════════════════════════════════
// ROOT — switches between Onboarding and Shell
// ════════════════════════════════════════════════════════════════

class _Root extends StatelessWidget {
  const _Root();

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<bool>(
        valueListenable: Prefs.onboarded,
        builder: (_, done, __) => done ? const Shell() : const OnboardScreen(),
      );
}
