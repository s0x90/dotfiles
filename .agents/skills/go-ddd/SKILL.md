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
- **Value Objects:**
  - Unexported fields + exported accessor methods (no setters). Immutability is
    enforced by encapsulation, not convention.
  - Construct and validate ONLY via `NewX(...) (X, error)`. Return errors from
    constructors; never panic. Prefer pointer-free structs.
- **Domain Events:**
  - Aggregates RECORD events into an in-memory slice (e.g. `agg.PullEvents()`);
    they do NOT dispatch. Dispatch happens in the application layer AFTER the
    transaction commits, via a **transactional outbox** (persist events in the same
    DB tx as the aggregate, then relay asynchronously).
  - Do NOT use raw Go channels for domain events — they lose events on crash and
    couple the domain to delivery.

### 4. Persistence & Transactions
- An aggregate save MUST be atomic — one transaction covering the aggregate root,
  its children, and the outbox. Define a `UnitOfWork`/`Tx` port in `ports/`;
  adapters wrap all writes in a single DB transaction with `defer rollback` on the
  error path.
- When an aggregate maps to a single document (typical in document stores), the
  atomic single-document update IS the consistency boundary — no multi-document
  `UnitOfWork` is required for that case. A `UnitOfWork`/`Tx` port is still needed
  when a save spans multiple documents/rows or must include the outbox atomically.
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
