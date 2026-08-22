# Graph engineering follow-up points

Source: [Graph Engineering: Connecting Code, Agents, and Evidence Without Building a New Graph Database](https://joeywang.github.io/posts/graph-engineering-agents-and-evidence/)

## Strong points to reuse

1. **Graph engineering is not the same as adopting a graph database.** It is a way to make important entities, relationships, provenance, and transitions explicit while keeping existing systems of record.
2. **Different knowledge layers have different authority.** Git-backed Markdown, durable memory, QMD, code intelligence, and live systems can be connected without pretending they are interchangeable sources of truth.
3. **The useful output is an impact packet.** For a proposed change, it should identify affected contracts, repositories, clients, tests, operational checks, and approval boundaries.
4. **Relationship provenance matters.** A relationship extracted from source code is different from one inferred by a model or manually asserted in a workflow manifest.
5. **Graphs support discovery; verification remains deterministic.** Tests, diffs, builds, browser checks, and live read-backs still decide whether a change is safe.
6. **Start with one painful boundary.** A cross-service API, client integration, deployment path, long-running agent task, or research-to-content workflow is a better pilot than a universal ontology.
7. **Safety boundaries are part of the design.** Do not put credentials or customer data into relationship manifests, and do not let unattended graph processes rewrite skills, production configuration, or memory.

## Follow-up content plan

- Write a practical “impact packet” tutorial using one small cross-repository contract.
- Create a comparison/checklist post: Markdown knowledge, QMD, code graphs, and live verification.
- Turn the provenance point into a short X thread and LinkedIn carousel outline.
- Add a worked example showing predicted impact versus focused-test results.
- Keep social publishing manual until the copy and URLs are reviewed.
