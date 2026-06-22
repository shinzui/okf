---
type: PostgreSQL Table
title: Orders
description: One row per customer order.
resource: postgresql://warehouse/sales/public/orders
---

# Schema

| Column        | Type        | Nullable | Description                                            |
|---------------|-------------|----------|--------------------------------------------------------|
| `order_id`    | bigint      | no       | Primary key.                                           |
| `customer_id` | bigint      | no       | FK to [customers](/schemas/sales/tables/customers.md). |
| `total_cents` | bigint      | no       | Order total in cents.                                  |
| `placed_at`   | timestamptz | no       | When the order was placed.                             |
