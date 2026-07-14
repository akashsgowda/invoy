<div align="center">

# Invoy

**A local-first Flutter invoicing app for freelancers and small businesses.**

Create GST-ready invoices, track payments, manage clients, and export
shareable PDFs — all offline, with no account required.

[![Download APK](https://img.shields.io/badge/Download%20APK-Invoy%20v2.1.3-black?style=for-the-badge&logo=android)](https://github.com/akashsgowda/invoy/releases/latest/download/Invoy-v2.1.3.apk)

![Platform](https://img.shields.io/badge/platform-Android-3DDC84?style=flat-square&logo=android)
![License](https://img.shields.io/badge/license-MIT-blue?style=flat-square)
![Flutter](https://img.shields.io/badge/built%20with-Flutter-02569B?style=flat-square&logo=flutter)

</div>

---

## Screenshots

<p align="center">
  <img src="docs/screenshots/dashboard-light.png" alt="Invoy dashboard in light theme" width="200">
  <img src="docs/screenshots/invoices-dark.png" alt="Invoy invoices list in dark theme" width="200">
  <img src="docs/screenshots/invoice-detail-light.png" alt="Invoy invoice detail in light theme" width="200">
  <img src="docs/screenshots/pdf-template-dark.png" alt="Invoy invoice PDF template preview" width="200">
</p>

<p align="center">
  <sub>Dashboard · Invoices list · Invoice detail · Exported PDF template</sub>
</p>

> The maintained platform target is Android. Generated builds, APKs, local app
> data, signing keys, and exported PDFs are intentionally kept out of source
> control.

---

## Features

**Invoicing**
- Create and manage GST-ready invoices with line items, discounts, due dates, and payment status
- CGST/SGST and IGST support, HSN/SAC codes, item units, reverse charge, and place of supply
- Save reusable invoice items for faster billing
- Six invoice PDF templates

**Tracking**
- Track paid, unpaid, overdue, draft, and part-paid invoices at a glance
- Dashboard view of collections over time

**Sharing & backups**
- Generate invoice PDFs and receipt PDFs for sharing or saving outside the app
- Export GST summary CSV files and restore app data using local backups

**Clients & profile**
- Store clients and business profile details locally on the device
- Optional UPI payment QR support for unpaid invoices — this is a payment QR,
  not an IRP e-invoice QR; Invoy does not generate an IRN

---

## Development

```bash
flutter pub get
flutter analyze
flutter test
flutter build apk --release
```

APKs are published through GitHub Releases, not committed to this repository.

---

## Privacy

Invoy is designed for local-first use. Invoice, client, and business data stay
on the user's device unless the user exports, backs up, or shares that data.
See [PRIVACY_POLICY.md](PRIVACY_POLICY.md) for details.

## License

MIT. See [LICENSE](LICENSE).
