---
type: PostgreSQL Table
title: Customers
description: One row per customer.
resource: postgresql://warehouse/sales/public/customers
---

# Schema

| Column        | Type        | Nullable | Description                          |
|---------------|-------------|----------|--------------------------------------|
| `customer_id` | bigint      | no       | Primary key.                         |
| `email`       | text        | no       | Customer email address.              |
| `created_at`  | timestamptz | no       | When the customer record was created.|
