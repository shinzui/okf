---
type: Command
key: issue-invoice
message: IssueInvoice
title: Issue Invoice
aggregate: invoice
description: Request to issue an invoice for a placed order.
timestamp: 2026-06-18T00:00:00Z
tags: [ddd, command, billing]
---

# Issue Invoice

`IssueInvoice` drives the [Invoice](/aggregates/invoice.md) aggregate. It is
dispatched by the [Issue Invoice On Order policy](/policies/issue-invoice-on-order.md)
and emits [Invoice Issued](/events/invoice-issued.md).
