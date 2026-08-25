__BROKERBRIDGE ENTERPRISE__

Product Requirements Document

*Version 4\.0 — Implementation\-Ready Edition*

Status: Active Draft | Industry: Agriculture Commodity Brokerage | Market: India

Prepared for: Development Team | Pre\-TRD Reference Document

# 1\. Product Overview

## 1\.1 Product Vision

Build India's leading AI\-powered brokerage operating system for agricultural and cattle feed raw materials\. The platform minimizes manual data entry through structured workflows and enables buyers, sellers, and brokers to trade efficiently using AI\-assisted matching and market intelligence\.

## 1\.2 Architectural Paradigm

BrokerBridge operates as a multi\-party marketplace with strict data isolation\. Similar to a multi\-tenant SaaS application, user data \(Requirements, Availabilities, Deals\) must be strictly partitioned at the database layer\. Buyers and Sellers operate in isolated silos, while Brokers act as cross\-entity facilitators with explicitly granted access scopes\.

## 1\.3 Product Identity

__Attribute__

__Value__

Product Name

BrokerBridge Enterprise

Product Type

B2B SaaS — Operational ERP/CRM Platform

Target Market

India \(Tier\-2 and Tier\-3 Cities\)

Primary Industry

Agriculture Commodity Brokerage

Primary Users

Buyers, Sellers, Brokers, Administrators

Deployment

Cloud\-hosted, Mobile\-first, WhatsApp\-integrated

PRD Version

4\.0 — Implementation\-Ready Edition

Document Status

Active Draft — Pre\-TRD Reference

# 2\. Problem Statement & Goals

## 2\.1 Challenges

- High brokerage cycle times due to manual coordination via phone/WhatsApp
- Manual data entry causing errors in quantity, pricing, and grades
- Scattered historical commodity data with no analytics or forecasting
- Unstructured negotiations without audit trails or accountability
- No digital workflow for dispatch, payment, and closure
- Brokers managing multiple buyers/sellers without CRM tools

## 2\.2 Primary Goals

- Standardize operational workflows and reduce transaction cycle time by 60%
- Provide a historical commodity intelligence platform with explainable AI recommendations
- Ensure enterprise scalability and strict data security with RBAC
- Enable WhatsApp\-first communication for Tier\-2/Tier\-3 adoption
- Reduce requirement creation time to under 60 seconds

# 3\. Design Philosophy — Tier\-2 India Operational Platform

BrokerBridge is NOT a consumer app\. It is an operational ERP/CRM platform for brokers and businesses\. Every design decision must reflect this reality\.

## 3\.1 Core UX Principles

__Principle__

__Implementation Requirement__

Minimal Typing

All fields that can be dropdown must be dropdown\. Free text only where unavoidable

Large Touch Targets

Minimum 48×48px touch targets\. Buttons minimum 56px height on mobile

Mobile\-First

All screens designed for 360px width first\. Desktop is an enhancement

WhatsApp\-First

Every notification and document shareable via WhatsApp\. PDF export on all key documents

Fast Workflows

Requirement creation under 60 seconds\. No screen should require more than 3 taps to reach

One\-Hand Usage

Primary actions within thumb zone\. Floating Action Buttons for primary CTA

Low Internet

Optimize for 2G/3G\. Compress images\. Lazy load non\-critical data\. Offline queue for form submissions

Card\-Based UI

Cards over tables for mobile\. Tables available for desktop/admin views

Master\-Data Driven

Every lookup field pulls from master data\. No free text for commodity, grade, location, unit

Hindi\-Ready

UI string architecture must support i18n from day one\. Hindi language pack in roadmap

# 4\. Core Features — User Roles, Permissions & Architecture

## 4A\. System Role Hierarchy

__Tier__

__Role__

__Data Scope & Capabilities__

Tier 0

Administrator

God Mode\. Full CRUD across platform\. User management, master data configuration, system audit logs, AI configuration, dispute resolution\.

Tier 1

Broker

Cross\-party visibility restricted to active deals they manage\. CRM management, AI matching execution, quotation generation, dispatch handling, brokerage commission tracking\.

Tier 2

Buyer

Isolated to own profile and company\. Create requirements, track deal statuses, submit quality feedback\.

Tier 2

Seller

Isolated to own profile and company\. Publish inventory, respond to RFQs, track dispatches and payments\.

## 4B\. Unified Dashboard Architecture

A single DashboardView component dynamically composes the UI panels based on the authenticated user's JWT role claim\.

- Admin Mode: System health, user management tables, master configuration inputs
- Broker Mode: AI Match Center, Buy/Sell Demand KPIs, Deal Lifecycle trackers, Quotation workflows, CRM activity feed
- Buyer Mode: Requirement forms, order tracking cards, payment statuses
- Seller Mode: Availability posting, RFQ inbox, dispatch tracker, payment tracker

# 5\. Complete User Journeys

## 5A\. Buyer Journey — Onboarding to Deal Closure

__Step__

__Action__

__System Behavior__

__Validation / Approval__

1

Signup via Mobile/WhatsApp

OTP sent to mobile\. Profile form opens

Mobile number verified\. Mandatory fields enforced

2

Company Profile Setup

Company name, GST, address, district, state from master data

GST format validated\. Admin approval triggered

3

Admin Approval

Admin reviews buyer application

Account activated upon approval\. WhatsApp notification sent

4

Login & Dashboard

JWT issued\. Buyer dashboard rendered

Role verified\. Session established

5

Create Requirement

Commodity, Grade, Quantity, Price, Delivery Terms, Target Date selected from dropdowns

All mandatory fields validated\. Duplicate check run

6

Requirement Submitted

Status: Open\. Broker notified in\-app \+ WhatsApp

Broker assigned automatically or manually by admin

7

AI Match Executed

Broker runs AI match\. Top seller matches presented with confidence score

Broker reviews and selects match

8

Quotation Received

Buyer receives quotation via in\-app \+ WhatsApp PDF

Buyer can Accept, Reject, or Counter

9

Quotation Accepted

Deal created\. Status: Booked

Immutable booking record created\. Audit log entry

10

Dispatch Tracked

Buyer tracks dispatch in real time\. Vehicle, ETA visible

Dispatch confirmed by seller/broker

11

Delivery & Quality Check

Buyer submits quality feedback post\-delivery

Quality rating stored\. Dispute flag if mismatch

12

Payment

Payment status visible\. Invoice downloadable as PDF

Payment confirmed by admin/broker

13

Deal Closed

Deal marked Closed\. Rating prompt shown

Immutable closure record\. Commission calculated

## 5B\. Seller Journey — Onboarding to Deal Closure

__Step__

__Action__

__System Behavior__

__Validation / Approval__

1

Signup

OTP verified\. Seller profile and company form

GST, business type validated\. Admin approval triggered

2

Admin Approval

Admin activates seller account

WhatsApp notification on activation

3

Post Availability

Commodity, Grade, Quantity, Price, Location, Delivery Terms from dropdowns

Availability stored\. Broker sees in AI match pool

4

RFQ Received

Seller gets RFQ notification via in\-app \+ WhatsApp

Seller reviews buyer requirement details

5

Submit Quotation

Seller confirms price, quantity, packaging, delivery terms

Quotation validated and sent to buyer via broker

6

Quotation Accepted

Seller notified\. Deal booked\. Dispatch preparation begins

Dispatch details form unlocked

7

Dispatch Details

Seller enters vehicle number, driver details, loading date, quantity loaded

Validated against deal quantity\. Discrepancy flagged

8

Invoice Uploaded

Seller uploads invoice/lorry receipt

Document validated\. Stored against deal

9

Delivery Confirmed

Buyer confirms delivery\. Quality feedback submitted

If dispute, escalated to broker/admin

10

Payment Received

Payment status updated\. Seller dashboard reflects settlement

Commission deducted and shown transparently

## 5C\. Broker Journey — Onboarding to Commission

__Step__

__Action__

__System Behavior__

__Validation / Approval__

1

Admin creates Broker profile

Broker invited via email/WhatsApp with credentials

Role assigned by admin

2

Broker logs in

Broker dashboard renders: AI Match Center, Active Deals, CRM Feed

Role\-based dashboard routing

3

Receives Buyer Requirement

Notification triggered\. Requirement visible in dashboard

Broker assigned to requirement \(auto or manual\)

4

Run AI Match

AI engine presents ranked seller matches with confidence scores

Broker reviews and selects top match

5

Negotiate & Send Quotation

Broker crafts quotation\. PDF generated and sent via WhatsApp

Quotation logged with timestamp

6

Follow\-Up

CRM task/reminder created\. Call log recorded

Next action date set

7

Quotation Accepted

Deal created\. Broker manages dispatch coordination

Dispatch details tracked

8

Monitor Dispatch

Track vehicle, ETA, delivery confirmation

Exception alerts for delays

9

Post\-Delivery

Quality feedback monitored\. Dispute resolution if needed

Commission calculated on closure

10

Deal Closed

Commission credited\. Deal archived in CRM history

Full deal timeline preserved

## 5D\. Administrator Journey

__Step__

__Action__

__System Behavior__

1

Platform Setup

Configure all master data: commodities, grades, units, locations, GST types, payment terms

2

User Management

Approve/reject buyer and seller applications\. Create broker accounts

3

AI Configuration

Set matching weights, confidence thresholds, and manual override rules

4

Monitor Platform

Review system health dashboard: active users, deals in progress, disputes, errors

5

Audit & Compliance

Access immutable audit logs\. Export reports\. Review all state changes

6

Dispute Resolution

Review flagged deals\. Override statuses with reason documented in audit log

7

Master Data Updates

Add/edit/deactivate commodities, grades, locations\. All changes audit\-logged

# 6\. Master Data Strategy

All lookup data must be managed through a centralized Master Data layer\. Free\-text input must be eliminated wherever a structured value is possible\. Every master table must support: Active/Inactive status, Created/Updated timestamp, Audit trail, Admin\-only edit rights\.

## 6\.1 Master Data Entities

__Master Entity__

__Purpose__

__Example Values__

__Used In__

Commodities

All tradeable commodities

Soybean Meal, Mustard DOC, Maize

Requirements, Availability, Deals

Quality Grades

Grade standards per commodity

Grade A, Grade B, FAQ, Bold

Requirements, Quotations, Quality Check

Packaging Types

Packaging formats

HDPE Bag 50kg, Loose, Jumbo Bag

Requirements, Quotations, Dispatch

Units of Measurement

Quantity units

MT, Quintal, Kg, Bags

Requirements, Availability, Deals

Indian States

All 28 states \+ 8 UTs

Rajasthan, Gujarat, MP

Company, Delivery, Warehouse

Districts

District per state

Jaipur, Indore, Ahmedabad

Company, Delivery Address

Cities / Talukas

City per district

Mansarovar, Pithampur, Vapi

Delivery Location

Transport Types

Mode of transport

Road, Rail, Own Vehicle

Dispatch

Vehicle Types

Vehicle category

Truck 10T, Trailer, Mini Truck, Container

Dispatch

GST Types / HSN Codes

GST slab and HSN

0%, 5%, 12%, 18%, 28%

Invoices, Quotations

Payment Terms

Standard payment windows

Advance, 7 Days Credit, 15 Days, 30 Days

Deals, Quotations

Business Types

Buyer/Seller business category

Manufacturer, Trader, Farm, Co\-operative

Company Profile

Delivery Terms

Delivery responsibility terms

Ex\-Factory, FOR Destination, CIF

Requirements, Quotations

Incoterms

International trade terms

FOB, CIF, EXW, DAP

Export deals

Currencies

Currency types

INR, USD

Quotations, Invoices

Warehouses

Registered warehouses

Jaipur WH\-01, Indore WH\-02

Availability, Dispatch

Companies

All registered companies

Linked to Buyer/Seller profiles

All modules

Broker Companies

Brokerage firms

Linked to Broker profiles

Deals, Commissions

Dispute Reasons

Pre\-defined dispute types

Quality Mismatch, Short Quantity, Delay

Dispute module

Cancellation Reasons

Pre\-defined cancel reasons

Buyer Cancelled, Seller Out of Stock

Requirements, Deals

## 6\.2 Master Data Governance Rules

- Only Administrators can create, edit, or deactivate master data records
- Soft delete only — records are marked inactive, never physically deleted
- All master data changes are audit\-logged with user, timestamp, and before/after values
- Inactive records must not appear in dropdowns but historical references must remain intact
- Commodity\-Grade relationship must be enforced: only valid grades for a selected commodity shown
- District must filter by selected State\. City must filter by selected District \(cascading dropdowns\)

# 7\. Form Specifications

## 7\.1 Buyer Requirement Form

__Field Name__

__Type__

__Mandatory__

__Validation__

__Default__

__Example__

Commodity

Searchable Dropdown

Yes

Must select from master list

None

Soybean Meal

Quality Grade

Dropdown \(filtered by commodity\)

Yes

Must be valid for selected commodity

None

Grade A

Quantity Required

Number

Yes

Must be > 0\. Max 10,000 MT

None

100

Unit

Dropdown

Yes

From UOM master

MT

MT

Target Price \(₹\)

Number

Yes

Must be > 0\. Numeric only

None

38000

Delivery Location State

Dropdown

Yes

From States master

None

Rajasthan

Delivery District

Dropdown \(filtered\)

Yes

Filtered by State

None

Jaipur

Delivery City

Dropdown \(filtered\)

No

Filtered by District

None

Mansarovar

Delivery Terms

Dropdown

Yes

From Delivery Terms master

FOR Destination

FOR Destination

Target Delivery Date

Date Picker

Yes

Must be future date

None

15 Aug 2025

Packaging

Dropdown

No

From Packaging master

None

HDPE 50kg Bags

Payment Terms

Dropdown

Yes

From Payment Terms master

None

7 Days Credit

Special Instructions

Text Area

No

Max 500 characters

None

Moisture < 12%

Priority

Dropdown

Yes

Low / Medium / High / Urgent

Medium

High

## 7\.2 Seller Availability Form

__Field Name__

__Type__

__Mandatory__

__Validation__

__Default__

__Example__

Commodity

Searchable Dropdown

Yes

From master list

None

Mustard DOC

Quality Grade

Dropdown \(filtered\)

Yes

Valid for commodity

None

Bold

Available Quantity

Number

Yes

> 0

None

500

Unit

Dropdown

Yes

From UOM master

MT

MT

Asking Price \(₹\)

Number

Yes

> 0

None

41000

Origin State

Dropdown

Yes

From States master

None

Rajasthan

Origin District

Dropdown \(filtered\)

Yes

Filtered by State

None

Bikaner

Warehouse / Location

Dropdown

No

From Warehouses master

None

Bikaner WH\-01

Delivery Terms Offered

Dropdown

Yes

From Delivery Terms master

Ex\-Factory

Ex\-Factory

Available From Date

Date Picker

Yes

Current or future date

Today

Today

Valid Until Date

Date Picker

Yes

Must be after Available From

None

31 Aug 2025

Packaging Available

Dropdown

No

From Packaging master

None

Loose / HDPE 50kg

Moisture Content %

Decimal Number

No

0 to 100

None

11\.5

Remarks

Text Area

No

Max 500 characters

None

ISI certified stock

## 7\.3 Quotation Form

__Field Name__

__Type__

__Mandatory__

__Validation__

__Default__

__Example__

Linked Requirement

Auto\-filled \(read\-only\)

Yes

System populated

N/A

REQ\-2024\-0045

Linked Seller Availability

Dropdown / AI Selected

Yes

Must be active availability

None

AVAIL\-2024\-0012

Quoted Price \(₹/Unit\)

Number

Yes

> 0

None

39500

Quantity

Number

Yes

> 0, ≤ Req Quantity

None

100

Unit

Read\-only

Yes

From requirement

MT

MT

Delivery Terms

Dropdown

Yes

From master

None

FOR Destination

Payment Terms

Dropdown

Yes

From master

None

7 Days Credit

Valid Until Date

Date Picker

Yes

Must be future date

None

20 Aug 2025

Brokerage % \(Buyer\)

Decimal

Yes

0 to 5%

None

0\.5

Brokerage % \(Seller\)

Decimal

Yes

0 to 5%

None

0\.5

GST Type

Dropdown

Yes

From GST master

None

5%

Delivery Location

Read\-only from Requirement

Yes

System populated

N/A

Jaipur, Rajasthan

Notes to Buyer

Text Area

No

Max 500 chars

None

Subject to availability

## 7\.4 Dispatch Form

__Field Name__

__Type__

__Mandatory__

__Validation__

__Default__

__Example__

Deal Reference

Read\-only

Yes

System populated

N/A

DEAL\-2024\-0022

Dispatch Date

Date Picker

Yes

Current or future

Today

Today

Quantity Dispatched

Number

Yes

> 0, ≤ Deal Quantity

None

100

Vehicle Type

Dropdown

Yes

From Vehicle Types master

None

Truck 10T

Vehicle Number

Text

Yes

Format: XX00XX0000 \(Indian plate\)

None

RJ14GC5511

Driver Name

Text

Yes

Max 100 chars

None

Ramesh Kumar

Driver Mobile

Mobile Number

Yes

10\-digit Indian mobile

None

9876543210

Transport Company

Dropdown / Text

No

From master or free text

None

Shree Transport

Expected Delivery Date

Date Picker

Yes

After dispatch date

None

18 Aug 2025

Loading Location

Dropdown

Yes

From Warehouse master

None

Bikaner WH\-01

Invoice Number

Text

Yes

Alphanumeric

None

INV\-2024\-001

Invoice Amount \(₹\)

Number

Yes

> 0

None

3950000

Upload Invoice / LR

File Upload

Yes

PDF / JPG / PNG\. Max 5MB

None

invoice\.pdf

Remarks

Text Area

No

Max 500 chars

None

Partial dispatch

# 8\. Workflow State Machines

## 8\.1 Requirement Lifecycle

__Current State__

__Allowed Transitions__

__Who Can Transition__

__Editable?__

__Notes__

Draft

Open

Buyer

Yes

Buyer saves as draft before submitting

Open

AI Matched, Cancelled

Buyer \(cancel\), Broker \(match\)

Limited

Only non\-critical fields editable after Open

AI Matched

Quotation Sent, Open

Broker

No

Broker sends quotation or resets to Open

Quotation Sent

Accepted, Rejected, Expired, Countered

Buyer

No

Immutable once quotation sent

Countered

Quotation Sent, Rejected

Broker

No

Broker revises and resends quotation

Accepted \(Booked\)

Dispatch Pending

System \(auto\)

No

Locked\. No edits after acceptance

Dispatch Pending

Dispatched, Cancelled

Seller / Broker

No

Seller enters dispatch details

Dispatched

In Transit

System / Broker

No

ETA tracking begins

In Transit

Delivered

Buyer / Broker

No

Buyer confirms delivery

Delivered

Payment Pending

System \(auto\)

No

Quality check period begins

Payment Pending

Closed, Disputed

Admin / Broker

No

Payment confirmation triggers closure

Disputed

Resolved, Cancelled

Admin

No

Admin resolves with documented reason

Closed

—

—

No

Final immutable state

Cancelled

—

—

No

Cancellation reason mandatory\. Audit logged

Expired

Open \(Reactivate\)

Buyer / Broker

No

Quotation validity expired; can reopen requirement

## 8\.2 Quotation Lifecycle

__State__

__Transition To__

__Triggered By__

__Notes__

Draft

Sent

Broker

Broker prepares and reviews quotation

Sent

Accepted / Rejected / Countered / Expired

Buyer / Timer

PDF shared via WhatsApp

Accepted

— \(Creates Deal\)

System

Immutable\. Deal auto\-created

Rejected

Closed

Buyer

Rejection reason mandatory

Countered

Revised Sent

Broker

Broker revises price/terms

Expired

Closed

Timer \(auto\)

Validity date crossed

## 8\.3 Dispatch Lifecycle

__State__

__Transition To__

__Triggered By__

__Notes__

Pending

Dispatched

Seller

Seller enters vehicle \+ invoice details

Dispatched

In Transit

System / Broker

Dispatch confirmed

In Transit

Delivered / Delayed

Buyer / System

ETA monitoring active

Delayed

In Transit / Cancelled

Broker / Admin

Delay notification sent to buyer

Delivered

Quality Check

Buyer

Buyer confirms receipt

Quality Check

Accepted / Disputed

Buyer

Dispute if quality mismatch

Accepted

Payment Triggered

System

Payment workflow starts

# 9\. Exception Handling — Business Scenarios

__Exception__

__Trigger__

__System Action__

__Notification__

__Resolution Path__

Buyer Cancels Requirement

Buyer clicks Cancel \(pre\-booking\)

Status → Cancelled\. Reason mandatory

Broker notified via WhatsApp \+ In\-app

No penalty\. Audit logged

Buyer Cancels After Booking

Buyer requests post\-booking cancellation

Escalated to Admin\. System flags as disputed

Broker \+ Seller \+ Admin notified

Admin adjudicates\. Cancellation fee may apply

Seller Out of Stock

Seller cancels availability post\-quotation

Quotation withdrawn\. Requirement reverted to AI Matched

Buyer \+ Broker notified

Broker re\-runs AI match or manually reassigns

Duplicate Requirement

Same buyer, same commodity, overlapping date

System warns: "Possible duplicate found"

Inline warning shown to buyer

Buyer confirms or cancels the new entry

Dispatch Delayed

ETA date crossed without delivery confirmation

Status → Delayed\. Alert triggered

Buyer \+ Broker notified via WhatsApp

Broker contacts seller\. New ETA recorded

Wrong Quantity Dispatched

Dispatched quantity ≠ booked quantity

System flags discrepancy\. Short delivery recorded

Buyer \+ Admin notified

Dispute or credit note created

Wrong Pricing on Invoice

Invoice amount ≠ quotation amount

System flags mismatch on upload

Broker \+ Admin alerted

Correction required before payment release

Payment Failed

Payment confirmation not received by due date

Status → Overdue\. Escalation triggered

Seller \+ Broker \+ Admin notified

Admin resolves\. Overdue record created

Broker Reassigned

Admin reassigns a deal to another broker

All CRM history transferred to new broker

Old \+ New broker notified

Deal continuity maintained\. Audit log updated

Dispute Filed

Buyer or Seller raises quality/quantity dispute

Deal status → Disputed\. Admin review triggered

Both parties \+ Admin notified

Admin reviews evidence\. Resolution documented

Quotation Rejected

Buyer rejects quotation

Requirement reverts to AI Matched

Broker notified

Broker re\-negotiates or finds alternate seller

Quotation Expired

Validity date crossed

Auto\-status → Expired by system timer

Buyer \+ Broker notified

Requirement reopened\. New quotation initiated

Quality Rejected

Buyer marks quality as failed post\-delivery

Dispute created\. Deal status → Disputed

Seller \+ Broker \+ Admin notified

Sample testing evidence required for resolution

Master Data Gap

User cannot find commodity/grade in dropdown

User submits request via "Request New Item" option

Admin notified to add to master data

Admin adds item\. User re\-creates entry

# 10\. CRM Module — Broker Relationship Management

The CRM module is exclusively for Brokers and Administrators\. It provides a complete view of buyer\-seller relationships, activity history, and next actions\.

## 10\.1 CRM Features

__Feature__

__Description__

__Fields Required__

Call Logs

Record every phone call with buyer or seller

Contact, Date/Time, Duration, Outcome, Notes, Follow\-up Date

Meeting Notes

Document face\-to\-face or video meetings

Contact, Date, Location/Mode, Attendees, Summary, Action Items

Follow\-Up Tasks

Create tasks for future actions

Task Title, Assigned To \(Broker\), Due Date, Priority, Status, Linked Contact

Reminders

Automated reminder notifications

Reminder Time, Channel \(WhatsApp/Push\), Repeat Frequency

Lead Status

Track buyer/seller as Lead, Active, Inactive, Churned

Status, Reason, Last Activity Date, Next Action Date

Customer Timeline

Chronological feed of all interactions for a contact

All activities sorted by date\. Filter by type

Customer History

All historical deals closed with this contact

Deal list, Total Value, Commodities traded, Dates

Relationship Notes

Persistent notes about the relationship

Note text, Date, Broker, Visibility \(Private/Team\)

Next Action

Clear single next action visible on contact card

Action type, Due date, Assigned broker

Contact Health Score

Engagement score based on recent activity

Score 1–100 based on recency, deal frequency, volume

## 10\.2 CRM Activity Feed

- Activity feed shows all CRM actions for the broker's contacts in reverse chronological order
- Filterable by: Contact, Activity Type, Date Range, Status
- Quick\-action buttons: Log Call, Create Task, Send WhatsApp directly from feed
- Overdue tasks highlighted in red on broker dashboard

# 11\. Search & Filter Standards

__Module__

__Search Fields__

__Filter Options__

__Sort Options__

__Pagination__

__Export__

Requirements

Req ID, Commodity, Buyer Name, Mobile

Status, Commodity, Date Range, Priority, Broker

Date Created, Target Date, Quantity

20 per page

CSV, Excel

Availabilities

Avail ID, Commodity, Seller Name, Location

Status, Commodity, State, Date Range

Date Posted, Quantity, Price

20 per page

CSV, Excel

Deals

Deal ID, Buyer, Seller, Commodity

Status, Commodity, Broker, Date Range, Payment Status

Deal Date, Value, Status

20 per page

CSV, Excel, PDF

Quotations

Quot ID, Requirement ID, Buyer, Seller

Status, Commodity, Valid Until, Broker

Date Sent, Price, Expiry

20 per page

PDF per quotation

Users

Name, Mobile, Email, Company

Role, Status, Registration Date, State

Name, Registration Date

50 per page

CSV, Excel

CRM Contacts

Name, Mobile, Company, Email

Lead Status, Commodity Interest, Broker, Last Activity

Name, Last Activity, Deal Count

20 per page

CSV

Dispatches

Deal ID, Vehicle Number, Driver Name

Status, Date Range, Commodity

Dispatch Date, ETA

20 per page

CSV, Excel

Invoices

Invoice No, Buyer, Seller, Deal ID

Payment Status, GST Type, Date Range

Invoice Date, Amount

20 per page

PDF per invoice, CSV bulk

Audit Logs

User, Action, Entity ID

Role, Action Type, Date Range, Entity Type

Timestamp

50 per page

CSV, Excel

## 11\.1 Saved Filters

- Brokers can save frequently used filter combinations with a custom name
- Saved filters appear as quick\-access chips above the filter panel
- Maximum 10 saved filters per user
- Saved filters are personal and not shared across users

# 12\. Mobile UX Standards — Tier\-2 India

__UX Pattern__

__Standard / Requirement__

Touch Targets

Minimum 48×48px\. Primary action buttons minimum 56px height\. Thumb\-zone placement for FAB

Typography

Minimum 16px body text\. 18px for form labels\. High\-contrast color pairs

Scrolling

Maximum 2 scrolls to reach primary action\. Sticky headers on lists\. No horizontal scroll on mobile

Offline Behavior

Forms queue submissions when offline\. Sync on reconnect\. Offline badge shown in header

Skeleton Loaders

Show skeleton UI for all list and card views while data loads\. Never show blank screen

Empty States

Every list screen must have an empty state with icon, message, and primary action button

Error States

Inline field validation\. Toast for network errors\. Full\-page error for critical failures with retry

Slow Network

Compress all API payloads\. Lazy load images\. Timeout after 15s with retry prompt

Form UX

One logical section per screen on mobile\. Progress indicator for multi\-step forms\. Auto\-advance on dropdown select

Notifications

WhatsApp deeplinks open in WhatsApp app\. Push notifications open relevant screen directly

Search

Search bar visible without scroll on all list screens\. Debounced 300ms\. Min 2 chars to trigger

Language

All UI strings in i18n files from day 1\. Hindi language pack to be added in Phase 2

# 13\. Notification Matrix

__Event__

__Recipient__

__WhatsApp__

__Email__

__Push__

__In\-App__

__Trigger__

Account Pending Approval

New User

✓

✓

—

✓

On registration submission

Account Approved

Buyer / Seller

✓

✓

✓

✓

Admin approves account

Account Rejected

Buyer / Seller

✓

✓

—

✓

Admin rejects account

Requirement Created

Broker

✓

—

✓

✓

Buyer submits requirement

AI Match Found

Broker

—

—

✓

✓

AI matching completes

Quotation Sent

Buyer

✓ \(with PDF\)

✓

✓

✓

Broker sends quotation

Quotation Accepted

Broker \+ Seller

✓

✓

✓

✓

Buyer accepts quotation

Quotation Rejected

Broker

✓

—

✓

✓

Buyer rejects quotation

Quotation Expired

Buyer \+ Broker

✓

—

✓

✓

Validity date crossed

Deal Booked

Buyer \+ Seller \+ Broker

✓

✓

✓

✓

Quotation accepted

Dispatch Initiated

Buyer \+ Broker

✓

—

✓

✓

Seller enters dispatch details

Dispatch Delayed

Buyer \+ Broker \+ Admin

✓

—

✓

✓

ETA crossed, not delivered

Delivery Confirmed

Seller \+ Broker

✓

✓

✓

✓

Buyer confirms receipt

Quality Dispute Filed

Seller \+ Broker \+ Admin

✓

✓

✓

✓

Buyer files dispute

Payment Pending

Buyer \+ Broker

✓

✓

✓

✓

Delivery confirmed, payment due

Payment Overdue

Buyer \+ Admin

✓

✓

✓

✓

Payment date crossed

Deal Closed

Buyer \+ Seller \+ Broker

✓

✓

✓

✓

Admin/Broker marks closed

CRM Task Due Today

Broker

✓

—

✓

✓

Task due date = today \(7 AM\)

Follow\-Up Reminder

Broker

✓

—

✓

✓

Reminder time reached

Master Data Updated

Admin only

—

✓

—

✓

Admin updates master data

New User Registration

Admin

—

✓

✓

✓

Any new registration

# 14\. Permission Matrix

__Feature / Action__

__Admin__

__Broker__

__Buyer__

__Seller__

User Management — View

Full

Own Profile Only

Own Profile Only

Own Profile Only

User Management — Create/Edit/Delete

Full

None

None

None

User Approval

Full

None

None

None

Master Data — View

Full

View Only

Via Dropdown

Via Dropdown

Master Data — Create/Edit/Deactivate

Full

None

None

None

Requirements — Create

Admin Can Create

Can Create on Behalf

Full

None

Requirements — View

Full

Assigned Only

Own Only

None

Requirements — Edit

Full

Limited \(pre\-quotation\)

Limited \(pre\-quotation\)

None

Requirements — Cancel

Full

Assigned

Own \(pre\-booking\)

None

Availability — Post

Admin Can Post

Can Post on Behalf

None

Full

Availability — View

Full

Assigned Only

None

Own Only

AI Match — Run

Full

Full

None

None

Quotation — Create/Send

Full

Full

None

None

Quotation — Accept/Reject

Admin Override

None

Full

None

Deal — View

Full

Assigned Only

Own Only

Own Only

Deal — Edit

Full

None \(post\-booking\)

None

None

Deal — Close

Full

Recommend Only

None

None

Dispatch — Create/Edit

Full

Monitor Only

None

Full

Invoice — Upload

Admin Can Upload

None

None

Full

Invoice — View

Full

Assigned Deals

Own Deals

Own Deals

Payment — Confirm

Full

Recommend

None

None

Dispute — File

Full

None

Full

Full

Dispute — Resolve

Full

None

None

None

CRM — View

Full

Own Contacts

None

None

CRM — Call Log / Meeting / Task

Full

Full

None

None

Reports — View

Full

Own Activity

Own Activity

Own Activity

Reports — Export

Full

Limited

Own Data Only

Own Data Only

Audit Logs — View

Full

None

None

None

Notification Settings — Edit

Full

Own Only

Own Only

Own Only

Dashboard — Admin KPIs

Full

None

None

None

Dashboard — Broker KPIs

Full \(all brokers\)

Own Only

None

None

Dashboard — Buyer KPIs

Full

None

Full

None

Dashboard — Seller KPIs

Full

None

None

Full

# 15\. Database Entity List \(Pre\-ERD Reference\)

The following entities and relationships are expected in the system\. No SQL is defined here — this serves as a guide for the ERD to be created in the Technical Specification\.

__Entity__

__Key Attributes__

__Key Relationships__

Users

ID, Name, Mobile, Email, Role, Status, CompanyID, CreatedAt

Belongs to Company\. Has one Role\. Has many Activities

Companies

ID, Name, GST, BusinessTypeID, StateID, DistrictID, Status

Has many Users\. Has one BusinessType

Buyer Profiles

UserID, CompanyID, TradingName, PreferredCommodities, CreditLimit

Extends User\. Has many Requirements

Seller Profiles

UserID, CompanyID, TradingName, PrimaryCategories, WarehouseIDs

Extends User\. Has many Availabilities

Broker Profiles

UserID, BrokerCompanyID, AssignedBuyerIDs, AssignedSellerIDs

Extends User\. Manages many Deals

Requirements

ID, BuyerID, CommodityID, GradeID, Qty, Unit, TargetPrice, Status, BrokerID, \.\.\.

Belongs to Buyer\. Linked to Broker\. Generates Quotations

Availabilities

ID, SellerID, CommodityID, GradeID, Qty, Price, ValidFrom, ValidUntil, Status

Belongs to Seller\. Used in AI Matching

Deals

ID, RequirementID, QuotationID, BuyerID, SellerID, BrokerID, Status, ClosedAt

Links Requirement \+ Quotation \+ Dispatch \+ Payment

Quotations

ID, RequirementID, AvailabilityID, BrokerID, Price, Qty, Terms, Status, ValidUntil

Belongs to Requirement\. Created by Broker\. Accepted creates Deal

Dispatches

ID, DealID, SellerID, VehicleNo, DriverName, DispatchDate, ETA, Status

Belongs to Deal\. Has many Documents

Invoices

ID, DealID, SellerID, InvoiceNo, Amount, GSTID, Status, FileURL

Belongs to Deal\. Created by Seller

Payments

ID, DealID, Amount, Status, DueDate, ConfirmedAt, ConfirmedByID

Belongs to Deal\. Confirmed by Admin/Broker

Disputes

ID, DealID, FiledByID, Reason, Status, EvidenceURLs, ResolvedByID, ResolvedAt

Belongs to Deal\. Resolved by Admin

Notifications

ID, UserID, EventType, Channel, Status, SentAt, DeepLink

Belongs to User\. Triggered by Events

Activities

ID, UserID, EntityType, EntityID, Action, Timestamp

Polymorphic audit trail for all entities

CRM Contacts

ID, BrokerID, ContactUserID, LeadStatus, HealthScore, LastActivityAt

Belongs to Broker\. Linked to User

CRM Activities

ID, CRMContactID, Type \(Call/Meeting/Note/Task\), Date, Notes, OutcomeID, FollowUpDate

Belongs to CRM Contact

CRM Tasks

ID, BrokerID, CRMContactID, Title, DueDate, Priority, Status, ReminderAt

Belongs to CRM Contact \+ Broker

AI Match Results

ID, RequirementID, AvailabilityID, ConfidenceScore, MatchParams \(JSON\), CreatedAt

Belongs to Requirement \+ Availability

Files

ID, EntityType, EntityID, FileType, FileURL, UploadedByID, CreatedAt

Polymorphic attachment for Dispatch, Invoice, Dispute

Audit Logs

ID, UserID, Action, EntityType, EntityID, OldValue \(JSON\), NewValue \(JSON\), IP, Timestamp

Global immutable event log

Master: Commodities

ID, Name, HSNCode, Category, IsActive

Has many Grades

Master: Grades

ID, CommodityID, Name, Description, IsActive

Belongs to Commodity

Master: States

ID, Name, Code, IsActive

Has many Districts

Master: Districts

ID, StateID, Name, IsActive

Belongs to State\. Has many Cities

Master: Cities

ID, DistrictID, Name, IsActive

Belongs to District

Master: Packaging

ID, Name, WeightKg, IsActive

Used in Requirements \+ Dispatch

Master: Units

ID, Name, Abbreviation, IsActive

Used in Requirements \+ Availability

Master: PaymentTerms

ID, Name, DaysCredit, IsActive

Used in Quotations \+ Deals

Master: VehicleTypes

ID, Name, CapacityMT, IsActive

Used in Dispatch

Master: GSTTypes

ID, Rate, HSNApplicable, IsActive

Used in Invoices

Master: DeliveryTerms

ID, Name, Description, IsActive

Used in Requirements \+ Quotations

Master: BusinessTypes

ID, Name, IsActive

Used in Company profiles

# 16\. AI Specification — Matching & Intelligence Engine

## 16\.1 AI Matching Module

__Parameter__

__Detail__

Inputs

Requirement: Commodity, Grade, Quantity, Target Price, Delivery Location, Target Date, Delivery Terms\. Availability Pool: All active availabilities within valid date range

Matching Weights \(Configurable\)

Commodity Match: 35%\. Grade Match: 25%\. Price Proximity: 20%\. Location Score: 10%\. Quantity Match: 7%\. Delivery Date Match: 3%

Outputs

Ranked list of Availability IDs with Confidence Score \(0–100\)\. Match reason breakdown per parameter\. Top 3 recommended matches highlighted

Confidence Score

80–100: Strong Match \(Green\)\. 60–79: Good Match \(Yellow\)\. 40–59: Partial Match \(Orange\)\. Below 40: Weak Match \(Red — shown but flagged\)

Threshold

Matches below 40 shown with warning\. Admin can adjust threshold\. Default: Show top 5 results regardless of score

Manual Override

Broker can override AI selection with documented reason\. Override reason stored in AI Match Result record

Feedback Loop

When deal is closed successfully, the match result is tagged as Successful\. When rejected, tagged with rejection reason\. Used to retrain model weights

Learning Pipeline

Phase 1: Rule\-based weighted scoring \(launch\)\. Phase 2: ML model trained on historical deal outcomes\. Phase 3: Personalized recommendations per buyer/seller profile

Recommendation Logic

Score calculated per availability: weighted sum of all parameters\. Location score uses state\-district proximity index\. Price proximity uses % deviation from target price

Market Intelligence

Aggregated platform data generates: Average commodity prices \(7\-day, 30\-day\)\. Supply/demand index per commodity\. Seasonality trend chart\. Price movement alerts

Explainability

Every AI recommendation must show a human\-readable reason: e\.g\. "Strong match: Same grade, within 3% of target price, same state delivery"

# 17\. Dashboard KPI Definitions

## 17\.1 Admin Dashboard

__KPI Card__

__Definition__

__Update Frequency__

Total Registered Users

Count of all users by role \(Buyer/Seller/Broker\)

Real\-time

Pending Approvals

Count of users awaiting admin approval

Real\-time

Active Deals

Count of deals in non\-final states \(Booked through Payment Pending\)

Real\-time

Deals Closed This Month

Count of deals with status = Closed in current calendar month

Daily

Total Platform GMV \(Month\)

Sum of all deal values closed this month in ₹

Daily

Active Disputes

Count of deals in Disputed status

Real\-time

AI Match Accuracy \(30 Days\)

% of AI\-matched deals that reached Closed status vs total AI matches run

Daily

Top Commodities \(Month\)

Top 5 commodities by deal count and GMV this month

Daily

## 17\.2 Broker Dashboard

__KPI Card__

__Definition__

__Update Frequency__

My Active Deals

Count of deals assigned to this broker in active states

Real\-time

Open Requirements \(Assigned\)

Count of buyer requirements assigned to this broker pending quotation

Real\-time

Deals Closed \(Month\)

Count of deals this broker closed this month

Daily

My GMV \(Month\)

Total deal value \(₹\) closed by this broker this month

Daily

Commission Earned \(Month\)

Total brokerage commission earned this month

Daily

Overdue Follow\-Ups

CRM tasks that are past due date and not completed

Real\-time

Quotations Pending Acceptance

Count of quotations sent but not yet accepted/rejected/expired

Real\-time

Dispatches Delayed

Count of dispatches past ETA with no delivery confirmation

Real\-time

## 17\.3 Buyer Dashboard

__KPI Card__

__Definition__

__Update Frequency__

Active Requirements

Count of my requirements in non\-final status

Real\-time

Pending Quotations

Count of quotations awaiting my response

Real\-time

Active Orders \(Booked\)

Count of booked deals awaiting dispatch/delivery

Real\-time

In Transit

Count of dispatches currently in transit

Real\-time

Payment Pending

Count of deals where payment is due from me

Real\-time

Deals Closed \(All Time\)

Total deals closed by this buyer

Daily

## 17\.4 Seller Dashboard

__KPI Card__

__Definition__

__Update Frequency__

Active Availabilities

Count of my active availability postings

Real\-time

Pending Quotations

Count of my quotations awaiting buyer response

Real\-time

Active Orders \(Booked\)

Count of booked deals requiring dispatch

Real\-time

Dispatches Pending

Count of deals where I have not yet entered dispatch details

Real\-time

Payment Pending

Count of deals where payment is due to me

Real\-time

Revenue \(Month\)

Total deal value \(₹\) from deals I closed this month

Daily

# 18\. Reports Module

__Report Name__

__Columns__

__Filters__

__Export__

__Access__

__Frequency__

Deal Summary Report

Deal ID, Date, Buyer, Seller, Broker, Commodity, Grade, Qty, Value, Status

Date Range, Commodity, Broker, Status

CSV, Excel, PDF

Admin, Broker \(own\)

On\-demand

Commission Report

Deal ID, Broker, Buyer Brokerage %, Seller Brokerage %, Value, Commission ₹

Date Range, Broker, Commodity

CSV, Excel

Admin, Broker \(own\)

Monthly, On\-demand

Requirement Aging Report

Req ID, Commodity, Buyer, Created Date, Days Open, Status, Broker

Date Range, Status, Commodity, Broker

CSV, Excel

Admin, Broker

On\-demand

Buyer Activity Report

Buyer Name, Company, Requirements Created, Deals Closed, GMV

Date Range, State, Commodity

CSV, Excel

Admin, Buyer \(own\)

Monthly, On\-demand

Seller Activity Report

Seller Name, Company, Availabilities Posted, Deals Closed, Revenue

Date Range, State, Commodity

CSV, Excel

Admin, Seller \(own\)

Monthly, On\-demand

Dispatch Tracker Report

Deal ID, Vehicle, Driver, Dispatch Date, ETA, Actual Delivery, Status

Date Range, Status, Commodity

CSV, Excel

Admin, Broker

On\-demand

Payment Report

Deal ID, Buyer, Invoice No, Amount, Due Date, Paid Date, Status

Date Range, Payment Status, Buyer

CSV, Excel

Admin

Monthly, On\-demand

AI Match Performance

Match ID, Req ID, Top Score, Selected Score, Converted to Deal, Rejection Reason

Date Range, Commodity, Broker

CSV, Excel

Admin only

Monthly

Market Price Trend

Commodity, Date, Avg Price, Min Price, Max Price, Volume

Commodity, Date Range, State

CSV, Excel, PDF Chart

Admin, Broker

Daily, On\-demand

Audit Log Report

Timestamp, User, Role, Action, Entity, Old Value, New Value, IP

Date Range, User, Role, Action Type

CSV, Excel

Admin only

On\-demand

# 19\. Audit Logging — Immutable Event Registry

Every significant user action and system event must be recorded in an immutable audit log\. Logs must never be editable or deletable by any user including administrators\.

__Audit Event__

__Entity__

__Captured Data__

__Triggered By__

User Login

User

UserID, IP, Timestamp, Device, Success/Fail

System on auth

User Logout

User

UserID, Timestamp, Session Duration

System on logout

Failed Login Attempt \(3\+\)

User

IP, Timestamp, Attempt Count

System auto

Account Created

User

All registration fields, Created By

Admin / Self\-registration

Account Approved / Rejected

User

UserID, Decision, Reason, Admin ID

Admin action

Role Changed

User

UserID, Old Role, New Role, Changed By

Admin action

Password Changed

User

UserID, Timestamp \(no actual password\)

User / Admin

Requirement Created

Requirement

All fields at creation

Buyer / Broker

Requirement Edited

Requirement

Changed fields only \(old vs new values\)

Buyer / Broker

Requirement Status Changed

Requirement

Req ID, Old Status, New Status, Changed By

Any permitted actor

Requirement Cancelled

Requirement

Req ID, Cancellation Reason, Cancelled By

Buyer / Admin

Availability Posted

Availability

All fields at creation

Seller / Broker

Availability Deactivated

Availability

Avail ID, Reason, Deactivated By

Seller / Admin

AI Match Run

AI Match

Req ID, Top Results, Weights Used, Confidence Scores

Broker trigger

Quotation Created

Quotation

All quotation fields

Broker

Quotation Sent

Quotation

Quot ID, Sent To, Channel, Timestamp

Broker

Quotation Accepted / Rejected

Quotation

Quot ID, Decision, Reason, Buyer ID

Buyer

Price Changed on Quotation

Quotation

Old Price, New Price, Reason, Changed By

Broker

Deal Created

Deal

All deal fields at creation

System on acceptance

Deal Status Changed

Deal

Deal ID, Old Status, New Status, Changed By

Permitted actor

Deal Closed

Deal

Deal ID, Closure Reason, Commission, Closed By

Admin / Broker

Dispatch Created

Dispatch

All dispatch fields

Seller

Dispatch Updated

Dispatch

Changed fields only

Seller / Broker

Delivery Confirmed

Dispatch

Deal ID, Confirmed By, Timestamp, Quality Rating

Buyer

Dispute Filed

Dispute

Deal ID, Reason, Filed By, Evidence

Buyer / Seller

Dispute Resolved

Dispute

Resolution, Resolved By, Timestamp, Notes

Admin

Payment Confirmed

Payment

Deal ID, Amount, Confirmed By, Timestamp

Admin / Broker

Master Data Created

Master Table

Entity Type, New Record Details, Created By

Admin

Master Data Updated

Master Table

Entity Type, Record ID, Old vs New Values, Updated By

Admin

Master Data Deactivated

Master Table

Entity Type, Record ID, Reason, Deactivated By

Admin

Permission Changed

User/Role

Role, Feature, Old Permission, New Permission, Changed By

Admin

Report Exported

Report

Report Type, Filters Applied, Exported By, Timestamp

Any permitted user

CRM Activity Logged

CRM

Contact ID, Activity Type, Summary, Broker ID, Timestamp

Broker

# 20\. Tier\-2 India Optimization Strategy

__Area__

__Requirement__

__Implementation Notes__

Mobile\-First Design

All screens must work perfectly on 360–414px width Android phones

Design in Figma at 360px\. Test on low\-end Android devices

WhatsApp Integration

All notifications, quotations, and invoices must be shareable via WhatsApp

Generate PDF for quotations and invoices\. WhatsApp share API integration\. Template messages for business accounts

Low Bandwidth

App must function on 2G/3G connections

Compress JSON payloads\. Lazy load images\. CDN for static assets\. API response caching\. Target: all API calls under 500KB

Hindi Language Support

UI must support Hindi from Phase 2

All UI text in i18n JSON files from day 1\. No hardcoded strings\. Hindi translation ready for Phase 2 release

Search by Mobile Number

All user searches must support mobile number lookup

Mobile number indexed in all user tables\. Appears in all search bars for admin and broker

Large Buttons

All interactive elements designed for fat\-finger accuracy

Minimum 48px touch target\. Primary CTA buttons minimum 56px height\. 8px minimum spacing between interactive elements

Minimal Typing

Typing must be the exception, not the rule

All location, commodity, grade, unit, payment term, delivery term fields must be dropdown\. Numeric pad for quantity and price inputs

Quick Forms

Requirement creation under 60 seconds

Pre\-fill company and common preferences\. Smart defaults from recent entries\. One\-tap reuse of previous requirements

PDF Quotation Sharing

Quotations must be immediately shareable as PDF via WhatsApp

Server\-side PDF generation\. PDF includes: commodity, grade, quantity, price, terms, broker contact, validity\. QR code for digital verification

GST\-Friendly Workflow

GST number capture, HSN code auto\-fill, invoice generation

GST master with rate lookup by HSN\. Invoice PDF with GST breakup\. Auto\-calculate CGST/SGST/IGST based on buyer\-seller state match

Offline Form Queue

Forms submitted while offline must queue and sync

Service worker intercepts form submissions\. IndexedDB queue\. Sync on reconnect with conflict resolution

Vernacular Search

Allow search in transliterated Hindi

Fuzzy search with phonetic matching\. Example: "Soyabean" matches "Soybean"\. Phase 2: native Hindi script search

# 21\. Success Metrics & KPIs

__Metric__

__Definition__

__Target__

__Measurement Method__

Requirement Creation Time

Time from opening form to submission

< 60 seconds

Frontend telemetry: form\_start to form\_submit events

Dashboard Load Time

Time to interactive on dashboard after login

< 2 seconds on 4G

Lighthouse \+ real\-user monitoring \(Core Web Vitals\)

AI Match Accuracy

% of AI\-top\-1 matches that convert to closed deals

> 60% within 6 months

AI Match Result vs Deal Closed cross\-reference

Broker Productivity

Average deals closed per broker per month

Baseline Month 1; 25% improvement by Month 6

CRM \+ Deal module analytics

Daily Active Users \(DAU\)

Unique users logging in per day

70% of registered users weekly active

Session analytics

Deal Conversion Rate

% of Requirements that result in a closed deal

> 40% within 3 months

Requirements vs Closed Deals ratio

Repeat Buyer Rate

% of buyers who create 2\+ requirements

> 50% within 3 months

Buyer requirement count cohort analysis

Repeat Seller Rate

% of sellers who post 2\+ availabilities

> 50% within 3 months

Seller availability count cohort analysis

Quotation Response Time

Avg time from quotation sent to buyer response

< 4 hours

Quotation sent\_at vs responded\_at timestamps

Dispatch Delay Rate

% of dispatches where actual delivery > ETA

< 15%

Dispatch ETA vs Delivery Confirmed timestamps

Dispute Rate

% of closed deals that had a dispute

< 5%

Dispute records vs Closed Deals ratio

WhatsApp Open Rate

% of WhatsApp notifications opened/read

> 80%

WhatsApp Business API delivery receipts

API Response Time \(P95\)

95th percentile API response time

< 800ms

API gateway monitoring

System Uptime

Platform availability excluding planned maintenance

> 99\.5% monthly

Infrastructure monitoring \(uptime\.betterstack\.com or equivalent\)

# 22\. Pre\-TRD Document Requirements

Before the Technical Requirements Document \(TRD\) can begin, the following documents must be completed\. The PRD is now the foundation\. The following documents expand each PRD section into implementation\-ready specifications\.

__Document__

__Description__

__Owner__

__Inputs From PRD__

__Blocks TRD?__

Functional Specification Document \(FSD\)

Detailed functional behavior of every screen, workflow, and business rule\. Screen\-by\-screen specification\.

BA / Product Manager

Sections 5, 7, 8, 9, 10

YES

UX Specification

Screen layouts, component specifications, interaction patterns, navigation flows, empty/error/loading states for all screens\.

UX Designer

Sections 3, 12, 7

YES

Wireframes

Low\-fidelity wireframes for all screens\. Mobile\-first\. Must cover: all user journeys, modals, empty states, and error screens\.

UX Designer

Sections 5, 7, 12

YES

Database ERD

Entity\-Relationship Diagram showing all entities, attributes, and relationships\. Normalized schema with cardinality\.

Architect / DBA

Section 15

YES

Permission Matrix \(Finalized\)

Complete feature\-level permission table validated with all stakeholders\.

BA / Security Lead

Section 14

YES

Notification Matrix \(Finalized\)

Complete event\-channel\-recipient\-trigger table validated and signed off\.

BA / Product Manager

Section 13

YES

API Contracts \(Draft\)

Draft API endpoint list with method, path, request/response schema, auth requirements, pagination\.

Tech Lead / Architect

Sections 5, 7, 8

YES

Validation Rules Document

Field\-level validation for every form\. Includes min/max, formats, dependencies, error messages\.

BA / Tech Lead

Section 7

YES

Sequence Diagrams

Sequence diagrams for critical flows: Login, Requirement → Deal, AI Match, Dispatch, Payment, Dispute\.

Architect

Sections 5, 8

YES

AI/ML Specification

Detailed specification for AI matching: training data requirements, model selection, confidence logic, feedback pipeline\.

AI/ML Architect

Section 16

YES

Integration Specification

WhatsApp Business API, SMS Gateway, PDF Generation service, Payment Gateway integration requirements\.

Tech Lead

Sections 13, 20

YES

Infrastructure & Deployment Plan

Cloud provider, environment setup \(dev/staging/prod\), CI/CD, monitoring, backup, DR plan\.

DevOps / Architect

Section 5

RECOMMENDED

- All YES items in the "Blocks TRD?" column must be completed before TRD authoring begins\.
- Documents must be version\-controlled and reviewed by at least two stakeholders\.
- The TRD author must sign off that all pre\-TRD documents have been reviewed\.
- The PRD \(this document\) is the root reference for all subsequent documents\.

# Appendix A: Deal Status Codes Reference

__Status Code__

__Display Label__

__Color__

__Module__

REQ\_DRAFT

Draft

Gray

Requirement

REQ\_OPEN

Open

Blue

Requirement

REQ\_MATCHED

AI Matched

Purple

Requirement

REQ\_QUOTED

Quotation Sent

Indigo

Requirement

REQ\_ACCEPTED

Accepted / Booked

Green

Requirement

REQ\_REJECTED

Rejected

Red

Requirement

REQ\_CANCELLED

Cancelled

Dark Gray

Requirement

REQ\_EXPIRED

Expired

Orange

Requirement

DEAL\_DISPATCH\_PENDING

Dispatch Pending

Yellow

Deal

DEAL\_DISPATCHED

Dispatched

Blue

Deal

DEAL\_IN\_TRANSIT

In Transit

Cyan

Deal

DEAL\_DELAYED

Delayed

Orange

Deal

DEAL\_DELIVERED

Delivered

Teal

Deal

DEAL\_PAYMENT\_PENDING

Payment Pending

Amber

Deal

DEAL\_DISPUTED

Disputed

Red

Deal

DEAL\_CLOSED

Closed

Green \(Dark\)

Deal

DEAL\_CANCELLED

Cancelled

Dark Gray

Deal

# Appendix B: Version History

__Version__

__Date__

__Author__

__Summary of Changes__

1\.0

—

Product Team

Initial product concept and goals

2\.0

—

Product Team

Role architecture and workflow additions

3\.0

—

Product Team

Architectural paradigm and multi\-tenant model added

4\.0

August 2025

Senior Product Architect

Full implementation expansion: User Journeys, Master Data, Form Specs, State Machines, Exception Handling, CRM, Search Standards, Mobile UX, Notification Matrix, Permission Matrix, DB Entities, AI Spec, Dashboard KPIs, Reports, Audit Logs, Tier\-2 Optimization, Success Metrics, Pre\-TRD Checklist

