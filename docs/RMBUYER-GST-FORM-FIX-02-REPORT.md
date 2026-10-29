# RMBUYER-GST-FORM-FIX-02 — GST Verification Form Defects

**Date:** 2026-10-29 · **Branch:** `feature/broker-nilesh` (uncommitted; nothing committed, pushed or deployed)

## Status: **PASS WITH LIMITATIONS**

All three screenshot defects are fixed and covered by regression tests. Limitations:
- Submission stays unavailable, because the secure backend does not exist in production (§4).
- The device's own OCR text for the new screenshot was not captured; fixes were verified against the recorded ML Kit capture of the same certificate.
- On that recorded capture the Valid-from cell is genuinely unreadable (`Jo/O7/2017`). It is therefore left empty and flagged for the buyer to fill in, not guessed.

## 1. Valid from empty

**Reproduced.** The existing reference test asserted `validityFrom == null` for the real capture.

**Root cause.** ML Kit returns the validity value cell on its own line, separate from the "From" label. The parser only accepted a validity date on the same line as "From"/"To". In this photo's capture the cell is also garbled as `Jo/O7/2017`, so even a standalone-date scan skipped it.

**Fix** (`gst_certificate_parser.dart`):
- Standalone date cells are read in document order, **keeping duplicates**. On REG-06 the value column is: liability (row 6), valid from (row 7), issue date (row 9).
- The second date becomes Valid From **only when the layout proves it**: three dates, or the liability date repeated. Two different dates mean the second is the issue date, as before.
- A layout-derived Valid From adds the note "identified from the layout. Please confirm it."
- Only unambiguous digit confusables in date cells are repaired (`O o D Q`→0, `I l | i`→1). Anything else (e.g. `J`) makes the cell **unreadable**: the field stays empty and a review note quotes the raw OCR ("could not be read (OCR read "Jo/O7/2017")").
- The four dates stay separate fields. Valid From is never taken from the issue date or the signature timestamp, and the issue-date logic still excludes liability and valid-from dates.

**Result on the recorded capture:** Valid from stays empty and flagged, which is correct, since the cell is unreadable. With a legible cell (`01/07/2017`, `01/O7/2017` or `Ol/07/2017`) it returns **01/07/2017**.

## 2. Trade name "Paslhu"

**Root cause.** The parser kept ML Kit's text verbatim. ML Kit inserted a stray `l` ("Pasl**h**u").

**Fix.** `GstCertificateParser.repairTradeName`:
- A word in the **trade name only** is corrected when deleting **exactly one interior character** gives a word from a small agri/feed trade vocabulary (Pashu, Aahar, Udyog, Traders, Feeds, Mills, …).
- Words that are already in the vocabulary and unknown words are untouched. Ambiguous matches are untouched, and the original casing is kept.
- There is no global character substitution (`l`→`h` never happens), and personal names are never changed.
- Each correction is flagged: the field helper says "Corrected from the OCR reading — please compare", a review note quotes the raw text, and the field stays editable.

**Result:** "Shiv Shanker Paslhu Aahar Udyog" becomes **"Shiv Shanker Pashu Aahar Udyog"** (flagged).

## 3. Company/profile identity mismatch

**Investigation:**
- **Active user and company:** the device session is the Buyer account `ro***@gmail.com`. Its company is `53b23dbe…` ("Rohan Gupta Pvt. Ltd."), confirmed read-only in RMBUYER-GST-STATUS-TRUTH-01.
- **No fallback:** `BuyerProfileRepository.getProfile()` loads the company only from the signed-in user's own `users.company_id`. The GST screen reads records only for that company ID (tested).
- **Where a fallback exists:** the hard-coded fallback company ID is only in `requirements_repository.dart` (audit F6), not in this flow.
- **Conclusion:** the profile is loaded correctly. The certificate simply belongs to a **different business**, Hari Shankar Khandelwal / Shiv Shanker Pashu Aahar Udyog.

**Defect.** The screen showed "Company name: Rohan Gupta Pvt. Ltd. → Shiv Shanker Pashu Aahar Udyog", which reads as a pending replacement and gives no identity warning.

**Fix:**
- **`GstIdentityCheck`** (domain) flags:
  - a saved GSTIN that differs from the certificate's
  - a company name that matches **neither** the legal name **nor** the trade name, ignoring M/s, Pvt, Ltd, LLP and punctuation

  A sole proprietor whose profile carries their own name or their trade name is **not** flagged.
- **The screen:**
  - The arrow section is replaced by a warning: "Check that this certificate belongs to your business", with the specific mismatch, plus "Your saved profile is not changed by this screen."
  - A required checkbox, "I confirm this certificate belongs to my business", must be ticked before Check or Submit proceeds. Otherwise an error shows and nothing is sent.
  - A new photo resets the confirmation.
- **Nothing is overwritten.** The app writes no company fields (it never has). The company link comes only from the server. When the backend exists, `submit_buyer_gst_verification` derives the company from the session and ignores any client company ID (proven offline in RMBUYER-GST-BACKEND-01).

**Not done:** editing company fields from the app. The Buyer app has no authorized company-write path (`companies` writes are the unsafe policy, audit F1), so legitimate profile corrections stay with support/admin until a secure endpoint exists.

## 4. Submission status

**Verified read-only, 2026-10-29.** The 0054 rollback has been applied in production: the tables, functions, triggers and storage policies are gone. **The empty bucket `brokerbridge_buyer_gst_certificates` still exists** (0 objects) and should be deleted from the Storage UI to complete the rollback. No secure submission endpoint exists.

**App behaviour:**
- The backend flag is off and refused for production, as before.
- The button is labelled **"Check details"**, with a persistent note: "Online submission is not available yet… nothing is saved or sent."
- After a check: "Your details were checked but nothing was saved or sent. Your status remains Not Verified." No success state is possible.
- No client write of `is_verified`, `status` or `trust_score`.

**Dependency:** the reviewed 0053/0054 applied (production rollout proposal in `RMBUYER-GST-BACKEND-01-REPORT.md` §9), plus a test project.

## 5. Files changed

| File | Change |
|---|---|
| `lib/features/profile/data/gst_certificate_parser.dart` | Value-column validity parsing, date-cell confusable repair and unreadable-cell notes, `repairTradeName`, `correctedFields` |
| `lib/features/profile/domain/gst_certificate_data.dart` | `correctedFields`; `GstIdentityIssue` / `GstIdentityCheck` |
| `lib/features/profile/presentation/gst_verification_screen.dart` | Identity warning plus required confirmation (`Material`-backed, see below); "Check details" label and unavailable note; corrected-field helper |
| `test/unit/gst_reference_certificate_test.dart` | Reference assertions updated (trade name now correct and flagged; unreadable Valid From flagged); new groups for validity dates, trade-name repair safety and identity check |
| `test/widgets/gst_verification_screen_test.dart` | Reference mapping updated; identity group; submission test now fills the unreadable Valid From; harness default profile has no company name, so non-identity tests stay independent |

No other files changed. Unrelated uncommitted work was preserved.

**A defect found by the tests was fixed:** a `CheckboxListTile` inside a coloured `Container` raised Flutter's "ink splashes may be invisible" assertion. The warning is now painted by a `Material`.

## 6. Tests

| Required case | Test |
|---|---|
| 1. Valid From returns 01/07/2017 | `validity dates` group: legible cell, plus `01/O7/2017` and `Ol/07/2017` repaired |
| 2. Dates stay distinct | Liability, valid from, valid to and issue date asserted separately; a different valid-from date (15/08/2019) is kept as read; never from the issue date or timestamp |
| 3. Trade name corrected with evidence | Reference "Paslhu" becomes "Pashu" (flagged); UPPER-case variant; "Tradlers" becomes "Traders" |
| 4. Uncertain values remain editable | Unreadable Valid From is flagged, then entered by the user and kept; corrected fields are editable |
| — Similar words not altered | Pashupati, Aahat, Rohan Gupta, Paslu, Feedsx, Lalit Mills, Dal Mill unchanged |
| 5. Another business can't silently attach | Identity warning; submit blocked until confirmed; new photo resets; profile and saved company unchanged; zero profile writes |
| — Sole proprietor not blocked | A profile carrying the trade name or the legal name is not flagged and submits |
| 6. Correct company, no fallback | Records read only for the signed-in user's company (`c-ro`); existing status-truth tests |
| 7. Profile preserved | Saved company name unchanged after OCR, confirm and submit; `writes` empty |
| 8. No false success when unavailable | "Check details" label, unavailable note and notice; no success widget; badge stays Not Verified |

| Command | Result |
|---|---|
| `flutter analyze` | **No issues found** |
| `flutter test test/widgets/gst_verification_screen_test.dart` | **32 passed** |
| `flutter test test/widget_test.dart test/widgets test/unit` | **428 passed, 4 skipped, 1 failed** |
| `flutter build apk --debug` | **Built** (not installed) |

**The 1 failure** is `chat_screen_test.dart` "send is disabled until text…", **tracked separately and unchanged**. Root cause: the fake chat clock is fixed at `2026-10-26` (`test/support/fake_chat_gateway.dart:18`), so the "Today" label only matches on that date.

## 7. Remaining limitations

- The device screenshot's own OCR text was not captured, so fixes were verified on the recorded capture of the same certificate. A device retest is recommended.
- On that capture Valid From is unreadable and needs manual entry. A sharper photo should read it automatically.
- The trade-name vocabulary is deliberately small; other OCR slips stay flagged for manual correction.
- Submission, persistence and reload remain blocked on the backend (§4).
- The empty production bucket still needs deleting from Storage.
