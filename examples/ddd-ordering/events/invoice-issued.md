---
type: Domain Event
key: invoice-issued
message: InvoiceIssued
title: Invoice Issued
aggregate: invoice
description: An invoice was issued for an order.
timestamp: 2026-06-18T00:00:00Z
tags: [ddd, event, billing]
---

# Invoice Issued

Published by [Invoice](/aggregates/invoice.md) once an
[Issue Invoice](/commands/issue-invoice.md) command succeeds. Downstream
consumers (payments, notifications) would subscribe here.
