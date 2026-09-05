---
name: refine_doc
description: Refine existing project documentation while preserving its outline and meaningful bullet hierarchy. Use when asked to polish grammar, wording, concision, or keyword definitions and nested bullet formatting.
---

# Refine Doc

Refine the requested document in place using these rules:

- Preserve the existing outline, heading hierarchy, and section order. Do not add, remove, merge, split, or reorder sections unless the user explicitly asks.
- Fix grammar, spelling, and punctuation while preserving intentional sentence fragments in bullets. Read parent and child bullets together; do not force each bullet into a standalone sentence. Keep headings and keyword labels concise.
- Improve wording and keep phrasing concise. Remove unnecessary repetition while preserving meaning and technical accuracy.
- Preserve and use nested bullets to show relationships within a sentence or idea. Put shared context or conditions in a parent bullet, components or statements in child bullets, and consequences or supporting details in deeper bullets. Do not flatten meaningful nesting into standalone sentences or repeat shared context in every child.
- Replace large blocks of prose with focused bullet points under existing headings. Each bullet should express one component of the idea; it may be a phrase or a complete sentence. Use punctuation that fits the combined thought rather than adding a period to every fragment.
- Format keywords and technical terms with inline backticks, such as `keyword`.
- For a keyword definition, place the term in backticks in a parent bullet and its concise definition in a nested bullet. The definition may be a fragment. Use bold selectively to emphasize key participants, actions, or relationships within the definition.
- Preserve commands, code blocks, links, and factual details. Do not invent missing information or change technical behavior when polishing prose.

Follow this pattern for related statements:

- By default,
  - `etcd` communicates in plain text
    - can be captured with `tcpdump`.
  - Authentication is not required
    - anyone with access to the endpoint can query the `etcd` database.
- With `mutual TLS` (`mTLS`),
  - both the client and server present certificates to authenticate each other.
  - `TLS` encryption protects traffic in transit.

Follow this pattern for keyword definitions:

- `Mutual TLS (mTLS)`
  - a security protocol in which the **client** and **server** **verify each other's identities** using digital certificates before data flows.

Before finishing, review the changes to confirm that the outline and meaningful bullet relationships are preserved, the wording retains its original meaning, and the requested formatting is consistent.
