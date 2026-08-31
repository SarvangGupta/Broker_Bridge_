Technical Requirements Document \(TRD\)

Product: BrokerBridge Enterprise

Architecture Stack: Next\.js, TypeScript, Supabase \(PostgreSQL, Auth, Storage, Realtime\), Drizzle ORM, Tailwind CSS, TanStack Query, Zustand, Zod\.

1\. System Architecture

The BrokerBridge platform is designed as a cloud\-hosted, mobile\-first B2B SaaS application optimized for Tier\-2 and Tier\-3 Indian markets\. 

- Overall Architecture: A monolithic frontend/backend architecture using Next\.js App Router, deeply integrated with Supabase as the Database\-as\-a\-Service \(DBaaS\) provider\.
- High\-Level Component Diagram:
	- Client Layer: Next\.js React Server Components \(RSC\) and Client Components\. Optimized for 360px mobile width\. Uses Zustand for global state and TanStack Query for server state caching\. Service workers manage offline form queuing\. 
	- API & Logic Layer: Next\.js Server Actions for direct form mutations and Route Handlers for external integrations \(e\.g\., WhatsApp Webhooks\)\.
	- Data Access Layer: Drizzle ORM acting as the bridge between Server Actions and the database\.
	- Data & Storage Layer: Supabase PostgreSQL database, Supabase Auth for identity, and Supabase Storage for files\.
- Request Flow: Client Interaction  Zod Validation  Server Action Execution  Middleware \(Auth/Role Check\)  Drizzle ORM Query  Supabase  UI Update via TanStack Query invalidation\.
- Authentication Flow: Supabase Auth manages mobile OTP signups\. Next\.js Middleware intercepts requests to validate the JWT session cookie\. 
- Authorization Flow: Enforced at two layers\. Application logic \(Next\.js Middleware\) routes users based on their Tier 0, 1, or 2 role\. Database logic \(Supabase Row Level Security\) ensures isolated data silos for buyers and sellers\. 
- Realtime Architecture: Supabase Realtime channel subscriptions listen to database row updates \(e\.g\., deal status changes\) and broadcast payloads to connected TanStack Query clients to trigger immediate UI refreshes\.

2\. Folder Structure

The production Next\.js repository will follow a feature\-driven App Router structure:

- /src
	- /app \(Next\.js routing, pages, and layouts grouped by role: /\(admin\), /\(broker\), /\(client\)\)
	- /components \(Reusable UI components using shadcn/ui and custom cards\)
	- /lib \(Utility functions, Supabase clients, constants\)
	- /server
		- /actions \(Next\.js Server Actions grouped by entity e\.g\., deal\-actions\.ts\)
		- /db \(Drizzle ORM schema definitions, relations, and migrations\)
		- /api \(Next\.js Route Handlers for external webhooks\)
	- /types \(TypeScript interfaces and shared Zod schemas\)
	- /store \(Zustand state slices for local UI state\)
	- /hooks \(Custom React hooks and TanStack Query wrappers\)
	- /public \(Static assets, offline fallback pages, manifest for PWA\)

3\. Database Design

The database uses PostgreSQL with a strictly normalized schema and soft deletes\. 

- Users & Auth:
	- Tables: users, companies, profiles\_buyer, profiles\_seller, profiles\_broker\.
	- Keys & Relations: company\_id is a Foreign Key \(FK\) in users\. User profiles extend users via 1\-to\-1 relations\. **[x] (Structurally finalized and generated)**
- Master Data:
	- Tables: master\_commodities, master\_grades, master\_locations \(States, Districts, Cities\), master\_logistics \(Packaging, Vehicles, Transport Types\)\.
	- Indexes: B\-tree indexes on is\_active flags to optimize dropdown population\.
- Core Transactions:
	- Tables: requirements, availabilities, quotations, deals, dispatches, invoices, payments, disputes\.
	- Keys & Relations: deals acts as the central junction, holding FKs to requirements, quotations, buyer\_id, seller\_id, and broker\_id\. 
	- Indexes: Status columns, Date columns \(for aging reports\), and Foreign Keys heavily indexed for CRM and dashboard query performance\.
- System:
	- Tables: audit\_logs, notifications, crm\_activities, crm\_tasks\.
	- Keys: audit\_logs uses polymorphic relations \(entity\_type, entity\_id\) to track changes across all tables\. 

4\. Authentication Architecture

- Login & Signup: Mobile number with OTP verification acting as the primary authentication vector, handled natively by Supabase Auth\. 
- JWT & Session Handling: Upon successful OTP verification, Supabase issues a JWT containing the user's UUID and custom claims containing their Role ID\. This JWT is stored in an HttpOnly, secure cookie\.
- Protected Routes: Next\.js Middleware reads the session cookie on every request\. If invalid or missing, it redirects to the login screen\.
- Refresh Tokens: Supabase client SDK automatically manages token refreshes in the background before the short\-lived JWT expires\.
- Logout: Server action destroys the session cookie and invalidates the token in Supabase\.

5\. Authorization \(RBAC\)

- Roles: Mapped exactly to the PRD hierarchy: Tier 0 \(Admin\), Tier 1 \(Broker\), Tier 2 \(Buyer/Seller\)\. 
- Role Validation & Middleware: Next\.js Middleware parses the JWT role claim\. Attempting to access /\(admin\) without Tier 0 credentials results in a 403 Forbidden redirect\.
- Database Row Level Security \(RLS\):
	- *Buyers/Sellers:* RLS policies ensure they can only SELECT, INSERT, or UPDATE rows where company\_id matches their auth token\. 
	- *Brokers:* RLS grants read/update access conditionally where broker\_id on the deal/requirement matches their auth token\. 
	- *Admins:* RLS bypassed via Supabase Service Role key for God Mode operations\. 

6\. API Architecture

While Server Actions handle the frontend UI, standard REST APIs \(Route Handlers\) are built for webhooks, offline\-queue syncing, and potential Phase 3 mobile app integrations\.

- Method / Endpoint: POST /api/v1/requirements/sync
	- Purpose: Sync offline\-created requirements when the device reconnects\. 
	- Request: Array of requirement payload objects\.
	- Response: 200 OK with synced IDs\.
	- Error Codes: 400 Bad Request \(Zod failure\), 401 Unauthorized \(Invalid JWT\)\.
- Method / Endpoint: POST /api/webhooks/whatsapp
	- Purpose: Receive delivery receipts and replies from the WhatsApp Business API\. 
	- Request: Provider\-specific webhook payload\.
	- Response: 200 OK acknowledgment\.
- Method / Endpoint: GET /api/v1/master\-data
	- Purpose: Fetch cached, versioned dropdown data for local IndexedDB storage to support low\-bandwidth form loads\. 

7\. Server Actions

Server Actions act as the primary mutation layer directly from React forms\.

- createRequirementAction: Validates payload via Zod, inserts to requirements table, triggers AI match background job, logs to audit\_logs\. 
- submitQuotationAction: Creates quotations record, generates PDF buffer, queues WhatsApp notification\. 
- acceptQuotationAction: Initiates database transaction to convert requirement status and generate deals record\. 
- updateDispatchStatusAction: Updates dispatches, triggers ETA monitoring, notifies Buyer\. 
- logCrmActivityAction: Inserts broker call/meeting notes into crm\_activities and updates the contact's health score\. 

8\. Database Transactions

Drizzle ORM transactions \(db\.transaction\(\)\) are mandatory for operations spanning multiple tables to prevent orphaned data\.

- Deal Creation: Accepting a quotation must simultaneously update quotations\.status, update requirements\.status, create a deals record, and write an immutable event to audit\_logs\. 
- Dispatch & Upload: Updating dispatches with vehicle data while concurrently saving a reference to the uploaded Lorry Receipt PDF in the files table\. 
- Payment Confirmation: Changing payments\.status to confirmed, calculating the broker commission, updating deals\.status to Closed, and writing to the audit log\. 

9\. Realtime Events

Supabase Realtime handles push\-based UI updates for critical state machines\. 

- Requirement Created: Broadcasts to the assigned Broker's dashboard channel to update the Open Requirements KPI instantly\.
- AI Match Complete: Broadcasts to the Broker to reveal the ranked seller matches\.
- Quotation Sent: Broadcasts to the Buyer's channel to show the incoming PDF quotation without requiring a page refresh\.
- Dispatch Updated: Broadcasts ETA changes to the Buyer's tracking card\.

10\. File Storage

Utilizing Supabase Storage for enterprise document management\.

- Buckets: Private buckets configured with RLS\. Users can only download files linked to their specific deal\_id\.
- Invoices & Documents: Uploads validated on the server for MIME type \(PDF, JPG, PNG\) and size \(Max 5MB\)\. 
- Folder Structure: Organized logically by entity: /deals/\{deal\_id\}/invoices/ or /quotations/\{quotation\_id\}/pdfs/\.
- Naming Convention: \{EntityID\}\_\{DocumentType\}\_\{Timestamp\}\.ext \(e\.g\., DEAL\-2024\-0022\_Invoice\_1715432000\.pdf\)\.

11\. AI Architecture

The Phase 1 matching engine is implemented via a backend rule engine\. 

- Matching Engine: A Server Action retrieves all active availabilities and scores them against the requirement\.
- Rule Engine \(Weighted Score\): Calculates standard deviations\. Commodity \(35%\), Grade \(25%\), Price Proximity \(20%\), Location index \(10%\), Quantity \(7%\), Delivery Date \(3%\)\. 
- Confidence Score: Output is a normalized 0\-100 score\. Results  are flagged with warnings\. 
- Explainability: The engine maps the scoring array to natural language strings \(e\.g\., "Price within target, location match"\) stored in a JSONB column in ai\_match\_results\. 
- Future ML Pipeline: Deal closure statuses act as labeled data for future Phase 2 model training to adjust weights based on successful conversions\. 

12\. Search Architecture

Optimized for Tier\-2 low\-bandwidth requirements\. 

- Database Search: PostgreSQL pg\_trgm extension is utilized for fuzzy string matching, allowing transliterated Hindi searches \(e\.g\., mapping "Soyabean" to "Soybean"\)\. 
- Filters: Passed as query parameters in TanStack query\. Drizzle dynamic where clauses handle complex multi\-field filtering \(status, commodity, dates\)\. 
- Sorting & Pagination: Handled at the database level using LIMIT and OFFSET \(20 items per page for mobile performance\)\. 
- Mobile Number Search: Phone numbers are indexed across users and companies for rapid global lookup\. 

13\. Notification Architecture

The notification engine is decoupled from the main request thread to ensure fast response times\. 

- Event Flow: A database trigger or Server Action writes an intent to the notifications table\. A background worker picks up the row and dispatches the payload via HTTP to external providers\.
- Channels:
	- WhatsApp: Primary channel via official WhatsApp Business API\. Server generates PDFs and sends them directly in template messages\. 
	- Email: Sent via SendGrid/Resend for Admin reporting\.
	- In\-App / Push: Triggered via Supabase Realtime / Firebase Cloud Messaging\.
- Retry Strategy: Failed webhook calls trigger an exponential backoff retry mechanism \(max 3 attempts\)\.

14\. Security

- RBAC & JWT: Strict enforcement at both Next\.js middleware and DB RLS levels\. 
- Audit Logs: Insert\-only operations in the audit\_logs table\. Database triggers block UPDATE and DELETE commands on this table to guarantee immutability\. 
- Input Validation: Every Server Action request strictly validated against Zod schemas before Drizzle interaction\.
- Rate Limiting: Vercel KV/Upstash limits endpoint requests \(e\.g\., maximum OTP attempts, API hits\) to prevent abuse\.
- Security Headers: Next\.js configured with strict Content Security Policy \(CSP\) and standard HTTP security headers\.

15\. Performance

Architected for 2G/3G connectivity\. 

- Caching: Master data \(Commodities, Locations\) cached heavily using Next\.js unstable\_cache and TanStack Query on the client to prevent redundant fetching\.
- Lazy Loading: React Suspense boundaries prevent UI blocking\. Skeleton loaders display immediately while data streams in\. 
- Code Splitting: Next\.js automatic route\-based chunking minimizes JavaScript bundle sizes\.
- Image Optimization: Built\-in Next\.js <Image> component compresses and serves modern formats \(WebP\)\.
- Offline Support: Service workers intercept fetch calls\. Form submissions made offline are written to browser IndexedDB and automatically synced upon reconnection\. 
- Connection Pooling: Supavisor acts as the connection pooler for PostgreSQL to handle high concurrent serverless connections\.

16\. Error Handling

- Validation Errors: Zod errors are caught in Server Actions and returned as standardized \{ error: \{ field: "message" \} \} objects to inform UI inline validation states\. 
- Business Errors: Domain errors \(e\.g\., "Quantity exceeds availability"\) return custom error codes handled by toast notifications\.
- System Errors: Unhandled exceptions trigger standard 500 responses and are logged\. Critical failures on mobile present full\-page retry screens\. 
- Logging: Server\-side errors and warnings aggregated in a centralized monitoring tool \(e\.g\., Sentry\)\.

17\. Background Jobs

Serverless CRON jobs configured via Vercel Cron or Inngest\.

- Expired Quotations: Runs hourly to scan quotations where valid\_until is in the past, transitioning statuses to Expired and notifying parties\. 
- Reminder Jobs: Scans crm\_tasks to trigger WhatsApp/Push reminders for Brokers at their specified alert times\. 
- Dispatch ETA Monitor: Scans dispatches daily\. If current date  ETA and status  Delivered, flags deal as Delayed\. 
- Daily Reports: Aggregates deal closure metrics at midnight to email to Tier 0 Administrators\. 

18\. Monitoring

- Logs & Error Tracking: Sentry deployed on Next\.js to capture frontend crashes and backend exceptions\.
- Metrics: Vercel Analytics utilized to monitor Core Web Vitals, ensuring the strict  second dashboard load time target is maintained\. 
- Health Checks: Dedicated /api/health endpoint monitors Supabase connection status and background job queue health\.

19\. Deployment

- Environments: Development, Staging \(mirrors production\), and Production\.
- Environment Variables: Managed securely in Vercel\. Database URIs, JWT secrets, WhatsApp API keys, and Storage URLs are strictly segregated by environment\.
- Build & Deployment Flow: Automated via Vercel GitHub integration\. PRs trigger staging builds with database branch isolation\. Merges to main trigger automated production builds\.
- Database Migrations: Drizzle Kit generates schema migrations which are automatically applied during the CI/CD deployment step\.

20\. Testing Strategy

- Unit Testing: Jest/Vitest for testing the AI Match confidence score calculations, commission logic, and Zod validation schemas\.
- Integration Testing: Verifying Drizzle queries and transaction locks on the Deal creation workflow\.
- API Testing: Postman collections testing Route Handlers and external webhook processors\.
- Performance Testing: Throttling network in Chrome DevTools/Playwright to verify offline\-queue behavior, skeleton loaders, and form submission on 2G/3G speeds\. 
- UAT \(User Acceptance Testing\): Business testing focused on the strict 60\-second requirement creation threshold\. 

21\. Technical Risks

- Database Concurrency: High\-volume transaction overlap during deal booking could result in overselling inventory\. *Strategy: PostgreSQL row\-level locks \(SELECT FOR UPDATE\) during quotation acceptance transactions\.*
- WhatsApp API Rate Limits: Business limits may throttle notification delivery during peak hours\. *Strategy: Implement robust queuing and fallback to in\-app/push notifications\.*
- Offline Data Conflicts: A requirement generated offline might conflict with updated master data or duplicate submissions\. *Strategy: Enforce unique idempotency keys generated on the client device prior to sync\.*
- Audit Log Scaling: The immutable audit table will grow exponentially\. *Strategy: Plan for table partitioning by date in Phase 2 to maintain query speeds for admin history views\.*

22\. Seller Enterprise Command Center, Authorization & Privacy Architecture (Sprint 13)

- Seller Workspace App Shell & Role-Aware Navigation:
	- Unified responsive shell (`seller-workspace-shell.tsx`) with sticky header (`seller-header.tsx`) and 8-module sub-navigation (`seller-nav.tsx`).
	- Supports both desktop underline tab navigation (Forest Jade `#059669`) and mobile drawer navigation (`Sheet`) with 48px+ touch targets.
	- Real-time KYC status badges (`Verified Entity`, `Pending KYC`, `Action Required`) integrated into the header.
- Seller Role Authorization (`seller-auth.ts`):
	- Granular sub-roles: `SELLER_ADMIN` (full permissions), `SELLER_USER` (operational dispatch/availability management), `SELLER_VIEWER` (read-only monitoring).
	- `verifySellerSession({ allowViewer })` gates all mutations (availabilities, dispatches, invoices) against unauthorized roles and extracts server-authenticated `companyId`.
- Buyer Privacy & Zero Leakage Enforcement:
	- Hard Rule: Seller-facing APIs (`deal-actions.ts`) strictly mask buyer names as `"Verified Buyer #B-XXXX"` and never return Buyer PII (phone, email, GST, address, internal notes).
	- Confidential minimum asking prices are restricted strictly to the owning Seller organization, assigned Broker, or Admin (`availability-actions.ts`).
- Transaction Document Authorization:
	- Request-time signed URL generation (`getTransactionDocumentSignedUrlAction` in `logistics-actions.ts`) verifying that caller is an authorized deal participant (Seller company, Buyer company, Broker, Admin) before generating storage access URLs.
- Shared UX Resilience Baseline:
	- Skeleton loaders (`dashboard-skeleton.tsx`), empty states (`empty-state.tsx`), and data freshness indicators (`data-freshness.tsx`) for slow/unstable Tier-2 mobile connections.
	- Strict error recovery preventing false success dialog closures on mutation failures.


