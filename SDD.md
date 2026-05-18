# Software Design Document (SDD)

## lua-finances — Personal Finances Manager

**Version:** 1.0  
**Date:** 2026-05-17  
**Author:** freitas.a  
**Framework:** LÖVE2D (Lua)  
**Database:** SQLite (lsqlite3)

---

## Table of Contents

- [Software Design Document (SDD)](#software-design-document-sdd)
  - [lua-finances — Personal Finances Manager](#lua-finances--personal-finances-manager)
  - [Table of Contents](#table-of-contents)
  - [Introduction](#introduction)
    - [Purpose](#purpose)
    - [Scope](#scope)
  - [System Overview](#system-overview)
  - [Feature Specifications](#feature-specifications)
    - [F-01 — Accounts](#f-01--accounts)
    - [F-02 — Transactions](#f-02--transactions)
    - [F-03 — Categories](#f-03--categories)
    - [F-04 — Cards](#f-04--cards)
    - [F-05 — Budgets](#f-05--budgets)
    - [F-06 — Installment Plans](#f-06--installment-plans)
    - [F-07 — Statements](#f-07--statements)
    - [F-08 — Tags](#f-08--tags)
    - [F-09 — Wishlist Items](#f-09--wishlist-items)
    - [F-10 — Reports \& Charts](#f-10--reports--charts)
    - [F-11 — Data Export](#f-11--data-export)
  - [Reports Specification](#reports-specification)
  - [Non-Functional Requirements](#non-functional-requirements)
  - [Data Models \& Database Schema](#data-models--database-schema)
    - [Accounts](#accounts)
    - [Cards](#cards)
    - [Categories](#categories)
    - [Installment Plans](#installment-plans)
    - [Transactions](#transactions)
    - [Tags](#tags)
    - [Transaction Tags](#transaction-tags)
    - [Statements](#statements)
    - [Budgets](#budgets)
    - [Wishlist Items](#wishlist-items)
  - [Architecture Overview (TO-DO)](#architecture-overview-to-do)
  - [Project File Structure (TO-DO)](#project-file-structure-to-do)
  - [Module Descriptions (TO-DO)](#module-descriptions-to-do)
  - [UI Design \& Navigation (TO-DO)](#ui-design--navigation-to-do)
  - [Technology Stack](#technology-stack)

---

## Introduction

### Purpose

This document describes the software design for **lua-finances**, a local-only personal finances management desktop application built with Lua and the LÖVE2D framework. It covers architecture decisions, data models, module responsibilities, UI navigation, and feature specifications to guide the full implementation of the project.

### Scope

lua-finances is a **single-user, offline-first desktop application** for personal financial management. It enables tracking of accounts, transactions, cards, budgets, recurring transactions, and installment plans, and provides analytical reports. All data is persisted locally in an SQLite database. No cloud synchronization, authentication system, or multi-user support is in scope.

---

## System Overview

lua-finances is a **tab-based desktop GUI application** that runs entirely on the user's machine. The user interacts through a LÖVE2D window (800×600, fixed size). All financial data is stored in a local SQLite file at `db/db.sqlite3`.

---

## Feature Specifications

### F-01 — Accounts

- User can create an account with: name, type (`checking`, `savings`, `cash`, `investment`, `credit_card`, `digital_wallet`), initial balance, description, and color.
- `balance` is a derived value: it equals `initial_balance` plus the sum of all **paid** transactions against the account. `recalculate_balance` recomputes it from scratch when needed.
- Accounts cannot be deleted if they have associated transactions; they can only be **archived** (`is_active = 0`). Archived accounts are hidden from active views but preserved for historical reporting.
- Transfer transactions (`type = transfer`) link a source account (`account_id`) and a destination account (`destination_account_id`); the UI enforces that both are distinct.

---

### F-02 — Transactions

- Creating a transaction opens a modal form that exposes all schema fields: date, description, amount, type, allocation, payment method, account, card, category, and `is_paid`.
- Selecting `type = transfer` reveals the destination account selector and hides allocation and category (not applicable to transfers).
- `is_paid = 0` (pending): the transaction is recorded but does **not** affect any account balance until marked paid.
- `is_paid = 1` (paid/confirmed): triggers an immediate balance update on the relevant account(s).
- **Payment method** is stored as a text enum directly on the transaction: `cash`, `debit`, `credit`, `pix`, `transfer`, `boleto`.
- **Allocation** follows the 50/30/20 budgeting rule and is required for `expense` transactions:
  - **Needs (50%):** Housing, utilities, food, transport, health
  - **Wants (30%):** Leisure, dining out, entertainment, subscriptions
  - **Savings (20%):** Investments, emergency fund, transfers to savings accounts
- **Parent / child hierarchy:** a transaction with `level = parent` may have child transactions linked via `parent_transaction_id`. Child transactions cannot have their `amount` edited independently; they inherit from the installment plan. Only `date` and `is_paid` are adjustable per child.
- Deleting a parent transaction warns the user and either cascades deletion to all children or orphans them, depending on user confirmation.
- Tags can be attached to any transaction via the `transaction_tags` join table.

---

### F-03 — Categories

- Categories use a two-level hierarchy: root categories have `parent_category_id = NULL`; sub-categories point to a root.
- Each category has a `type` (`income` or `expense`) that restricts which transactions may reference it — an income transaction cannot use an expense category and vice versa.
- Default root categories are seeded automatically on first run (see §5.3 for the full list).
- A category cannot be deleted if any transaction references it. The user must reassign those transactions to a different category first.
- Categories have an optional `color` and `icon` for visual distinction in lists and charts.

---

### F-04 — Cards

- Cards are linked to an account via `account_id` (typically an account of type `credit_card` or `checking`).
- A card has a `type`: `credit` or `debit`.
- Credit card attributes include: `credit_limit`, `closing_day` (day of month the billing cycle closes), and `due_day` (payment due day).
- When a credit transaction is recorded with a `card_id`, it is automatically associated with the open statement for that card's current billing cycle (see F-08 — Statements).
- Paying a card statement is done through the Statements feature, not directly on the card.
- Cards can be archived (`is_active = 0`); archived cards are hidden from active selectors but preserved for historical data.

---

### F-05 — Budgets

- Budgets are defined per category per month/year (`category_id`, `month`, `year`). Only one budget per combination is allowed (enforced by a UNIQUE constraint).
- Budget progress = actual spending in the category for the month ÷ `limit`.
- Visual progress indicator thresholds:
  - **Green:** < 80% spent
  - **Yellow:** 80–99% spent
  - **Red:** ≥ 100% spent (over budget)
- The Dashboard displays alerts for all categories that have crossed the 80% threshold.
- Budgets only consider **paid** expense transactions (`is_paid = 1`) when calculating progress.

---

### F-06 — Installment Plans

- An installment plan is created when the user records a purchase to be paid in N > 1 installments.
- The manager creates one `parent` transaction and N `child` transactions. Each child is dated one frequency period after the previous (default: monthly).
- All child transactions share the same `installment_plan_id` and inherit their `amount` from `installment_amount` in the plan.
- The plan stores: `total_amount`, `number_installments`, `installment_amount`, `start_date`, `end_date`, `frequency`, `card_id` or `account_id`, and `category_id`.
- The installment overview shows: description, total amount, number of paid installments vs total, and the remaining unpaid amount.
- Cancelling a plan (`is_active = 0`) stops future installments from being shown as due but preserves paid ones.

---

### F-07 — Statements

- A statement represents one monthly billing cycle for a credit card.
- A statement record is created automatically the first time a credit transaction is recorded for a given `card_id` + billing cycle (derived from `closing_day` on the card).
- `total_amount` is the sum of all expense transactions linked to the card within the billing cycle's date range.
- Statement statuses: `open` (cycle still running) → `closed` (cycle ended, awaiting payment) → `paid` / `partially_paid`.
- Paying a statement creates a new `expense` transaction on the linked `account_id` and stores its id in `payment_transaction_id`. The status is updated to `paid` or `partially_paid` based on whether `paid_amount >= total_amount`.
- Each card may have at most one statement per `reference_month` / `reference_year` (UNIQUE constraint).

---

### F-08 — Tags

- Tags are free-form text labels that can be attached to any transaction.
- A transaction can have multiple tags; a tag can be attached to multiple transactions (many-to-many via `transaction_tags`).
- Tags are created inline when editing a transaction; existing tags are suggested as the user types.
- Tags are managed (created, renamed, deleted) from the Settings tab.
- A tag cannot be deleted while it is still attached to transactions.

---

### F-09 — Wishlist Items

- A wishlist item is an aspirational record for a desired future purchase or financial goal.
- Fields: name, notes, estimated price, priority (`low`, `medium`, `high`), status, target date, category, and an optional URL.
- Statuses: `pending` → `saved` (actively saving) → `purchased` / `cancelled`.
- Wishlist items **do not affect any account balance** at any stage.
- When a user marks an item as `purchased`, the app offers to pre-fill a new transaction form (or installment plan form) using the item's name, estimated price, and category.
- Items are sorted by priority and target date in the UI.

---

### F-10 — Reports & Charts

See [Reports Specification](#reports-specification) for the full list of report types, chart formats, and data definitions.

---

### F-11 — Data Export

- Accessible from the Settings tab.
- The user selects the entity to export (transactions, accounts, budgets) and optionally a date range.
- Files are saved to the LÖVE2D save directory (`love.filesystem.getSaveDirectory()`).
- Format: UTF-8 CSV, comma-separated, with a header row.
- Monetary values are exported as decimal strings (e.g., `12.50`) converted from centavos for human readability.

---

## Reports Specification

All reports are accessible from the **Reports** tab. A report type selector and date/range controls appear at the top.

| Report | Chart Type | Description |
|---|---|---|
| **Monthly Summary** | Bar (grouped) | Total income vs total expense for a selected month, with category breakdown |
| **Annual Summary** | Bar (grouped) | 12-month view of income, expense, and net balance for a selected year |
| **Cash Flow** | Line / Area | Day-by-day or week-by-week cumulative balance evolution over a date range |
| **Net Worth History** | Line | Monthly net worth (sum of all account balances) for the last N months |
| **Spending by Category** | Pie / Donut | Distribution of expenses by category for a given month |
| **Income Sources** | Pie / Donut | Distribution of income by category for a given month |
| **Budget vs Actual** | Bar (horizontal) | Each category's budget limit vs actual spending; shows over/under |
| **Allocation Breakdown** | Pie / Donut | Split of spending into Needs / Wants / Savings |
| **Savings Rate** | Line + Number | Monthly savings rate (%) over the last N months |
| **Top Expenses** | Bar (horizontal) | Top 10 individual expense transactions for a given month |
| **Card Invoice** | Table | Itemized list of charges on a specific card for a billing cycle |
| **Installment Overview** | Table + Progress | All active installment plans with paid/pending status |

---

## Non-Functional Requirements

| Requirement | Detail |
|---|---|
| **Platform** | Windows desktop (LÖVE2D 11.x) |
| **Language** | Lua 5.1 (LÖVE2D built-in) |
| **Storage** | Local SQLite file; expected size < 50 MB |
| **Performance** | UI renders at ≥ 60 FPS; all queries complete in < 100 ms |
| **Currency** | BRL (Brazilian Real); amounts stored as integer centavos |
| **Locale** | Portuguese Brazilian for labels and date formatting |
| **Privacy** | No network access; no telemetry; data stays on-device |
| **Backup** | User is responsible for backing up `db/db.sqlite3` |

---

## Data Models & Database Schema

All monetary values are stored as **integers in centavos** (e.g., R$ 12,50 → `1250`) to avoid floating-point precision issues.

Dates are stored as **ISO 8601 strings** (`YYYY-MM-DD`).

---

### Accounts

Represents a financial account owned by the user.

Table name: `accounts`

| Column | Type | Constraints | Description |
|---|---|---|---|
| `id` | INTEGER | PK AUTOINCREMENT | Unique identifier |
| `name` | TEXT | NOT NULL | Display name |
| `description` | TEXT | | Optional notes |
| `type` | TEXT | NOT NULL | Options: `checking`, `savings`, `cash`, `investiment` |
| `balance` | INTEGER | NOT NULL DEFAULT 0 | Current balance in centavos |
| `initial_balance` | INTEGER | NOT NULL DEFAULT 0 | Opening balance |
| `color` | TEXT | | Hex color for UI display |
| `is_active` | INTEGER | NOT NULL DEFAULT 1 | 1 = active, 0 = archived |
| `creation_date` | TEXT | NOT NULL | ISO 8601 timestamp |

---

### Cards

Represents a payment card (credit or debit) linked to an account.

Table name: `cards`

| Column | Type | Constraints | Description |
|---|---|---|---|
| `id` | INTEGER | PK, AUTOINCREMENT | Unique identifier |
| `name` | TEXT | NOT NULL | Card label |
| `last_four_digits` | TEXT | | Last 4 digits |
| `type` | TEXT | NOT NULL | Options: `credit` or `debit` |
| `credit_limit` | INTEGER | | Credit limit (credit cards only) |
| `closing_day` | INTEGER | | Invoice closing day of month |
| `due_day` | INTEGER | | Payment due day of month |
| `is_active` | INTEGER | NOT NULL DEFAULT 1 | 1 = active, 0 = archived |
| `account_id` | INTEGER | NOT NULL FK → accounts.id | Owning account |

---

### Categories

Hierarchical transaction categories. Top-level categories have `parent_id = NULL`.

Table name: `categories`

| Column | Type | Constraints | Description |
|---|---|---|---|
| `id` | INTEGER | PK, AUTOINCREMENT | Unique identifier |
| `name` | TEXT | NOT NULL | Category name |
| `description` | TEXT | | Optional category description
| `type` | TEXT | NOT NULL | Options: `income`, `expense` |
| `color` | TEXT | | Hex color for UI |
| `icon` | TEXT | | Icon name/path |
| `parent_category_id` | INTEGER | FK → categories.id | Parent category (NULL = root) |

---

### Installment Plans

Tracks a multi-installment purchase. Each installment is a child `transaction`.

Table name: `installment_plans`

| Column | Type | Constraints | Description |
|---|---|---|---|
| `id` | INTEGER | PK, AUTOINCREMENT | Unique identifier |
| `description` | TEXT | | Purchase description |
| `total_amount` | INTEGER | NOT NULL | Total purchase amount
| `number_installments` | INTEGER | NOT NULL | Number of installments |
| `installment_amount` | INTEGER | NOT NULL | Amount per installment |
| `start_date` | TEXT | NOT NULL | Date of first installment |
| `end_date` | TEXT | | Date of final installment, recurring if NULL |
| `frequency` | TEXT | NOT NULL | Options: `daily`, `weekly`, `biweekly`, `semi-monthly`, `monthly`, `quarterly`, `yearly` |
| `is_active` | TEXT | NOT NULL DEFAULT 1 | If is active or not |
| `created_date` | TEXT | NOT NULL | ISO 8601 timestamp |
| `card_id` | INTEGER | FK → cards.id | Card used (if credit) |
| `account_id` | INTEGER | FK → accounts.id | Account if not on a card |
| `category_id` | INTEGER | FK → categories.id | Category |

---

### Transactions

Core financial events. Supports parent/child hierarchy for installments and splits.

Table name: `transactions`

| Column | Type | Constraints | Description |
|---|---|---|---|
| `id` | INTEGER | PK, AUTOINCREMENT | Unique identifier |
| `date` | TEXT | NOT NULL | ISO 8601 date (`YYYY-MM-DD`) |
| `description` | TEXT | | Transaction description |
| `amount` | INTEGER | NOT NULL | Amount in centavos (always positive) |
| `type` | TEXT | NOT NULL | Options: `income`, `expense`, or `transfer` |
| `allocation` | TEXT | | Options: `needs`, `wants`, or `savings` |
| `payment_method` | INTEGER | NOT NULL | Options: `cash`, `debit`, `credit`, `pix`, `transfer`, `boleto` |
| `is_paid` | INTEGER | NOT NULL, DEFAULT 0 | 1 = paid/confirmed, 0 = pending |
| `parent_transaction_id` | INTEGER | FK → transactions.id | Parent if NULL |
| `account_id` | INTEGER | NOT NULL, FK → accounts.id | Source/destination account |
| `card_id` | INTEGER | FK → cards.id | Card used (if applicable) |
| `installment_plan_id` | INTEGER | FK → installment_plans.id | If part of an installment plan |
| `category_id` | INTEGER | FK → categories.id | Category |
| `destination_account_id` | INTEGER | FK → accounts.id | Target account for transfers |
| `created_at` | TEXT | NOT NULL | ISO 8601 timestamp |
| `updated_at` | TEXT | NOT NULL | ISO 8601 timestamp |

---

### Tags

Free-form labels for transactions.

Table name: `tags`

| Column | Type | Constraints | Description |
|---|---|---|---|
| `id` | INTEGER | PK, AUTOINCREMENT | Unique identifier |
| `name` | TEXT | NOT NULL, UNIQUE | Tag label |

---

### Transaction Tags

Many-to-many relationship between transactions and tags.

Table name: `transaction_tags`

| Column | Type | Constraints | Description |
|---|---|---|---|
| `id` | INTEGER | PK, AUTOINCREMENT | Unique identifier |
| `transaction_id` | INTEGER | NOT NULL, FK → transactions.id | |
| `tag_id` | INTEGER | NOT NULL, FK → tags.id | |

---

### Statements

Represents a monthly credit card statement (invoice). A statement is generated per card per billing cycle and groups all charges incurred during that period into a single payable entity.

Table name: `statements`

| Column | Type | Constraints | Description |
|---|---|---|---|
| `id` | INTEGER | PK, AUTOINCREMENT | Unique identifier |
| `reference_month` | INTEGER | NOT NULL | Billing month (1–12) |
| `reference_year` | INTEGER | NOT NULL | Billing year (e.g., 2026) |
| `closing_date` | TEXT | NOT NULL | ISO 8601 date — when the billing cycle closed |
| `due_date` | TEXT | NOT NULL | ISO 8601 date — payment due date |
| `total_amount` | INTEGER | NOT NULL DEFAULT 0 | Total charges in centavos |
| `paid_amount` | INTEGER | NOT NULL DEFAULT 0 | Amount already paid in centavos |
| `status` | TEXT | NOT NULL DEFAULT `open` | Options: `open`, `closed`, `paid`, `partially_paid` |
| `payment_transaction_id` | INTEGER | FK → transactions.id | The expense transaction created when paying the statement |
| `card_id` | INTEGER | NOT NULL, FK → cards.id | Card this statement belongs to |
| `account_id` | INTEGER | NOT NULL, FK → accounts.id | Account used to pay the statement |
| `created_date` | TEXT | NOT NULL | ISO 8601 timestamp |
| `updated_date` | TEXT | NOT NULL | ISO 8601 timestamp |

---

### Budgets

Monthly spending limits per category.

Table name: `budgets`

| Column | Type | Constraints | Description |
|---|---|---|---|
| `id` | INTEGER | PK, AUTOINCREMENT | Unique identifier |
| `month` | INTEGER | NOT NULL | Month (1–12) |
| `year` | INTEGER | NOT NULL | Year (e.g., 2026) |
| `limit` | INTEGER | NOT NULL | Spending limit |
| `category_id` | INTEGER | NOT NULL, FK → categories.id | Target category |

---

### Wishlist Items

Represents desired future purchases or financial goals that the user wants to plan for. Wishlist items are not transactions; they are aspirational records that can later be converted into transactions or installment plans once the purchase is made.

Table name: `wishlist_items`

| Column | Type | Constraints | Description |
|---|---|---|---|
| `id` | INTEGER | PK, AUTOINCREMENT | Unique identifier |
| `name` | TEXT | NOT NULL | Item name or description |
| `notes` | TEXT | | Additional details or motivation |
| `estimated_price` | INTEGER | | Estimated cost in centavos |
| `priority` | TEXT | NOT NULL DEFAULT `medium` | Options: `low`, `medium`, `high` |
| `status` | TEXT | NOT NULL DEFAULT `pending` | Options: `pending`, `saved`, `purchased`, `cancelled` |
| `target_date` | TEXT | | ISO 8601 date — desired purchase date |
| `url` | TEXT | | Optional product or reference URL |
| `created_date` | TEXT | NOT NULL | ISO 8601 timestamp |
| `updated_date` | TEXT | NOT NULL | ISO 8601 timestamp |
| `category_id` | INTEGER | FK → categories.id | Associated expense category |

---

## Architecture Overview (TO-DO)

---

## Project File Structure (TO-DO)

```
lua-finances/
├── conf.lua                            -- LÖVE2D window configuration
├── main.lua                            -- Entry point: love.load, love.update, love.draw
├── SDD.md                              -- This document
│
├── assets/
│   ├── fonts/                          -- TTF font files
│   └── icons/                          -- UI icons (PNG)
│
├── db/
│   └── db.sqlite3                      -- SQLite database file
│
├── lib/
│   ├── classic.lua                     -- OOP base class
│   └── tick.lua                        -- Timer utilities
│
└── modules/
    ├── database.lua                    -- Data access layer (SQL execution)
    ├── accounts_manager.lua            -- Account business logic
    ├── transactions_manager.lua        -- Transaction business logic
    ├── categories_manager.lua          -- Category business logic
    ├── cards_manager.lua               -- Card business logic
    ├── payment_methods_manager.lua     -- Payment method business logic
    ├── budgets_manager.lua             -- Budget business logic
    ├── installment_plans_manager.lua   -- Installment plan business logic
    ├── recurring_manager.lua           -- Recurring transaction business logic
    ├── reports_manager.lua             -- Report data aggregation
    └── export_manager.lua              -- CSV export logic
    │
    └── ui/
        ├── ui_manager.lua              -- Theme, screen management
        │
        ├── screens/
        │   ├── dashboard_screen.lua    -- Overview / summary tab
        │   ├── accounts_screen.lua     -- Accounts management tab
        │   ├── transactions_screen.lua -- Transactions list/form tab
        │   ├── cards_screen.lua        -- Cards management tab
        │   ├── budgets_screen.lua      -- Budgets management tab
        │   ├── reports_screen.lua      -- Reports & charts tab
        │   └── settings_screen.lua     -- Settings tab
        │
        ├── components/
        │   ├── shape.lua               -- Base drawable class (existing)
        │   ├── rectangle.lua           -- Rectangle component (existing)
        │   ├── circle.lua              -- Circle component (existing)
        │   ├── tab_bar.lua             -- Horizontal tab navigation bar
        │   ├── button.lua              -- Clickable button
        │   ├── input.lua               -- Text input field
        │   ├── select.lua              -- Dropdown selector
        │   ├── date_picker.lua         -- Date selection widget
        │   ├── modal.lua               -- Modal dialog overlay
        │   ├── data_table.lua          -- Scrollable data table
        │   ├── badge.lua               -- Status/category badge
        │   ├── chart_bar.lua           -- Bar chart component
        │   ├── chart_line.lua          -- Line chart component
        │   └── chart_pie.lua           -- Pie/donut chart component
        │
        └── themes/
            └── kanagawa.lua            -- Kanagawa color palette (existing)
```

---

## Module Descriptions (TO-DO)

---

## UI Design & Navigation (TO-DO)

---

## Technology Stack

| Component | Technology | Version |
|---|---|---|
| Runtime | LÖVE2D | 11.x |
| Language | Lua | 5.1 |
| Database | SQLite | 3.x |
| SQLite binding | lsqlite3 | — |
| OOP library | classic.lua | — |
| Timer utility | tick.lua | — |