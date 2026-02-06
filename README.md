# README

This README would normally document whatever steps are necessary to get the
application up and running.

Things you may want to cover:

* Ruby version

* System dependencies

* Configuration

* Database creation

* Database initialization

* How to run the test suite

* Services (job queues, cache servers, search engines, etc.)

* Deployment instructions

* ...

# Subscription Management API (Ruby on Rails)

This project implements a subscription management system for a video
streaming service using Ruby on Rails (API mode).

Users purchase subscriptions via Apple In-App Purchase. The system
manages provisional subscription starts, Apple webhook notifications
(PURCHASE / RENEW / CANCEL), renewals, and cancellations in a robust,
idempotent, and extensible way.

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
