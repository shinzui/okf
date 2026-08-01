---
type: PostgreSQL Table
title: Customers
description: One row per customer.
generated:
  by: human:nadeem
  at: 2026-06-22T00:00:00Z
resource: postgresql://warehouse/sales/public/customers
---

# Schema

| Column        | Type        | Nullable | Description                          |
|---------------|-------------|----------|--------------------------------------|
| `customer_id` | bigint      | no       | Primary key.                         |
| `email`       | text        | no       | Customer email address.              |
| `created_at`  | timestamptz | no       | When the customer record was created.|
