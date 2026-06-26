---
name: go-ddd
description: Enforces strategic and tactical Domain-Driven Design for production Go services with strict layer separation. Use when the user asks to design, structure, or refactor a Go service using DDD, Clean/Hexagonal Architecture, aggregates, or bounded contexts.
---

# Go Domain-Driven Design Skill

## Core Directives
You are a Principal Go Software Architect specializing in Domain-Driven Design (DDD). You must strictly follow Clean Architecture guidelines, ensuring domain rules remain free from infrastructure dependencies.

## Workflow Phases

### 1. Strategic Modeling
- Identify the Bounded Context and define the Ubiquitous Language.
- Isolate the Core Domain from Supporting or Generic subdomains.
- **Produce artifacts:** a short context map and a ubiquitous-language glossary
  (e.g. in `domain/doc.go`). A phase with no output is a phase that gets skipped.
- **Context mapping:** name the relationship for each external integration
  (Anti-Corruption Layer, Conformist, Shared Kernel, Published Language). Default to an
  **Anti-Corruption Layer** — an adapter that translates the external model into your
  domain model so no foreign model leaks past the boundary.

### 2. Package Layout Structure
Enforce this specific folder convention for every domain component:
- `domain/` -> Pure business logic: entities, value objects, aggregates, domain
  services, and **domain errors** (typed/sentinel). Strictly NO external imports,
  NO SQL, NO outbound-infra interfaces.
- `ports/` -> **The single home for all boundary interfaces** (repositories,
  gateways, publishers, unit-of-work). Domain depends on ports; never the reverse.
  Do NOT also declare these interfaces in `domain/`.
- `adapters/` -> Concrete implementations of ports (e.g., `adapters/postgres/`,
  `adapters/http/`, `adapters/grpc/`).
- `app/` (application services) -> Orchestrates use cases: loads aggregates via
  ports, invokes domain methods, manages transactions, dispatches events.

### 3. Tactical Modeling Implementation Rules
- **Aggregates & Entities:**
  - Contain fields and core mutations (methods) that enforce invariants.
  - **Boundaries:** Reference other aggregates by ID only (`CustomerID`), never by
    embedded pointer/struct. One transaction modifies exactly ONE aggregate;
    cross-aggregate consistency is achieved eventually via domain events, not shared
    transactions. Keep aggregates as small as the invariants they must enforce.
  - **Identity:** Entities equal by stable ID; Value Objects equal by all field
    values. State which rule each type uses.
  - **Concurrency (optimistic locking):** Aggregate roots carry a `version` field.
    Every persist is a conditional write guarded by the expected version; a no-op
    write means a concurrency conflict -> return a typed `ErrConcurrencyConflict`.
    Never last-write-wins. The pattern is storage-agnostic:
    - Relational: `UPDATE ... SET ..., version = version + 1 WHERE id=? AND version=?`;
      conflict when 0 rows affected.
    - Document (e.g. MongoDB): `updateOne({_id, version}, {$set:{...}, $inc:{version:1}})`;
      conflict when `matchedCount == 0`.
    - A no-op write means EITHER a version conflict OR the aggregate was deleted.
      Disambiguate by re-reading by ID: found with a different version ->
      `ErrConcurrencyConflict` (retry); not found -> `ErrNotFound` (do NOT retry).
      Never assume 0 rows == conflict.
    - On `ErrConcurrencyConflict` the application service RETRIES the use case (reload
      aggregate, re-apply command, re-save) — bounded attempts (e.g. 3) with small
      backoff; surface the conflict only after retries are exhausted. Command handlers
      must be safe to re-run (no external side effects before commit).
    - **Creation idempotency:** New aggregates start at version 1. Enforce a UNIQUE
      constraint on aggregate ID / natural key (or an idempotency key) so concurrent
      creates and client retries cannot duplicate. A duplicate-key error on insert ->
      return the existing aggregate or a typed `ErrAlreadyExists`.
- **Value Objects:**
  - Unexported fields + exported accessor methods (no setters). Immutability is
    enforced by encapsulation, not convention.
  - Construct and validate ONLY via `NewX(...) (X, error)`. Return errors from
    constructors; never panic. Prefer pointer-free structs.
  - **Persistence mapping:** Unexported fields DO NOT marshal via encoding/json, BSON,
    or row scanning — they serialize to empty/zero values silently. Adapters MUST map
    domain<->a persistence DTO (a struct with exported fields, living in the adapter),
    or implement custom (Un)MarshalBSON/JSON. NEVER persist a domain aggregate directly;
    this also keeps the storage schema decoupled from the domain model.
  - **Canonical shape** (apply the same pattern to aggregate roots — add `version` and
    `PullEvents()` — and define ports as interfaces in `ports/`):

    ```go
    type Email struct{ value string }              // unexported field == immutable
    func NewEmail(s string) (Email, error) {       // validate in constructor
        if !isValidEmail(s) {
            return Email{}, fmt.Errorf("%w: %q", ErrInvalidEmail, s)
        }
        return Email{value: s}, nil
    }
    func (e Email) String() string { return e.value } // accessor, never a setter
    ```
- **Domain Events:**
  - Aggregates RECORD events into an in-memory slice (e.g. `agg.PullEvents()`);
    they do NOT dispatch. Dispatch happens in the application layer AFTER the
    transaction commits, via a **transactional outbox** (persist events in the same
    DB tx as the aggregate, then relay asynchronously).
  - Do NOT use raw Go channels for domain events — they lose events on crash and
    couple the domain to delivery.
  - Delivery is AT-LEAST-ONCE. Every event carries a stable unique ID and a
    correlation/trace ID; consumers MUST be idempotent (dedup by event ID, or use
    upserts). Never assume exactly-once delivery.
  - Events carry an `OccurredAt` timestamp (UTC). Inject a `Clock` port (interface with
    `Now()`) into domain services/aggregates rather than calling `time.Now()` directly —
    keeps the domain deterministic and unit-testable.

### 4. Persistence & Transactions
- An aggregate save MUST be atomic — one transaction covering the aggregate root,
  its children, and the outbox. Define a `UnitOfWork`/`Tx` port in `ports/`;
  adapters wrap all writes in a single DB transaction with `defer rollback` on the
  error path.
- When an aggregate maps to a single document (typical in document stores), the
  atomic single-document update IS the consistency boundary — no multi-document
  `UnitOfWork` is required for that case. A `UnitOfWork`/`Tx` port is still needed
  when a save spans multiple documents/rows or must include the outbox atomically.
- The "single document = no UnitOfWork" shortcut applies ONLY to aggregates that emit
  no events. If an aggregate emits domain events, the outbox write MUST be atomic with
  the aggregate write — embed events in the aggregate document, or use a multi-document
  transaction. NEVER write the aggregate and its outbox in separate operations.
- Load aggregates with bounded queries; never one round-trip per child (no N+1).
- Adapters TRANSLATE infra errors at the boundary (map `pgx.ErrNoRows` ->
  `domain.ErrNotFound`) and never leak driver errors upward.

### 5. Code Idioms & Constraints
- Default to accepting interfaces and returning concrete types
  (`func NewService(repo ports.Repository) *Service`). Exception: factory/wiring
  functions may return a port interface when that's the consumer's contract.
- `ctx context.Context` is REQUIRED on all PORT, ADAPTER, and application-service
  methods (I/O boundaries). Pure domain/aggregate methods take NO ctx —
  cancellation and deadlines are infrastructure concerns and must not enter the domain.
- Define typed/sentinel domain errors in `domain/`. Use `fmt.Errorf("...: %w", err)`
  only to wrap within a layer; never wrap-and-bubble an infra error past a port boundary.
- Validate all external input at the value-object boundary; never build SQL by string
  concatenation in adapters — use parameterized queries.
- Do not use global state, shared package singletons, or global `init()` blocks.

### 6. Testing
The ports exist to be tested against — close the loop.
- **Domain / aggregates:** pure unit tests, NO mocks, NO I/O. Construct via constructors,
  invoke mutations, assert invariants and every error branch.
- **Application services:** test against in-memory FAKE implementations of ports (real
  working fakes, not mocks), including the conflict/not-found/already-exists paths.
- **Adapters:** integration/contract tests against the real backing store (e.g.
  testcontainers), covering the optimistic-locking and uniqueness-constraint behavior.
- Inject the `Clock` port in tests for deterministic time. Every invariant and every
  typed domain error (`ErrConcurrencyConflict`, `ErrNotFound`, `ErrAlreadyExists`) gets
  a test.
