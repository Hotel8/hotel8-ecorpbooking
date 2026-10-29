# Hotel8:eCorpBooking - Business Requirements & Functionality

> Audience: product owners, business analysts, and anyone evaluating what
> Hotel8:eCorpBooking **does for the business**. For architecture read
> `README.md`; for wire-level detail read `DESIGN.md`.

## 1. Business Purpose

- Win and retain corporate accounts with a secured, self-service portal for
  negotiated corporate rates - the corporate counterpart to the public
  eBooking channel.
- Enforce travel policy at booking time (rate caps, advance booking,
  approved properties, cost centers) so compliance is structural, not
  aspirational.
- Reduce corporate travel administration: traveler rosters, My Trips, and
  savings/compliance reporting for travel managers.
- Open flexible payment channels - credit card, post-pay (invoice), and
  bill-to-company - matching how corporations actually pay.

## 2. Business Scope (What the Service Provides)

| Capability | Provided by eCorpBooking |
|---|---|
| Corporate login (company code + credentials, SSO) ||
| Company-code verification ||
| Corporate dashboard (quick search, upcoming bookings, announcements) ||
| Corporate search & book (negotiated rates only, policy flags, traveler selection, payment methods) ||
| Traveler management (roster CRUD) ||
| My Trips (upcoming/past, modify/cancel) ||
| Reporting (summary, by-property, by-traveler, by-month) ||
| Company profile + travel policies + cost centers ||
| Announcements feed (via Post) ||
| SSO-free first-admin provisioning |Request Access provisions the first corporate admin (no-IdP companies); idempotent |
| Credit-method surfacing |checkout reads the company's approved credit methods (post-pay / bill-to-company) - approval state is live, not a static flag |
| Traveler company bindings + role roster |`pms.company_users` read/write via the corporate surfaces (profiles carry role-at-company) |
| Corporate `/admin` (branding, codes, rate assignment) |hotel-sales side: PMS admin RFW "Corporate" page (companies roster, credit methods, user bindings, rate links) rendered by Dash |
| Corporate invoicing execution |delegated - Bill8:Ledger (server-side) |
| Expense/TMS export |out of scope |
| Leisure booking |delegated - Hotel8:eBooking |
| Corporate rate negotiation | ⚙ rate links + company-scoped availability implemented; terms entered by hotel sales on the PMS admin surfaces |

## 3. Business Capabilities

### Identity & access

| Capability | Business rule |
|---|---|
| Company-code verification | Registration/login binds to a company only after its code verifies - negotiated rate data can never be seen unbound. |
| SSO | Companies with an identity provider sign in via SSO; others use credentials. |
| Role separation | Travelers book for themselves (or via booking agents); travel managers/admins manage rosters and policies; roles gate management screens. |

### Search & booking

| Capability | Business rule |
|---|---|
| Corporate rates only | Search shows the company's negotiated rates with the public rate shown (strikethrough) for savings context - public-rate-only results never appear. |
| Policy enforcement | Rate caps, advance-booking requirements, and approved-property limits are enforced server-side; out-of-policy choices are flagged (and blocked where policy demands). |
| Traveler selection | A booker can assign the booking to themselves or a roster traveler, with booking permissions honored. |
| Payment methods | Credit card (immediate), post-pay (PO number, invoiced), or bill-to-company, gated by the company's credit-approval state. |
| Booking notes | Project code, cost center, and purpose-of-travel are captured for reporting and accounting. |

### Administration & reporting

| Capability | Business rule |
|---|---|
| Traveler management | Travel managers add/edit/remove roster members and assign permissions. |
| Travel policies | Policies (rate caps, advance booking, approved properties) are read and edited via company policy endpoints; enforcement happens at booking. |
| Reports | Booking volume, spend, savings vs public rates, and compliance rate - broken by property, traveler, and month; CSV export-ready. |
| Announcements | Company announcements surface on the dashboard (delivered via Post). |

## 4. Business Events (Outbound)

eCorpBooking emits no events. Its actions trigger events in Hotel8:PMS
(booking, traveler, policy changes); see `services/pms/DESIGN.md` §4.

| Business moment | Event family (owner) |
|---|---|
| Corporate booking made/modified/cancelled | PMS reservation events (company-scoped) |
| Traveler roster change | PMS CRM events |
| Policy change | PMS CRM events |

**Inbound:** none.

## 5. Business Rules & Invariants

1. All corporate traffic is BFF-proxied and company-scoped; no session can
   see another company's rates, bookings, or reports.
2. A booking always references the company path segment - no company-less
   corporate bookings.
3. Policy compliance is enforced server-side; the UI flags decisions but
   cannot bypass them.
4. Post-pay and bill-to-company require approved credit status; an
   unapproved company cannot select those methods.
5. Negotiated rate data never appears in the public eBooking channel.
6. Money handling: card charges are Bill8 charges; invoicing runs on
   Bill8:Ledger - the app never performs money movement itself.
7. Reports show real aggregates or empty states, never fabricated zeros.

## 6. Target-User Roles & Use Cases

| Persona | What they do with eCorpBooking |
|---|---|
| Corporate traveler | Books corporate rates for own trips in policy; manages my trips. |
| Booking agent | Books on behalf of roster travelers per permissions. |
| Travel manager | Manages the roster, sets/monitors policies, runs reports. |
| Company admin | Manages company profile, cost centers, approved properties. |
| Hotel sales manager | (Service-side) sets up the company, negotiated rates, credit terms. |

## 7. KPIs / Success Criteria

- **Corporate channel share** of total bookings and room nights.
- **Policy compliance rate** - in-policy bookings as a share of attempts.
- **Savings vs public rates** - realized savings per company and traveler.
- **Time-to-portal** - new corporate client from sales approval to first
  booking (target: hours).
- **Self-service share** - bookings made without hotel sales/front-desk
  involvement.

## 8. Dependencies & Reliance on Other Services

| Reliance | For |
|---|---|
| Hotel8:PMS | Companies, negotiated rates, corporate bookings, policies, reports |
| Sentin8:Auth | Corporate login/SSO/company-code verification (via BFF) |
| Sentin8:BFF | Transport, corporate session, company scoping |
| Bill8:Payments | Card payment method execution (via BFF) |
| Bill8:Ledger | Post-pay/bill-to-company invoicing (server-side) |
| Sentin8:Post | Announcements + confirmations |
| Sentin8:App | Listing, runtime context, DCR bootstrap |

## 9. Acceptance Criteria

1. A corporate user registers with a valid company code and logs in (or
   SSOs); an invalid code never binds.
2. Search shows only the company's negotiated rates with savings context;
   public-only results never appear.
3. An out-of-policy booking is flagged (and blocked where policy demands)
   before confirmation.
4. A travel manager can add, edit, and remove roster travelers, and a
   traveler can book for another only if permissions allow.
5. Bookings support credit-card, post-pay (PO), and bill-to-company methods
   according to the company's credit approval.
6. Reports show booking volume, spend, savings, and compliance by property,
   traveler, and month, and export cleanly.
7. All corporate calls are `/proxy/*` and company-scoped - no cross-company
   leak in any trace.

## 10. Open Business Questions

- SSO onboarding for companies without an IdP (first-admin verification).
- Where post-pay/bill-to-company approval state is read from, and how the
  UI communicates pending approvals.
- Multi-company members (one traveler, two employers) - session binding is
  single-company; is role-switching needed?
- Corporate `/admin` division of labor between hotel sales tooling and this
  portal.

---

**Architecture & Design:** hotel8:ecorpbooking and its underlying concepts were designed by [Hamid Jahanzad](https://www.linkedin.com/in/hamidjahanzad/).
