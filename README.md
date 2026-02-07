# Subscription Management API (Ruby on Rails)

This project implements a **subscription management system** for a video
streaming service using **Ruby on Rails (API mode)**.

Users purchase subscriptions via **Apple In-App Purchase**.  
The backend manages provisional subscription starts, Apple webhook notifications
(PURCHASE / RENEW / CANCEL), renewals, and cancellations in a **robust,
idempotent, and extensible** manner.

---

## Demo Video

https://youtu.be/ctwmMBSnBrY

---

## Requirements Summary

- Users purchase subscriptions via Apple In-App Purchase
- Client notifies the backend immediately after payment completion
- Subscription starts in a **provisional (pending)** state
- Apple webhooks are the **source of truth** for:
  - Purchase confirmation
  - Renewal
  - Cancellation
- Cancellation does **not** immediately revoke access
- Users can access content until the current expiration date

---

## Architecture Overview

This system separates **current subscription state** from **billing / webhook
events** to ensure reliability and auditability.

### Core Models

#### Subscription
Represents the user's **current entitlement**.

- One record per Apple `transaction_id`
- Optimized for access checks
- Tracks current period start/end and status

#### SubscriptionEvent
Represents **immutable Apple webhook events**.

- PURCHASE / RENEW / CANCEL
- Append-only
- Enables idempotency, retries, auditing, and analytics

This separation prevents duplicated processing and makes the system resilient
to webhook retries and out-of-order delivery.

---

## Subscription Lifecycle

1. **Provisional Start (Client → Server)**  
   The client calls the provisional API immediately after payment completion.  
   A subscription is created or updated with status `pending`.

2. **Purchase Confirmation (Apple Webhook)**  
   Apple sends a PURCHASE webhook.
   - Event is persisted idempotently
   - Subscription becomes `active`
   - Current period start/end are set

3. **Renewal (Apple Webhook)**  
   Apple sends a RENEW webhook.
   - Event is persisted
   - Subscription period is extended

4. **Cancellation (Apple Webhook)**  
   Apple sends a CANCEL webhook.
   - Subscription status becomes `canceled`
   - Access remains valid until `current_period_end`

5. **Expiration**  
   Access is determined by time, not events.  
   Once the current period ends, access is denied.

---

## Subscription States

| State     | Meaning |
|----------|--------|
| pending  | Client payment completed, awaiting Apple confirmation |
| active   | Subscription is valid |
| canceled | Auto-renew stopped, still valid until expiration |
| expired  | Subscription period has ended |

---

## Access Control

Access is determined by **state + time**.

A user can watch content if:
- Subscription status is `active` or `canceled`
- Current time is before `current_period_end`

Cancellation does not immediately revoke access.

---

## Design Overview & Key Design Features

This system is designed with real-world subscription constraints in mind,
including webhook retries, partial failures, and future extensibility.

The implementation focuses on **extensibility, analyzability, idempotence,
and scalability**.

---

### Extensibility

- Subscription lifecycle rules are centralized in a domain-level state machine
  (`Subscriptions::StateMachine`)
- Controllers are thin and orchestration-only
- New states (grace period, paused, trial) can be added without changing
  existing controllers
- Additional providers (Google Play, Stripe) can reuse the same
  event + state machine pattern

---

### Analyzability

- Current subscription state is separated from immutable billing events
- `SubscriptionEvent` stores all webhook notifications as append-only data
- Enables future analysis such as:
  - Revenue reporting
  - Churn analysis
  - Debugging unexpected transitions
- Historical data is preserved even if subscription state changes

---

### Idempotence

- Apple webhooks may be retried or delivered multiple times
- Database-level unique constraints prevent duplicate event processing
- Webhook handling is wrapped in database transactions
- Duplicate notifications are safely ignored without side effects

---

### Scalability

- Controllers are stateless and horizontally scalable
- Idempotent webhook processing allows safe parallel execution
- Database constraints provide consistency instead of in-memory locks
- Separation of read-optimized subscription state and write-heavy event logs
  supports future optimization and sharding strategies

---

### Why This Design

This architecture reflects patterns commonly used in production subscription
systems where external providers are the source of truth and webhook delivery
is not guaranteed to be exactly-once.

By separating **client intent**, **provider confirmation**, and
**user entitlement**, the system remains robust, auditable, and easy to evolve.

---

## API Endpoints

### Provisional Subscription Start

```
POST /api/subscriptions/provisional
```

Used by the client immediately after payment completion.

---

### Apple Webhook

```
POST /api/apple/webhook
```

Receives PURCHASE / RENEW / CANCEL notifications from Apple.

---

## Project Structure

```
app/
├── controllers/
│   ├── api/
│   │   ├── subscriptions_controller.rb
│   │   └── apple/
│   │       └── webhooks_controller.rb
│   └── application_controller.rb
│
├── models/
│   ├── subscription.rb
│   └── subscription_event.rb
│
├── domains/
│   └── subscriptions/
│       └── state_machine.rb
│
db/
├── migrate/
│   ├── create_subscriptions.rb
│   └── create_subscription_events.rb
│
config/
│   └── routes.rb
│
README.md
```

---

## Manual Test Cases

### 1. Provisional Subscription Start

```bash
curl -X POST http://localhost:3000/api/subscriptions/provisional   -H "Content-Type: application/json"   -d '{
    "user_id": "user_test_1",
    "transaction_id": "tx_test_001",
    "product_id": "com.samansa.subscription.monthly"
  }'
```

Rails console:
```ruby
sub = Subscription.find_by(transaction_id: "tx_test_001")
pp sub
```

---

### 2. Purchase Confirmation (Apple Webhook)

```bash
curl -X POST http://localhost:3000/api/apple/webhook   -H "Content-Type: application/json"   -d '{
    "type": "PURCHASE",
    "transaction_id": "tx_test_001",
    "product_id": "com.samansa.subscription.monthly",
    "amount": "3.9",
    "currency": "USD",
    "purchase_date": "2026-02-01T00:00:00Z",
    "expires_date": "2026-03-01T00:00:00Z"
  }'
```

---

### 3. Idempotency Check

Send the same PURCHASE webhook again and verify:

```ruby
SubscriptionEvent.where(transaction_id: "tx_test_001").count
```

---

### 4. Renewal

```bash
curl -X POST http://localhost:3000/api/apple/webhook   -H "Content-Type: application/json"   -d '{
    "type": "RENEW",
    "transaction_id": "tx_test_001",
    "product_id": "com.samansa.subscription.monthly",
    "amount": "3.9",
    "currency": "USD",
    "purchase_date": "2026-03-01T00:00:00Z",
    "expires_date": "2026-04-01T00:00:00Z"
  }'
```

---

### 5. Cancellation (Access Still Valid)

```bash
curl -X POST http://localhost:3000/api/apple/webhook   -H "Content-Type: application/json"   -d '{
    "type": "CANCEL",
    "transaction_id": "tx_test_001",
    "product_id": "com.samansa.subscription.monthly",
    "purchase_date": "2026-03-01T00:00:00Z"
  }'
```

---

### 6. Expiration Check

```ruby
sub.update!(current_period_end: 1.day.ago)
sub.can_watch?
# => false
```

---

## Final Notes

- Apple signature verification is intentionally omitted as per the assignment
- The system is designed to reflect production-ready backend patterns
