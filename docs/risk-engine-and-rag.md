# Krogan — Risk Engine & RAG

## Orchestration: LangGraph

We use **LangGraph** as the agent orchestrator for the risk pipeline. The flow is modeled as a stateful graph:

- **Nodes:** e.g. receive chunk → transcribe (AssemblyAI) → build turn context → retrieval (Graph RAG) → LLM risk call (Groq) → rule floor (critical phrases, ETA expiry) → persist → guardian state update.
- **Edges:** normal flow + **fast path** when a critical phrase is detected (e.g. skip or shortcut to Overwatch).
- **State:** one object passed between nodes (turn context, transcript, retrieval results, risk output).

This keeps the pipeline explicit, debuggable, and easy to extend (e.g. human-in-the-loop, extra checks).

---

## Retrieval: Graph RAG (not flat vector RAG)

We use **Graph RAG** instead of flat vector-only RAG for the knowledge layer that feeds the risk LLM.

**Why Graph RAG**

- Risk and legal reasoning are **relationship-heavy**: e.g. “coercion” → “boundary violation” → “Title 18 § …”. Graph RAG supports multi-hop reasoning and structured links between entities.
- Our corpus includes **Title 18** (federal crime law) and **prosocial/threat patterns** (coercion, harassment, isolation). Entities and relationships (e.g. statute ↔ behavior) fit a graph model.
- Graph RAG typically reduces hallucinations and improves explainability (we can trace which nodes/edges contributed to context).

**What we need**

- **Graph storage:** entities (e.g. statutes, threat types, example phrases) and relationships. Options: Neo4j, FalkorDB, or a graph model in Postgres — to be chosen when we implement.
- **Ingestion:** from Title 18 + curated threat/prosocial corpus → entity extraction + relationship creation → load into graph.
- **Retrieval at query time:** given turn context (and optionally an embedding), retrieve relevant **subgraph** or **community** (not just top‑k vectors), then attach that structure (or its text summary) to the LLM context.
- **Latest stable** versions for any Graph RAG library or DB we add.

**Pinecone:** We build with **Pinecone** as the vector DB. Embeddings are stored in Pinecone; retrieval (vector similarity + optional hybrid with Graph RAG) feeds the risk LLM. Primary app data (users, sessions, guardians) stays in Postgres/SQLite.

**Not too late:** RAG is not built yet. We can design and implement Graph RAG + Pinecone from the start; no need to migrate from an existing vector-only RAG.

---

## Summary

| Layer           | Choice        | Role |
|----------------|---------------|------|
| Orchestration  | **LangGraph** | Risk pipeline as a stateful graph; fast path for critical phrases. |
| Vector DB      | **Pinecone** | Embeddings and vector retrieval for RAG; hybrid with Graph RAG. |
| Retrieval      | **Graph RAG + Pinecone** | Pinecone for vector candidate selection; Graph RAG (Title 18 + threat/prosocial) for verification/expansion and subgraph context. |
| LLM            | **Groq — Llama 3.1 70B** | Structured risk output (tier, labels, narrative, legal refs). 70B for quality on legal/threat reasoning. |
| Transcription  | AssemblyAI    | Streaming STT. |

We **build with Pinecone** for the RAG/risk layer; primary app data remains in Postgres (or SQLite for local dev).
