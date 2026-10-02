# Live privacy-policy update evidence

Published on 2 October 2026 through the user's authenticated Chrome tab at `https://bhrchospital.com/backend/cms/company`, using **Save Legal Content**. The CMS reported **Company information saved.** Both privacy-policy fields matched the prepared text exactly after reloading the page. Both Terms and Conditions fields remained unchanged.

## Corrected disclosures

- Android Health Connect reads daily steps only, following explicit connection and permission. Calories, distance and step cadence are not requested.
- Up to seven days of daily step totals, dates and timezone are sent to BHRC servers and linked to the authenticated patient profile, for step-goal progress, activity scores and eligible MyClub points.
- Connection, reopening/resuming and manual refresh trigger syncing while connected.
- Disconnect stops future syncing from the phone. It does not revoke Health Connect permission or delete Health Connect or BHRC server records.
- The seven-day display/sync window is not a retention period. The inspected fitness service has no automatic expiry.
- Portal account deletion does not automatically erase retained patient, fitness or reward records. Step quantities may also be stored in reward events and points transaction descriptions.
- Deletion requests use `info@bhrchospital.com` and require separate handling and confirmation. No automatic erasure or fixed deletion deadline was invented.
- iOS permissions are described separately: the current native iOS implementation still requests steps, active calories and walking/running distance. Android-only steps access is not incorrectly applied to iOS.

## Verification performed

- CMS save acknowledgement and persistence after reload.
- Public English policy visibly renders the new Android, sync, disconnect and retention text at `https://www.bhrchospital.com/privacy-policy`.
- A public HTTP read of `https://www.bhrchospital.com/api/v1/legal-content` at 12:43:37 +05:30 returned exact matches for both policy languages and unchanged Terms and Conditions. See `api-verification.json` and `legal-content-after.json`. Browser navigation to this JSON endpoint was blocked by the browser client; the read-only HTTP request succeeded.
- The local backend policy templates under `BHRC-Hospital/resources/legal` were updated with the corresponding sections and date, preserving their company/contact placeholders.

Files: `cms-before.json` is the prior CMS text; `privacy-policy-en.md` and `privacy-policy-ml.md` are the published text; `public-policy-snapshot.txt` is the observed public page; `public-policy-steps.jpg` shows the updated Android access and server syncing disclosure.

## Remaining gaps

- Retention/deletion statements derive from inspected backend source, not execution of a live deletion request. The deployed backend implementation and manual deletion fulfilment are not verified.
- The live website sidebar still asserts **End-to-End Encryption** and **No Third-party Sharing**. These separate frontend claims are outside the CMS policy and need correction or evidence. The local frontend template already differs from the deployed page.
- The live public page has no Malayalam selector. Malayalam was verified in the CMS and API, not in the public website's rendered policy.
- Reviewer login, Health Connect device reads, live steps-only sync, rewards and disconnect remain untested end to end. The local backend now accepts steps-only requests while retaining optional calorie/distance support; 18 fitness/rewards tests passed. That fix and its schema migration have not been deployed or verified against the live server.
- No Play Console listing, App access instructions or Data safety declaration was edited. Policy publication does not establish Play submission readiness.
