# RMBUYER-MANDI-BROKERS-UI-01 — Mandi Brokers directory UI

**Status: PASS WITH LIMITATIONS**: Chat is shown disabled because RMBuyer has no messaging feature. "Nearby", ratings, experience and business statistics are omitted because no real data exists for them.

Date: 2026-10-26 · Branch `feature/broker-nilesh` · uncommitted

## Files changed
| File | Change |
|---|---|
| `lib/features/search/presentation/widgets/broker_result_card.dart` | Card redesigned and made stateful. Adds a Call/WhatsApp/Chat action row, an `UnverifiedBadge`, and a duplicate-tap guard |
| `lib/features/search/presentation/brokers_screen.dart` | New header, subtitle and search hint; chips are `All Brokers (n)` / `Verified` / `Filters` |
| `test/widgets/broker_result_card_test.dart` | Rewritten: 10 tests |
| `test/widgets/brokers_screen_test.dart` | Rewritten: 6 tests |
| `test/widgets/navigation_shell_test.dart` | Subtitle string updated |
| `test/widgets/broker_selection_flow_test.dart` | Trust label updated (`96%` became `Trust Score: 96%`) |

`BrokerResultCard` is shared, so the **Home** (`home_screen.dart:298`) and **Search** (`buyer_search_screen.dart:319`) broker lists also get the new card. Their source code was not edited.

## Visual changes
- **Header:** larger "Mandi Brokers" title. Subtitle: "Connect with trusted brokers for your procurement needs." The refresh button is a soft-green rounded square and is disabled while loading.
- **Search:** full-width field. Hint: "Search by broker name, mandi or commodity...".
- **Filter chips:** pill chips in a `Wrap`. The earlier horizontal scroller pushed the Filters chip off-screen at 360px.
  - The selected chip is solid deep green; the others are soft green.
  - `All Brokers (n)` shows the real loaded count.
- **Card, identity section:**
  - 56px initial avatar (no profile-image field exists).
  - Bold name, with the badge wrapping beside or below it.
  - **Verified Broker** pill (green) when `is_verified == true`; otherwise a neutral grey **Unverified Broker** pill.
  - Firm name underneath.
- **Card, attributes:**
  - Trust score, only when verified and stored.
  - Location (map-pin icon).
  - Commodities as one line (sprout icon).
  - A missing attribute is hidden and leaves no gap.
- **Card, actions:** a divider, then three equal 48px actions.
  - Call and WhatsApp: green on soft green.
  - Chat: blue on soft blue.
  - A disabled action turns muted grey.
  - The chevron was removed, and the whole card is still tappable.

## Fields actually used
`name`, `mobile`, `companies.name`, `companies.is_verified`, `companies.trust_score`, `location`/`mandi`, `commodities`. These are the existing `BrokerModel` fields from `SearchRepository.searchBrokers`, which is unchanged.

The existing helpers `brokerDisplayLocation`, `brokerFirmName` and `brokerCommodities` filter out the model's placeholder values ("Mandi Trading Floor", "Licensed Mandi Broker Desk", default commodities).

**Not displayed (no data source):**
- rating and review count
- years of experience
- deals completed
- active buyers
- response rate
- profile photo

None of these were invented. A test asserts that none of the labels appear.

Note: the live `searchBrokers` select does not request `location` or `commodities`. Live cards therefore usually show only the name, badge, firm and trust score. That is a data gap, not a UI bug, and was left for a later sprint.

## Contact actions
| Action | Behaviour | Verified by test |
|---|---|---|
| Call | `ContactLauncherService.launchCall` opens the system dialer with a `tel:` URI. It never places a call directly. A failure shows "Could not open the phone dialer." | `tel:+919829012345` launched; the profile is not opened |
| WhatsApp | `launchWhatsApp` opens `https://wa.me/<digits>?text=…`. The existing +91 rule for 10-digit numbers applies. The prefilled message is only a draft: the user sends it. A failure shows "Could not open WhatsApp." | `/919829012345` with the `Hello Asha…` text. An invalid `---` number does not launch and reports the failure |
| No number | Call and WhatsApp render muted. Tapping explains: "Contact details for this broker are pending verification." | Nothing is launched |
| Chat | **Not implemented in RMBuyer.** There is no route, screen or table access for buyer↔broker messaging. The button is disabled; a tap explains "In-app chat is not available yet. Use Call or WhatsApp…". It does not navigate. | No push occurs |

**Authorization:** the `mobile` number appears only when the existing query and RLS return it. Nothing was broadened.

**Taps:** the action buttons are separate `InkWell`s, so tapping one does not open the profile. A per-card guard ignores repeat taps while a launch or navigation is pending, and a test confirms that two taps produce one launch.

## Unsupported or omitted
- **Nearby:** omitted, because the app stores no buyer location.
- **Overflow (⋮) menu:** omitted, because there are no legitimate actions for it.
- **Filters:** opens the existing location sheet. The chip shows the selected location's name when one is active.

## Tests and checks
- `dart format`: run on `brokers_screen.dart` and the two rewritten tests. It was not run on the card, because the package isn't uniformly formatted.
- `flutter analyze`: **No issues found.**
- `flutter test test/widget_test.dart test/widgets test/unit`: **314 passed, 4 skipped, 0 failed.** No live-DB tests were run.
- `flutter build apk --debug`: **built** `app-debug.apk`.

## Confirmations
- No changes to the database, schema, RLS, auth, backend, API or repository. No production data was written.
- Pre-existing uncommitted changes were preserved, and only the files above were touched.
- Nothing was committed, pushed or deployed.
