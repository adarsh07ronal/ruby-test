# Subscription Management API (Ruby on Rails)

This project implements a subscription management system for a video
streaming service using Ruby on Rails (API mode).

Users purchase subscriptions via Apple In-App Purchase. The system
manages provisional subscription starts, Apple webhook notifications
(PURCHASE / RENEW / CANCEL), renewals, and cancellations in a robust,
idempotent, and extensible way.

# Demo Video
https://youtu.be/ctwmMBSnBrY

---

## Requirements Summary

- Users purchase subscriptions via Apple In-App Purchase
- Client notifies the backend immediately after payment completion
- Subscription starts in a **provisional (pending)** state
- Apple webhooks are the source of truth for:
  - Purchase confirmation
  - Renewal
  - Cancellation
- Cancellation does **not** immediately revoke access
- Users can access content until the current expiration date

---

## Architecture Overview

This system separates **current subscription state** from **billing / webhook events**.

## Project Structure

The application follows a layered structure to keep responsibilities clear
and make the system easy to extend and maintain.

```text
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


---

## Responsibilities

```md
### Responsibilities

- Controllers  
  - Handle HTTP requests and responses  
  - Perform request orchestration only  
  - No business rules  

- Models  
  - Persist current subscription state  
  - Persist immutable Apple webhook events  
  - Provide access logic (`can_watch?`)  

- Domain Layer (State Machine)  
  - Centralizes subscription lifecycle rules  
  - Applies PURCHASE / RENEW / CANCEL events  
  - Keeps controllers thin and logic testable  


### Core Models

#### Subscription
Represents the user's **current entitlement**.

- Optimized for access checks
- One record per Apple `transaction_id`
- Tracks current period start/end and status

#### SubscriptionEvent
Represents **immutable Apple webhook events**.

- PURCHASE / RENEW / CANCEL
- Append-only
- Enables idempotency, retries, auditing, and analytics

This separation prevents duplicated processing and makes the system
resilient to webhook retries and out-of-order delivery.

---

## Subscription Lifecycle

1. **Provisional Start (Client → Server)**  
   The client calls the provisional API immediately after payment.
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

## Idempotency & Reliability

- Unique database indexes prevent duplicate event processing
- Webhook handling is wrapped in database transactions
- Safe against:
  - Webhook retries
  - Duplicate notifications
  - Concurrent processing

---

## State Machine

Subscription lifecycle rules are centralized in a domain-level
state machine.

- Controllers are thin
- Business rules are explicit and testable
- Easy to extend with new states (grace period, pause, upgrade)

---

## Access Control

Access is determined by both **state** and **time**.

A user can watch content if:
- Subscription status is `active` or `canceled`
- Current time is before `current_period_end`

Cancellation does not immediately revoke access.

---

## API Endpoints

### Provisional Subscription Start

POST /api/subscriptions/provisional

Used by the client immediately after payment completion.

---

### Apple Webhook

POST /api/apple/webhook

Receives PURCHASE / RENEW / CANCEL notifications from Apple.

---

## Extensibility

This design allows easy extension for:

- Additional providers (Google Play, Stripe)
- New subscription states
- Grace periods and retries
- Revenue analytics and reporting

---

## Design Principles

- Event-driven architecture
- Idempotent processing
- Clear separation of concerns
- Production-ready database constraints
- Predictable state transitions

## Manual Test Cases

Test cases


1) 
curl -X POST http://localhost:3000/api/subscriptions/provisional \
  -H "Content-Type: application/json" \
  -d '{
    "user_id": "user_test_1",
    "transaction_id": "tx_test_001",
    "product_id": "com.samansa.subscription.monthly"
  }'

rails console
sub = Subscription.find_by(transaction_id: "tx_test_001")
pp sub


2) 
curl -X POST http://localhost:3000/api/apple/webhook \
  -H "Content-Type: application/json" \
  -d '{
    "type": "PURCHASE",
    "transaction_id": "tx_test_001",
    "product_id": "com.samansa.subscription.monthly",
    "amount": "3.9",
    "currency": "USD",
    "purchase_date": "2026-02-01T00:00:00Z",
    "expires_date": "2026-03-01T00:00:00Z"
  }'

rails console
sub.reload
pp sub

3) 
curl -X POST http://localhost:3000/api/apple/webhook \
  -H "Content-Type: application/json" \
  -d '{
    "type": "PURCHASE",
    "transaction_id": "tx_test_001",
    "product_id": "com.samansa.subscription.monthly",
    "amount": "3.9",
    "currency": "USD",
    "purchase_date": "2026-02-01T00:00:00Z",
    "expires_date": "2026-03-01T00:00:00Z"
  }'

rails console
SubscriptionEvent.where(transaction_id: "tx_test_001").count

4) 
curl -X POST http://localhost:3000/api/apple/webhook \
  -H "Content-Type: application/json" \
  -d '{
    "type": "RENEW",
    "transaction_id": "tx_test_001",
    "product_id": "com.samansa.subscription.monthly",
    "amount": "3.9",
    "currency": "USD",
    "purchase_date": "2026-03-01T00:00:00Z",
    "expires_date": "2026-04-01T00:00:00Z"
  }'

rails console
sub.reload

5) 
curl -X POST http://localhost:3000/api/apple/webhook \
  -H "Content-Type: application/json" \
  -d '{
    "type": "CANCEL",
    "transaction_id": "tx_test_001",
    "product_id": "com.samansa.subscription.monthly",
    "purchase_date": "2026-03-01T00:00:00Z"
  }'

rails console
sub.reload

5) 
rails console
sub.update!(current_period_end: 1.day.ago)
sub.can_watch?

=> false

6) 
curl -X POST http://localhost:3000/api/apple/webhook \
  -H "Content-Type: application/json" \
  -d '{
    "type": "PURCHASE",
    "transaction_id": "tx_test_002",
    "product_id": "com.samansa.subscription.monthly",
    "amount": "3.9",
    "currency": "USD",
    "purchase_date": "2026-02-01T00:00:00Z",
    "expires_date": "2026-03-01T00:00:00Z"
  }'

rails console
Subscription.find_by(transaction_id: "tx_test_002").can_watch?

 





