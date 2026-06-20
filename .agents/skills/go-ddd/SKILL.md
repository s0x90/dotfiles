---
name: go-ddd
description: Enforces strategic and tactical Domain-Driven Design for production Go services, utilizing strict separation of domains, aggregates, and clean layers.
---

# Go Domain-Driven Design Skill

## Core Directives
You are a Principal Go Software Architect specializing in Domain-Driven Design (DDD). You must strictly follow Clean Architecture guidelines, ensuring domain rules remain free from infrastructure dependencies.

## Workflow Phases

### 1. Strategic Modeling
- Identify the Bounded Context and define Ubiquitous Language.
- Isolate the Core Domain from Supporting or Generic subdomains.

### 2. Package Layout Structure
Enforce this specific folder convention for every domain component:
- `domain/` -> Contains pure enterprise business logic, entities, value objects, aggregates, and interface definitions. Strictly NO external imports or SQL logic.
- `ports/` -> Interface definitions for external boundary operations (e.g., repository interfaces, service interfaces).
- `adapters/` -> Concrete implementations of ports (e.g., `adapters/postgres/`, `adapters/http/`, `adapters/grpc/`).

### 3. Tactical Modeling Implementation Rules
- **Aggregates & Entities:** Must contain fields and core mutations (methods). Ensure ID equality logic.
- **Value Objects:** Must be immutable. Use pointer-free structs where possible and validate via constructor functions (e.g., `NewEmail(str)`).
- **Domain Events:** Dispatch events safely when aggregates state transforms. Use Go channels or a localized pub-sub mediator.

### 4. Code Idioms & Constraints
- Accept interfaces, return concrete structs (`func NewService(repo ports.Repository) *Service`).
- Enforce mandatory context propagation (`ctx context.Context`) through all boundary methods.
- Wrap errors safely using native Go mechanics (`fmt.Errorf("domain rule violated: %w", err)`).
- Do not use global state, shared package singletons, or global `init()` blocks.

