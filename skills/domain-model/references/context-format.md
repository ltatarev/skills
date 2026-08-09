# CONTEXT.md format

## Structure

```md
# {Context name}

{One or two sentences: what this context is and why it exists.}

## Language

**Order**:
A customer's request for goods, from placement until it is fulfilled or cancelled.
_Avoid_: Purchase, transaction

**Invoice**:
A request for payment sent to a customer after delivery.
_Avoid_: Bill, payment request

**Customer**:
A person or organization that places orders.
_Avoid_: Client, buyer, account
```

## Rules

- **Be opinionated.** When several words exist for one concept, pick the best
  and list the rest under `_Avoid_`. A glossary that permits synonyms has not
  decided anything.
- **Keep definitions tight.** One or two sentences. Define what the thing *is*,
  not what it does.
- **Only terms specific to this context.** General programming concepts —
  timeouts, retries, adapters, error types — don't belong however heavily the
  project uses them. Test: would a project in a different industry need this
  word to mean this thing?
- **Group under subheadings** when natural clusters appear. A flat list is fine
  while the terms all belong to one cohesive area.
- **No implementation.** No file paths, type names, table names, or library
  names. If an entry would be wrong after a refactor that changed no behavior,
  it does not belong here.

## Single vs multiple contexts

**Single context (most repos):** one `CONTEXT.md` at the repo root.

**Multiple contexts:** a `CONTEXT-MAP.md` at the root lists them, says where
each lives, and describes how they relate:

```md
# Context map

## Contexts

- [Ordering](./src/ordering/CONTEXT.md) — receives and tracks customer orders
- [Billing](./src/billing/CONTEXT.md) — generates invoices and processes payments
- [Fulfillment](./src/fulfillment/CONTEXT.md) — warehouse picking and shipping

## Relationships

- **Ordering → Fulfillment**: Ordering emits `OrderPlaced`; Fulfillment consumes it to start picking
- **Fulfillment → Billing**: Fulfillment emits `ShipmentDispatched`; Billing consumes it to invoice
- **Ordering ↔ Billing**: shared `CustomerId` and `Money` types
```

Which structure applies is inferred, not asked:

- `CONTEXT-MAP.md` exists → read it to find the contexts.
- Only a root `CONTEXT.md` → single context.
- Neither → single context; create the root file lazily, when the first term
  is resolved.

The same word may legitimately mean different things in two contexts — that is
the point of splitting them. Define it in both, and say in the map that they
differ.

## Adding a term mid-session

1. Check whether the concept is already there under another word. If it is,
   the decision is which word wins, not whether to add one.
2. Write the definition, then read it back against the scenario that prompted
   it. If the definition doesn't settle that scenario, it is too vague.
3. Move every rejected synonym to `_Avoid_` on the surviving entry.
