# AI Collaboration Log (PROMPTS.md)

This is my running commentary on building the expiring-download-links app with an AI assistant.
For each phase I note what I asked for, what the AI gave back, and — the part that matters —
what I kept, what I changed, and what I overrode, with the reasoning. The AI wrote a lot of the
first-draft code; the judgment about what survived is mine.

---

## 1. Planning & project shape

**Prompt:** "Read the SendOwl code test PDF and propose a project plan."

**What the AI gave me:** A plan that split the work into a Rails API and a separate Svelte
frontend, and flagged that the download-limit requirement implies a concurrency problem.

**What I decided:** I kept the API/frontend split but chose to keep both in one monorepo
(`api/` + `frontend/`) rather than two repos — less ceremony for a code test, and it keeps the
e2e tests next to the thing they exercise. I picked PostgreSQL over SQLite specifically because
the concurrency story (row-level locking) is only honest on a real RDBMS; SQLite's locking would
have hidden the problem the brief is asking about.

---

## 2. Data model & the download-link lifecycle

**Prompt:** "Generate Product, Order, and DownloadLink models for the schema above."

**What the AI gave me:** Straightforward models with a token stored in plaintext on
`DownloadLink`, and link creation inline in the controller.

**What I changed:**
- **Moved link generation onto the model.** `Order#after_create :generate_download_link` keeps the
  controller thin and guarantees every order has a link — there's no valid state where an order
  exists without one.
- **Hashed the token.** I replaced the plaintext token with `SecureRandom.urlsafe_base64(32)`
  (256 bits) stored only as its SHA-256 hash. The raw token lives only in the emailed URL. This
  was a deliberate override of the AI's simpler design: if the DB leaks, the stored hashes can't
  be turned back into working links.
- **Consequence I accepted:** because the hash is one-way, a lost link is unrecoverable — you can
  only issue a *new* token. That shaped the resend design below.

---

## 3. Concurrency against the download limit

**Prompt:** "How should I stop concurrent downloads from exceeding max_download_count?"

**What the AI gave me:** A read-check-then-increment in the controller
(`if count < max then count += 1`).

**Why I rejected it:** that's the textbook race — N concurrent requests all read the same count,
all pass the check, all increment. The limit gets blown past.

**What I did instead:** `DownloadLink#increment_download!` wraps the check-and-increment in
`with_lock` (Postgres `SELECT ... FOR UPDATE`), so concurrent requests serialize on the row and
re-evaluate `active?` one at a time. I proved it rather than asserting it: a model spec spins up
5 threads hitting `increment_download!` on the same row and asserts the count never exceeds the
limit (`spec/models/download_link_spec.rb`). I left an inline comment at the lock because it's the
single most important line in the app.

---

## 4. Resend semantics — the decision I most want to defend

**Prompt:** "Add a 'resend link' action for the admin."

**What the AI gave me:** A resend that minted a fresh token and a fresh expiry window, no guards.

**Why I overrode it:** that quietly destroys the product. A buyer (or anyone with the order)
could resend forever to keep getting new 24h windows, and an expired link could be resurrected —
expiry would mean nothing. So I made two deliberate choices and documented them in the README as
design, not accident:
1. **Resend is refused for expired or limit-reached links** (and the dashboard disables the button
   in those states). Resend re-delivers a *still-valid* link; it is not a recovery tool for dead
   ones.
2. **The new link keeps the original expiry and carries the download count over.** `expires_at` is
   anchored to the order's `created_at`, not `Time.current`, so resending never extends the clock
   or refunds downloads.

This is the kind of thing where "the AI generated it" wouldn't be a defense — the naive version
looks like it works and passes a happy-path test, but it's wrong.

---

## 5. What the buyer sees: expired vs. limit-reached

**Prompt:** "Build the buyer download page and the download API."

**What the AI gave me:** A `GET` that returned a 403 for expired/exhausted links, and a page that
showed a raw error.

**What I changed:** I split the flow into **GET (info) / POST (trigger)**. The GET returns `200`
with status flags (`expired`, `limit_reached`, `expires_at`) *even when the link is dead*, so the
Svelte page can render a specific, friendly explanation ("Link expired on <date>" vs. "Download
limit reached") instead of a browser error page. The actual download is a separate POST that does
the locked increment; if the limit is hit concurrently between page-load and click, the POST
returns 403 and the page surfaces it. I added inline comments on both the controller (why 200, not
4xx) and the Svelte branch.

---

## 6. Not leaking the token hash

**Prompt (review):** "Does the orders JSON expose anything it shouldn't?"

**What I found:** the order serialization included the `download_link`, which dragged `token_hash`
along with it. It's not exploitable (you can't reverse SHA-256 of a 256-bit token), but the
frontend has no reason to see it.

**What I did:** rather than add an `except:` list in each controller (easy to forget at the next
endpoint), I overrode `serializable_hash` on `DownloadLink` to drop `token_hash` by default. Now
it's excluded everywhere, including future endpoints. Security-by-default beats
remember-to-exclude.

---

## 7. Frontend & integration

**Process / friction:**
- Created the SvelteKit app non-interactively. The scaffolder hung on Tailwind's interactive
  prompt, so I killed it and went with plain CSS — the dashboard is intentionally minimal per the
  brief ("the dashboard can be minimal"), so pulling in a styling toolchain wasn't worth the time.
- Configured `rack-cors` to let the Svelte dev server (`:5173`) hit the API (`:3000`).

---

## 8. Tests & the bugs they caught

- **`let` vs `let!` with time travel.** A model spec advanced time with `travel 25.hours` *before*
  the record was created under lazy `let`, so the expiry assertion was meaningless. Switching to
  `let!` (persist before the time jump) made the test actually test the thing.
- **Request specs** cover the order flow, both download steps, and the resend guards. I added
  coverage for `orders#index` and the products endpoints (the dashboard reads these on every load)
  and a regression test asserting `token_hash` never appears in serialized output.
- **End-to-end (Playwright)** drives the real purchase → email → download → resend loop across both
  servers. To read the emailed link, the test hits a `test/latest_email` endpoint that is only
  routed in the test environment — a deliberate test-only seam, commented as such so nobody mistakes
  it for production surface.
- **CI** runs RSpec against a real Postgres service container, alongside Brakeman, bundler-audit,
  and RuboCop.

---

## 9. Hardening pass after a full review

After the feature work I did a second review pass and fixed the rougher edges the happy-path
tests had hidden:

- **`reset_download_link!` was not atomic.** It did `destroy!` then create on the new link with no
  transaction — a failure in between would leave an order with no link, and two concurrent resends
  could interleave. I wrapped it in `with_lock` (transaction + row lock) so it's all-or-nothing and
  serialized against other resends/downloads on the same order.
- **Frontend `getProducts`/`getOrders` swallowed HTTP errors.** They returned `res.json()` without
  checking `res.ok`, so a 5xx produced a non-array that blew up the dashboard's `{#each}` instead of
  the error banner. Added `res.ok` guards to match the other client calls.
- **CORS was `origins "*"`.** Harmless today (no auth/cookies) but the wrong default. Locked it to
  `FRONTEND_URL`, the same env var the mailer uses, so there's a single source of truth.
- **Token leaked into request-path logs.** `params[:token]`/`:email` are already filtered, but Rails
  logs the raw path (`Started GET /downloads/<token>`). Couldn't cleanly scrub the path within the
  time box, so I documented it honestly in Known Limitations with the production fix (token out of
  the URL, or a custom log subscriber).
- **Filled the two test gaps the review found:** `downloads#show` now has specs proving it returns
  200 + correct flags for expired and limit-reached links (the deliberate not-a-4xx contract), and
  the resend flow now asserts the count and original expiry are preserved — the invariant from
  section 4 that a naive refactor could silently break.
- **Stopped the e2e suite from polluting the RSpec database.** Writing the new specs surfaced that
  request specs were asserting absolute row counts (`eq(2)`), which broke once the e2e run had
  committed real rows into the shared `api_test` DB — `use_transactional_fixtures` only rolls back
  rows created *inside* an example. Two fixes: (1) scope the request-spec assertions to the records
  each example creates so they don't assume a pristine DB; (2) point the e2e server at its own
  `api_e2e` database (`TEST_DATABASE`) so its committed writes can never reach `api_test`. The
  alternative — a Playwright `globalTeardown` that truncates — is fragile (skipped on a crashed
  run), whereas a separate database needs no teardown at all. Verified: after an e2e run, `api_test`
  still shows 0 orders while `api_e2e` holds the 2 the suite created.

## 10. What I'd do next (didn't fit the time box)

- Add merchant authentication and ownership scoping (the brief allowed assuming a single admin).
- Real file storage: ActiveStorage + S3 with short-lived signed URLs, redirecting instead of
  proxying bytes through Puma (notes in the README).
- Rate-limiting (`rack-attack`) on order creation and download attempts to deter token enumeration.
- Dead-letter handling / buyer notification for permanently failed email delivery.
