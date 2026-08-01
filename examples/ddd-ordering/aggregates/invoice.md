---
type: Aggregate
key: invoice
title: Invoice
context: billing
description: Aggregate root for a customer invoice.
commands: [IssueInvoice]
events: [InvoiceIssued]
invariants:
  - An invoice references exactly one placed order.
size: Medium
throughputPerDay: 500
generated:
  by: human:nadeem
  at: 2026-06-18T00:00:00Z
verified:
  by: human:nadeem
  at: 2026-06-21T00:00:00Z
tags: [ddd, aggregate, billing]
---

# Invoice

The Invoice is the aggregate root of the [Billing context](/contexts/billing.md).
It is created by [Issue Invoice](/commands/issue-invoice.md), emits
[Invoice Issued](/events/invoice-issued.md), and reuses the
[Money](/value-objects/money.md) value object shared from Ordering.
