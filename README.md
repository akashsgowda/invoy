<div align="center">

<img src="assets/logo.png" width="56" alt="Invoy logo">

# Invoy

**Local-first invoicing for freelancers and small businesses.**

Create GST-ready invoices, track payments, manage clients, and export shareable PDFs — fully offline, no account required.

[![Download v2.1.4](https://img.shields.io/badge/Download-v2.1.4-000000?style=for-the-badge)](https://github.com/akashsgowda/invoy/releases/latest/download/Invoy-v2.1.4.apk)

</div>

<br/>

## Preview

<p align="center">
  <img src="docs/screenshots/dashboard-light.png" width="160" alt="Dashboard">
  <img src="docs/screenshots/invoices-dark.png" width="160" alt="Invoices list">
  <img src="docs/screenshots/invoice-detail-light.png" width="160" alt="Invoice detail">
  <img src="docs/screenshots/pdf-template-dark.png" width="160" alt="PDF template">
</p>

> Android is the maintained platform target. Generated builds, APKs, signing keys, local app data, and exported PDFs are intentionally kept out of source control.

<br/>

## Features

- Create and manage GST-ready invoices with line items, discounts, due dates, and payment status
- CGST/SGST and IGST support, HSN/SAC codes, item units, reverse charge, and place of supply
- Save reusable invoice items for faster billing
- Six invoice PDF templates
- Track paid, unpaid, overdue, draft, and part-paid invoices
- Dashboard view of collections over time
- Generate invoice and receipt PDFs for sharing or saving outside the app
- Export GST summary CSV files and restore app data using local backups
- Store clients and business profile details locally on the device
- Optional UPI payment QR on unpaid invoices — a payment QR, not an IRP e-invoice QR; Invoy does not generate an IRN

<br/>

## Development

```bash
flutter pub get
flutter analyze
flutter test
flutter build apk --release
```

APKs are published through GitHub Releases, not committed to this repository.

<br/>

## Privacy

Invoy is designed for local-first use. Invoice, client, and business data stay on the user's device unless the user exports, backs up, or shares that data. See [PRIVACY_POLICY.md](PRIVACY_POLICY.md) for details.

## License

MIT. See [LICENSE](LICENSE).
