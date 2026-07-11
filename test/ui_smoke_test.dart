import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:invoy/models.dart';
import 'package:invoy/screens/client_detail.dart';
import 'package:invoy/screens/clients.dart';
import 'package:invoy/screens/create.dart';
import 'package:invoy/screens/dashboard.dart';
import 'package:invoy/screens/detail.dart';
import 'package:invoy/screens/invoices.dart';
import 'package:invoy/screens/onboarding.dart';
import 'package:invoy/screens/profile.dart';
import 'package:invoy/screens/settings.dart';
import 'package:invoy/screens/templates.dart';
import 'package:invoy/theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('narrow invoice screen has no layout overflow', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(false),
        home: InvoicesPage(onRefresh: () {}),
      ),
    );
    await tester.pump(const Duration(milliseconds: 700));
  });

  testWidgets('narrow detail screen has no layout overflow', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final invoice = Invoice(
      id: 'narrow-detail',
      num: 'INV-2026-001',
      client: Customer(name: 'Example Client Private Limited'),
      items: [
        LineItem(
          id: 'line-1',
          desc: 'Professional consulting service',
          qty: 2,
          rate: 12500,
          gstRate: 18,
        ),
      ],
      status: Status.pending,
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(false),
        home: DetailPage(invoice: invoice, onRefresh: () {}),
      ),
    );
    await tester.pump(const Duration(milliseconds: 700));
  });

  testWidgets('narrow client detail has no layout overflow', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(false),
        home: ClientDetailPage(
          name: 'Example Client Private Limited',
          email: 'accounts@example.com',
          phone: '',
          address: '',
          state: 'Karnataka',
          onRefresh: () {},
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 700));
  });

  testWidgets('onboarding steps remain usable on a compact phone',
      (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(theme: buildTheme(false), home: const OnboardScreen()),
    );
    await tester.pump(const Duration(milliseconds: 700));

    await tester.tap(find.text('Get started'));
    await tester.pumpAndSettle();
    expect(find.text('Your details'), findsOneWidget);
    final halfwayWidth = tester
        .getSize(find.byKey(const ValueKey('onboarding-progress-fill')))
        .width;
    expect(halfwayWidth, greaterThan(0));

    await tester.enterText(find.byType(TextField).first, 'Example Owner');
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('Tax and payment'), findsOneWidget);
    final fullWidth = tester
        .getSize(find.byKey(const ValueKey('onboarding-progress-fill')))
        .width;
    expect(fullWidth, closeTo(halfwayWidth * 2, 0.5));

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('Setup complete.'), findsOneWidget);
    expect(find.text('Start invoicing'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('core screens render across Android phone layouts',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final invoice = Invoice(
      id: 'ui-smoke',
      num: 'INV-2026-001',
      client: Customer(
        name: 'Example Client Private Limited',
        email: 'accounts@example.com',
        state: 'Karnataka',
      ),
      items: [
        LineItem(
          id: 'line-1',
          desc: 'Professional consulting service',
          hsnSac: '998391',
          unit: 'Service',
          qty: 2,
          rate: 12500,
          gstRate: 18,
        ),
      ],
      status: Status.pending,
      placeOfSupply: 'Karnataka',
    );

    final screens = <Widget>[
      const DashboardPage(),
      InvoicesPage(onRefresh: () {}),
      ClientsPage(onAddClient: () {}),
      const SettingsPage(),
      const ProfilePage(),
      const TemplatesPage(),
      const OnboardScreen(),
      CreatePage(
        invoice: invoice,
        editing: true,
        onSaved: (_) {},
      ),
      DetailPage(invoice: invoice, onRefresh: () {}),
      ClientDetailPage(
        name: invoice.client.name,
        email: invoice.client.email,
        phone: '',
        address: '',
        state: invoice.client.state,
        onRefresh: () {},
      ),
    ];

    final layouts = <({Size size, double textScale})>[
      (size: const Size(360, 800), textScale: 1),
      (size: const Size(320, 640), textScale: 1),
      (size: const Size(360, 800), textScale: 1.3),
    ];

    for (final layout in layouts) {
      tester.view.physicalSize = layout.size;
      for (final dark in [false, true]) {
        for (final screen in screens) {
          await tester.pumpWidget(
            MaterialApp(
              key: UniqueKey(),
              theme: buildTheme(false),
              darkTheme: buildTheme(true),
              themeMode: dark ? ThemeMode.dark : ThemeMode.light,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: TextScaler.linear(layout.textScale),
                ),
                child: child!,
              ),
              home: screen,
            ),
          );
          await tester.pump(const Duration(milliseconds: 700));
          final exception = tester.takeException();
          if (exception != null) {
            debugDumpApp();
            fail(
              '${screen.runtimeType} failed in ${dark ? 'dark' : 'light'} mode '
              'at ${layout.size.width.toInt()}x${layout.size.height.toInt()} '
              'with ${layout.textScale}x text: $exception',
            );
          }
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump();
        }
      }
    }
  });
}
