# RMBUYER-BROKER-PROFILE-UI-01 — Broker Profile redesign

**Status: PASS WITH LIMITATIONS**: the layout, identity, about, commodities, contact actions and CTA are done. The metrics, ratings, address, map, share, favorite and chat parts of the reference have **no backend source** and were not invented.

Date: 2026-10-26 · Branch `feature/broker-nilesh` · uncommitted

## Files changed
| File | Change |
|---|---|
| `apps/rmbuyer_mobile/lib/features/search/presentation/broker_profile_screen.dart` | Screen rebuilt to the reference structure |
| `apps/rmbuyer_mobile/lib/features/search/presentation/widgets/broker_result_card.dart` | `UnverifiedBadge` label made `Flexible`, fixing an overflow on narrow screens and large text |
| `apps/rmbuyer_mobile/test/widgets/broker_profile_screen_test.dart` | Rewritten: 6 tests |
| `apps/rmbuyer_mobile/test/widgets/broker_selection_flow_test.dart` | Expectations updated for the new title, labels and Contact Person row |

## Reference comparison
| Reference element | Implemented |
|---|---|
| Back, "Broker Profile", refresh | ✅ Refresh re-fetches through `SearchRepository.getBrokerById` and is disabled while loading |
| ⋮ overflow menu | ❌ Omitted: no supported actions |
| Avatar, name, company | ✅ |
| Verified badge | ✅ "Verified Broker" only when `companies.is_verified == true`; otherwise a grey "Unverified Broker" |
| ★ rating (reviews) | ❌ No ratings or reviews data. Replaced by one honest line: "Ratings, reviews and trade history are not available yet." |
| ♡ favorite | ❌ No shortlist feature exists |
| Call / WhatsApp / Chat | ✅ Icon-only 56px circular buttons with tooltips and semantic labels. Chat is disabled (see below) |
| Share | ❌ No share capability (no `share_plus`) |
| Metrics row (experience, deals, rating, clients) | ❌ No fields or aggregates exist, so the row is omitted (not shown as zeros) |
| About This Broker | ✅ Business Name, Contact Person, Verification Status and GST Registration, each only when present |
| Deals In (Commodities) | ✅ Wrapping chips from the broker record, with the empty state "No commodities listed for this broker yet." No commodity images |
| Location & Address + map | ⚠️ Only a **Location** row, shown when a real `location`/`mandi` value exists. There's no address field, coordinates or map launcher, so no map preview or "View on Map" |
| Fixed CTA | ✅ "Post Requirement with this Broker": solid green, safe-area aware, guarded against repeat taps |

**Also kept:** the trust score badge, shown only when the broker is verified and a score is stored (existing rule).

## Data fields used
`users.id`, `users.name` (heading and Contact Person), `users.mobile`, `companies.name`, `companies.gst`, `companies.is_verified`, `companies.trust_score`, `location`/`mandi`, `commodities`/`commodities_handled`.

All come through the unchanged `BrokerModel` and repository. The placeholder filters (`brokerDisplayLocation`, `brokerFirmName`, `brokerCommodities`) still hide the model's substituted defaults.

## Actions
- **Call:** `ContactLauncherService.launchCall`, which opens the dialer via `tel:`. A failure shows a message.
- **WhatsApp:** `launchWhatsApp` opens `wa.me/<digits>` (91 prefix for 10-digit numbers) with a draft message the user sends themselves.
- **No `mobile`:** both buttons are muted, labelled "… unavailable", and explain "Contact details for this broker are pending verification." Nothing launches.
- **Chat:** RMBuyer has no messaging route or table access. The button is disabled; a tap explains that and opens nothing.
- **Post Requirement:** pushes `/requirements/new` with `extra: {brokerId, brokerName, blankCommercialTerms: true}`.
  - **Behaviour change:** the old CTA prefilled the broker's *first* commodity. It also didn't set `blankCommercialTerms`, so the form preset quantity 50, price 4800 and a +14-day date.
  - The form now starts with only the broker association.

## Tests and checks
- `dart format`: the profile screen and its test.
- `flutter analyze`: **No issues found.**
- `flutter test test/widget_test.dart test/widgets test/unit`: **317 passed, 4 skipped, 0 failed.** No live-DB tests were run.
- `flutter build apk --debug`: **built.**

**Coverage:**
- identity and company
- verified and unverified badges
- no fabricated metrics, ratings, address, map or share
- commodities from the record, plus the empty state
- location shown only when real
- icon-only actions with semantics and correct `tel:`/`wa.me` destinations
- missing number
- chat unavailable
- CTA passes the exact broker id with blank terms, and pushes once on a double tap
- loading, not-found, network error with retry, and refresh
- no overflow at 320px

## Backend follow-up (needs approval as a separate sprint)
1. **Broker ratings and reviews:** a source table plus a buyer-readable aggregate.
2. **Broker metrics:** experience (stored), plus completed deals and active clients. These need an RLS-safe aggregate, because buyers cannot read `deals` today.
3. **Broker business address:** address and mandi fields on companies or a broker profile, with a map URI.
4. **Buyer↔broker chat.**
5. **Location and commodities in the select:** the live `searchBrokers`/`getBrokerById` selects don't request them, so live profiles usually show neither.

## Confirmations
- No database, schema, RLS, auth, backend or API changes. No data was written.
- Unrelated uncommitted work was preserved. Nothing was committed, pushed or deployed.
