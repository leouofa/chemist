# Chemist REST API (`/api/v1`) Specification & Developer Reference

This document provides a comprehensive technical reference for the programmatic REST API exposed by **Chemist** under `/api/v1`. The API is designed for external applications, researchers, and companion client environments (such as an MCP server or Python computational chemistry scripts) to query, manipulate, and orchestrate the entire chemistry catalog, vector embedding manifold, archetype clustering engine, and multi-stage LLM synthesis pipelines.

---

## 1. Architectural Overview & Conventions

### Base URL
```
http://localhost:3000/api/v1
```

### OpenAPI 3.1 Specification
Chemist serves an introspectable OpenAPI 3.1 JSON document directly at:
```http
GET /api/v1/openapi.json
```

### Response Envelopes
All responses are formatted as JSON using a consistent envelope structure:

#### Single Resource or Action Response
```json
{
  "data": { ... },
  "meta": { ... }
}
```

#### Collection Response (with Pagination)
```json
{
  "data": [ ... ],
  "meta": {
    "total": 42,
    "limit": 50,
    "offset": 0
  }
}
```

#### Error Response
Standard HTTP status codes (`400 Bad Request`, `404 Not Found`, `422 Unprocessable Entity`, etc.) return an error object:
```json
{
  "error": {
    "code": "not_found",
    "message": "Couldn't find Molecule with 'id'=9999",
    "details": ["Optional validation errors or context"]
  }
}
```

### Pagination
Collection endpoints support `limit` (default: `50`, maximum: `500`) and `offset` (default: `0`) query parameters.

### Embedding Vectors (`pgvector` 1024-float arrays)
To keep network payloads lean, endpoints returning `Molecule` or `FunctionalGroup` records include vector metadata (`embedded: boolean`, `embedding_model: string`, `embedded_at: timestamp`, `embedding_dimensions: 1024`), while the raw 1024-float array is omitted by default.
Pass `?include_embedding=true` on any individual or collection query to include the raw vector:
```json
{
  "data": {
    "id": 1,
    "name": "Quinine",
    "embedded": true,
    "embedding_model": "bge-large",
    "embedding": [0.0123, -0.0456, 0.0891, ...]
  }
}
```

### Synchronous vs. Asynchronous Job Execution (`?sync=true`)
Long-running LLM and embedding operations (discovery, population, vector calculation) default to asynchronous execution via ActiveJob/Sidekiq (`202 Accepted` with `{ "data": { "job_id": "...", "status": "queued" } }`).
Clients can:
1. Poll the job status at `GET /api/v1/jobs/:id`.
2. Or pass `?sync=true` on single-entity actions (`POST /api/v1/molecules/:id/generate_embedding?sync=true`, `POST /api/v1/chemical_classes/:id/populate_molecules?sync=true`, `POST /api/v1/molecules/:id/populate_functional_groups?sync=true`) to block until execution completes and receive the immediate result (`200 OK`).

---

## 2. Resource Endpoints

### 2.1 Chemical Classes (`/api/v1/chemical_classes`)

- `GET /api/v1/chemical_classes`: List chemical classes (supports `q`, `limit`, `offset`, `include_molecules`)
- `POST /api/v1/chemical_classes`: Create a new chemical class
- `GET /api/v1/chemical_classes/:id`: Retrieve chemical class by ID
- `PATCH /api/v1/chemical_classes/:id`: Update chemical class
- `DELETE /api/v1/chemical_classes/:id`: Delete chemical class
- `POST /api/v1/chemical_classes/populate`: Trigger automated discovery of major chemical classes
- `POST /api/v1/chemical_classes/:id/populate_molecules`: Discover molecules for a specific chemical class
- `POST /api/v1/chemical_classes/upsert_batch`: Bulk upsert chemical class records

### 2.2 Molecules (`/api/v1/molecules`)

- `GET /api/v1/molecules`: List molecules (supports `chemical_class_id`, `theme`, `q`, `embedded`, `include_embedding`, `include_functional_groups`)
- `POST /api/v1/molecules`: Create a molecule record
- `GET /api/v1/molecules/:id`: Retrieve molecule details
- `PATCH /api/v1/molecules/:id`: Update molecule details
- `DELETE /api/v1/molecules/:id`: Delete a molecule
- `GET /api/v1/molecules/:id/neighbors`: Find nearest cosine-distance molecule neighbors
- `POST /api/v1/molecules/:id/generate_embedding`: Generate or refresh 1024-d embedding vector
- `POST /api/v1/molecules/:id/populate_functional_groups`: Discover functional groups for this molecule
- `POST /api/v1/molecules/populate`: Discover molecules across all chemical classes
- `POST /api/v1/molecules/upsert_batch`: Bulk upsert molecules for a given `chemical_class_id`
- `GET /api/v1/molecules/search`: Semantic vector and keyword search across molecules

### 2.3 Functional Groups (`/api/v1/functional_groups`)

- `GET /api/v1/functional_groups`: List functional groups (supports `molecule_id`, `chemical_class_id`, `theme`, `q`, `embedded`, `include_embedding`)
- `POST /api/v1/functional_groups`: Create a functional group record
- `GET /api/v1/functional_groups/:id`: Retrieve functional group details
- `PATCH /api/v1/functional_groups/:id`: Update functional group details
- `DELETE /api/v1/functional_groups/:id`: Delete a functional group
- `GET /api/v1/functional_groups/:id/neighbors`: Find nearest functional group counterparts
- `POST /api/v1/functional_groups/:id/generate_embedding`: Generate 1024-d embedding vector
- `POST /api/v1/functional_groups/populate`: Discover functional groups across all molecules
- `POST /api/v1/functional_groups/upsert_batch`: Bulk upsert functional groups for a given `molecule_id`
- `GET /api/v1/functional_groups/search`: Semantic vector and keyword search across functional groups

### 2.4 Clustering & Snapshots (`/api/v1/clusters`, `/api/v1/cluster_snapshots`)

- `GET /api/v1/clusters`: Dynamically compute agglomerative clusters for `Molecule` or `FunctionalGroup` across levels 1 to 15 (params: `target`, `level`, `full_coverage`, `force`)
- `GET /api/v1/cluster_snapshots`: List frozen cluster snapshots
- `POST /api/v1/cluster_snapshots`: Compute and persist a frozen cluster snapshot
- `GET /api/v1/cluster_snapshots/:id`: Retrieve snapshot details, clusters, and member records
- `DELETE /api/v1/cluster_snapshots/:id`: Delete snapshot

### 2.5 Multi-Stage AI Synthesis Reports (`/api/v1/cluster_reports`)

- `GET /api/v1/cluster_reports`: List synthesis reports
- `POST /api/v1/cluster_reports`: Run 2-phase Map-Reduce report on a saved snapshot
- `POST /api/v1/cluster_reports/deep_synthesis`: Run 3-phase Hierarchical Deep Synthesis report
- `GET /api/v1/cluster_reports/:id`: Retrieve completed or running report details and synthesis monograph
- `DELETE /api/v1/cluster_reports/:id`: Delete report

### 2.6 Semantic Search & Discovery (`/api/v1/search`)

- `GET /api/v1/search`: Unified cross-entity search endpoint across molecules and functional groups

### 2.7 Platform Status, Jobs & Settings (`/api/v1/status`, `/api/v1/settings`, `/api/v1/jobs`)

- `GET /api/v1/status`: Health check, database connectivity, `pgvector` version, Ollama reachability, counts of chemical classes, molecules, functional groups, and embeddings
- `GET /api/v1/settings`: Current LLM and embedding model configuration, context window sizes, temperature settings
- `PATCH /api/v1/settings/context_window`: Update runtime LLM context window size
- `POST /api/v1/settings/generate_embeddings`: Trigger background embedding generation for all un-embedded records
- `GET /api/v1/jobs`: List background jobs
- `GET /api/v1/jobs/:id`: Retrieve status of a queued or running job
