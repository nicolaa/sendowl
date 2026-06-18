# SendOwl Expiring Download Links (Code Test)

This project is a simplified version of SendOwl's digital product delivery system. It generates expiring, 
limited-count download links upon purchase and provides a SvelteKit dashboard to view products and activity.

## Architecture & Tech Stack

- **Backend:** Ruby on Rails (API mode) + PostgreSQL
- **Frontend:** SvelteKit (TypeScript)
- **Testing:** RSpec (Backend)
- **Email Simulation:** `letter_opener`

## Setup Instructions

### Prerequisites
- Ruby 3.1+ 
- Node.js 18+
- PostgreSQL server running locally

### 1. Backend Setup
```bash
cd api
bundle install
rails db:create db:migrate db:seed
```

### 2. Frontend Setup
```bash
cd frontend
npm install
```

## Running the App

Start the Rails API on port 3000:
```bash
cd api
rails server
```

Start the SvelteKit frontend on port 5173:
```bash
cd frontend
npm run dev -- --open
```

## Running Tests

### Backend Unit Tests (RSpec)
Runs fast, isolated tests for the Rails API (models, controllers, mailers).
```bash
cd api
bundle exec rspec
```

### Full-Stack End-to-End Tests (Playwright)
Runs cross-stack E2E tests against the UI using a headless Chromium browser.
```bash
cd frontend
npm run test:e2e
```
**No manual setup needed:** the Playwright config (`playwright.config.ts`) boots its own Rails
server on port 3001 and SvelteKit server on port 5174, so you don't start anything yourself.

**Database isolation:** because the e2e suite drives a real server, its writes are committed (no
transactional rollback). To keep those rows out of the `api_test` database that RSpec uses, the
e2e server runs against a **separate `api_e2e` database** (via `TEST_DATABASE=api_e2e`, see
`config/database.yml`). It is created and reset automatically on each run, so RSpec and the e2e
suite never contaminate each other regardless of the order you run them in.

## Linting & Code Style

The backend is linted with **RuboCop** using the [`rubocop-rails-omakase`](https://github.com/rails/rubocop-rails-omakase)
ruleset — the same opinionated, low-bikeshedding style Rails ships with by default. The config is
in `api/.rubocop.yml`; house-style overrides can be added there on top of the inherited gem.

```bash
cd api
bin/rubocop          # report offenses
bin/rubocop -A       # safe-autocorrect what it can
```

The CI `lint` job runs `bin/rubocop -f github` on every push and pull request, so style is enforced
rather than advisory — a violation fails the build. Most offenses are auto-correctable, so the
typical workflow is to run `bin/rubocop -A` before committing.

> Note: the frontend is not yet linted. Adding ESLint + Prettier (and a matching CI job) is listed
> under Known Limitations.

## Key Decisions & Production Considerations

### Concurrent Downloads (Race Conditions)
When a user clicks a download link, we check if `download_count >= max_download_count`. To prevent race conditions 
where 5 concurrent requests all pass the check and increment the count past the limit, we use pessimistic 
locking (`with_lock` in `DownloadLink#increment_download!`). This acquires a row-level lock in PostgreSQL 
(`SELECT FOR UPDATE`), forcing concurrent requests to wait and re-evaluate the condition sequentially.

### Cryptographic Hashing for Tokens
Tokens are generated using `SecureRandom.urlsafe_base64(32)` to create a 43-character string. Before saving to the database, they are hashed using **SHA-256**. This ensures that even if the database is fully compromised, an attacker cannot extract active download URLs. 

Because hashing is a one-way function, historical tokens are unrecoverable. The dashboard's "Resend Link" button therefore generates a **brand new token** rather than re-sending the old one.

### Resend Behavior (Deliberate Design)
"Resend Link" is intentionally **not** a recovery tool for dead links — it is a way to re-deliver a link that is still valid (e.g. the buyer deleted the email). Two rules enforce this:

1. **Resend is rejected for expired or limit-reached links** (`OrdersController#resend_link`). Allowing a new token on an expired link would let a buyer bypass expiry indefinitely, defeating the entire point of an expiring link. The dashboard mirrors this by disabling the button in those states.
2. **The new link preserves the original expiry window.** `generate_download_link` anchors `expires_at` to the order's `created_at`, not `Time.current`. This means resending does not extend the clock — a 24h link created 20 hours ago still expires 4 hours from now after a resend. The download *count* is carried over for the same reason, so resending cannot reset a buyer's remaining downloads.

Together these guarantee that resend can re-deliver an active link but can never resurrect, extend, or refresh an exhausted one.

### Buyer Experience for Expired / Exhausted Links
To prevent frustrating the buyer by immediately returning a raw JSON error or a generic 403 page when they click the email link, we implemented a decoupled two-step flow:
1. **Info (GET):** The email link navigates the user to a polished SvelteKit landing page (`/download/[token]`) which fetches the link's status. If the link is expired or the download limit is reached, the UI renders a friendly, styled alert explaining exactly why they cannot download the file. 
2. **Trigger (POST):** If the user is on the page and the link is active, they see a "Download Now" button. If they click it, but the limit was reached *concurrently* (e.g. they had multiple tabs open), the API rejects the `POST` request and the UI surfaces the error dynamically.

### Handling Large Files
File uploads are currently stubbed using `file_placeholder` URLs. In production:
1. **Storage:** Use ActiveStorage configured with Amazon S3.
2. **Delivery:** Instead of proxying the file through Rails (which ties up Puma threads and memory), the `/downloads/:token` endpoint would generate a temporary, signed AWS S3 / CloudFront URL and redirect the user (`redirect_to @product.file.url(expires_in: 5.minutes)`).
3. **Private Storage:** The S3 bucket would be private, accessible only via these short-lived signed URLs.

### Background Jobs & Email Delivery
Emails are enqueued using `#deliver_later`. Rails natively abstracts both the queuing and email delivery mechanisms, ensuring the application is production-ready out-of-the-box:
1. **Queuing (ActiveJob):** In development, ActiveJob uses the `:async` adapter (an in-memory thread pool). In production, Rails 8 is already pre-configured (`config/environments/production.rb`) to use **SolidQueue** (`config.active_job.queue_adapter = :solid_queue`) backed by PostgreSQL, preventing email delivery from blocking web requests.
2. **Delivery (ActionMailer):** In development, ActionMailer is configured to use `letter_opener` to preview emails locally. In production, it defaults to SMTP. You simply need to uncomment the `smtp_settings` block and provide your SendGrid/Mailgun credentials.

## Known Limitations

These are conscious tradeoffs given the time box, not oversights:

- **No authentication.** Per the brief, a single implicit merchant/admin is assumed. The dashboard and all `/api/v1` endpoints are unauthenticated and unauthorized — anyone who can reach the API can create products/orders or trigger resends. Production would need merchant auth (e.g. Devise/JWT) and ownership scoping on every query.
- **Files are stubbed.** `Product#file_placeholder` is just a URL string; there is no real upload or private storage. See "Handling Large Files" above for the intended ActiveStorage + signed-S3-URL approach.
- **Scrubbing the download token from request-path logs (nice-to-have).** Tokens are stored only as SHA-256 hashes, so the database is never the weak point — that one-way hashing is the protection that actually matters, and a DB compromise still yields no usable links. On top of that, `params[:token]` and `:email` are already redacted from the `Parameters:` log line (`config/initializers/filter_parameter_logging.rb`). The remaining gap is that Rails logs the raw request path (`Started GET /api/v1/downloads/<token>`), so the token can appear in application logs. This is low priority — it only matters to someone who already has log access, and the at-rest data is hashed regardless — but to fully close it you'd keep the token out of the URL (header or POST body) or strip it with a custom log subscriber.
- **`:async` ActiveJob adapter in dev.** Enqueued mailer jobs live in an in-memory thread pool and are lost on process restart. Production uses SolidQueue (already configured) which is durable.
- **Email delivery is fire-and-forget.** A failed `deliver_later` is retried by ActiveJob but there is no dead-letter handling or buyer-facing notification if delivery permanently fails.
- **No rate limiting on link generation or download attempts.** An abusive client could enumerate tokens or spam order creation. Production would add throttling (e.g. `rack-attack`).
- **Frontend is not linted or type-checked in CI.** The backend has RuboCop (see "Linting & Code Style"), but the SvelteKit app has no ESLint/Prettier config and `svelte-check` isn't run in CI. The frontend also leans on `any` types in a few places. Next step: add ESLint + Prettier, wire `svelte-check` into the e2e job, and tighten the types.
