# Invoy

Invoy is an open-source Flutter invoice app for quick offline billing. It helps
small businesses and freelancers create invoices, track payment status, manage
clients, export backups, and generate shareable invoice PDFs.

The maintained platform target is Android. Generated builds, APKs, local app
data, signing keys, and exported PDFs are intentionally kept out of source
control.

## Features

- Create and manage invoices with line items, GST, discounts, due dates, and payment status.
- Store clients and business profile details locally on the device.
- Generate invoice PDFs for sharing or saving outside the app.
- Export and restore app data using local backup files.
- Optional UPI payment QR support for unpaid invoices.

## Development

Install Flutter, then run:

```bash
flutter pub get
flutter analyze
flutter test
flutter build apk --release
```

APKs should be published through GitHub Releases, not committed to this
repository.

## Privacy

Invoy is designed for local-first use. Invoice, client, and business data stay
on the user's device unless the user exports, backs up, or shares that data.
See [PRIVACY_POLICY.md](PRIVACY_POLICY.md) for details.

## License

MIT. See [LICENSE](LICENSE).
