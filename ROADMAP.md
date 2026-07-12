# Invoy Roadmap

## Implemented: GST invoice compliance base

This is the launch-critical track before more visual polish. The goal is to make GST invoices easy to read for customers, accountants, and auditors without turning the app into a heavy accounting suite.

- Added HSN/SAC and unit fields to invoice items.
- Added supplier business address and state details to onboarding/profile.
- Added buyer GST details, billing address, and place of supply visibility on GST invoices.
- Added a clear tax mode: CGST + SGST for same-state invoices, IGST for interstate invoices.
- Added reverse charge yes/no where needed.
- Added a GST Invoice PDF template with item table, taxable value, GST rate, CGST/SGST/IGST amount, total, invoice number/date, and signature area.
- Added a simple GST summary export/report for filing reference.
- Have the final GST PDF checked once by a CA/accountant before calling it compliant.

## Polish backlog

- Tighten PDF template typography, spacing, and large amount handling.
- Added edit and delete actions for clients with confirmation.
- Replace dashboard comparison text like percentage spikes with clearer amount-based copy.
- Reduce grey-heavy cards in dark theme while keeping the monochrome style.
- Clean up More Options so only advanced invoice settings live there.
- Keep the app simple: avoid e-invoicing, inventory, recurring invoices, and other heavy features unless users clearly ask for them.

## Lightweight feature gaps after GST

These are the useful gaps compared with bigger invoice tools, but they should stay small and offline-first.

- Added saved items or services so users can reuse common item names, HSN/SAC, unit, rate, and GST rate.
- Estimates or quotes that can be converted into invoices.
- Existing client statements show unpaid invoices, paid invoices, and payment history for one client.
- Added payment receipts for paid or partly paid invoices.
- Improved backup and restore flow with saved items/profile GST data included.
- Added basic invoice CSV and GST summary CSV reports.
- Duplicate invoice number warning and stronger required-field validation.
- Optional app lock for users who keep client/payment data on the phone.

## Keep out for now

- Full inventory management.
- Recurring invoices.
- Online payment gateway integration.
- Customer portal.
- Multi-user roles.
- E-invoice or e-way bill generation.
- Expense, project, or timesheet modules.
