# RMSeller Mobile — Enterprise Commodity Supply & Lot Workstation

Production mobile client for verified agricultural commodity sellers, grain aggregators, millers, and farmers in the BrokerBridge network.

## Core Architectural Invariants

1. **Role-Gated Boundary:** Authenticated access strictly restricted to `role == 'seller'` or `role == 'admin'`. Unauthorized roles are redirected to `/access-denied`.
2. **Counterparty Shield:** Zero direct Buyer contact, Buyer directory, or Buyer personal details exposed at any UI, repository, or API layer. All negotiations are strictly Broker-mediated.
3. **Lot-Level Inventory:** All commodities tracked by batch and lot number with available, reserved, and sold quantities.
4. **Loading Readiness:** Structured pre-deal supply attributes indicating physical loading status.
5. **Broker Mandate Mediation:** Sellers assign specific licensed mandi brokers or broadcast mandates across regional desks.

## Running the Application

```bash
# Debug mode with local backend
flutter run --dart-define=API_BASE_URL=http://localhost:3001/api/v1

# Release build
flutter build apk --release
```
