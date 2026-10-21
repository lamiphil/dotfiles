---
name: deployment-progress-diagram
description: Create or update an auditable current-state deployment-progress diagram for Terraform or cloud infrastructure. Use when a resource has been deployed and its diagram must track real applied state, when bootstrapping a progress diagram from existing deployments, or when reconciling a deployment diagram with a canonical v-devops-infra-arch registry and Draw.io specification.
---

# Deployment-progress diagrams

Maintain a **current-state projection**, separate from the target architecture. The target registry owns canonical component IDs, relationships, icons, names, and semantic styling. The owning infrastructure repository records only the part it has successfully deployed.

## Non-negotiable rules

- Mark a component or relation deployed only after a successful `terraform apply` and state/output verification; for manual resources, require explicit Azure verification.
- Use canonical IDs and relationships from the target registry. Do not invent local IDs, duplicate the registry, or show Terraform implementation details such as resource groups, tags, locks, or state containers.
- Omit undeployed and deferred components. Show another repository's deployed dependency only as labeled read-only context when necessary for an active relation.
- Keep one local manifest and one current-state diagram per infrastructure repository. Git history and MRs are the milestone history; do not store snapshots.
- Add the progress update as a dedicated commit in the same MR as the verified infrastructure apply.

## Discover before changing files

1. Locate the owning infrastructure repository, its current branch/MR, Terraform state/outputs, and the canonical architecture repository.
2. Read the architecture skill and its local conventions from `$V_DEVOPS_INFRA_ARCH_ROOT`. Stop and report the missing variable when it is unset or invalid.
3. Confirm the registry schema and find the deployed component IDs and relationship tuples. If an applied component or relation has no canonical representation, update the **target registry first** (and the target picture that consumes it); do not add a local substitute.
4. Inspect the working trees. Do not stage or overwrite unrelated pending changes.

## Progress artifact layout

Create these artifacts in the owning repository:

```text
docs/deployment-progress/
├── deployment-progress.yaml
├── diagrams/
│   ├── NN-<scope>-deployment-progress.yaml
│   └── NN-<scope>-deployment-progress.drawio   # generated
├── .gitignore
└── README.md
```

Ignore a temporary `registry.yaml` symlink and disposable `output/` reports. Point to the neighboring canonical checkout instead of committing a copy.

### Manifest shape

Use this structure; preserve dates, evidence, and Terraform addresses as an audit trail.

```yaml
schema_version: 1
owner_repository: <repo-name>
architecture_source: ../<architecture-repo>/docs/architecture/registry.yaml

deployed:
  components:
    - id: <canonical-component-id>
      deployed_at: "<ISO-8601 timestamp>"
      terraform_address: <state-address>
      proof: "<output, resource identity, or Azure verification>"
  relations:
    - from: <canonical-source-id>
      to: <canonical-target-id>
      deployed_at: "<ISO-8601 timestamp>"
      terraform_addresses: [<optional-peering-or-connection-addresses>]
      proof: "<verified active path>"
```

Use `terraform_address` for one address and `terraform_addresses` for several. Keep the YAML valid and reference only IDs and directed relations present in the canonical registry.

## Diagram workflow

1. Derive a concise picture from the manifest: only deployed components and active relations.
2. Preserve the registry diagram's information architecture: the same boundary layers, semantic colors, edge kinds, labels, and Azure Architecture Center icons. Use the `v-devops-infra-arch` declarative Draw.io YAML format; do **not** hand-edit Draw.io XML.
3. Use canonical `ref` values for registry components. Nest resources in truthful boundaries. Add a short note for intentionally empty deployed network containers, when useful.
4. Include external contexts only when an active relationship requires them; label them with their owner repository.
5. Execute rendering directly from the skill; do not add a repository wrapper script. For tools that require `registry.yaml` beside `diagrams/`, create a temporary untracked symlink to the local canonical registry, run build, readability validation, and export, then remove the link even if a gate fails.

## Validation and review

Run, in order:

1. YAML parse for manifest and picture spec.
2. Registry schema validation and picture-spec validation from `v-devops-infra-arch`.
3. A manifest check that every deployed component ID and directed relation exists in the canonical registry.
4. Local renderer: require the Draw.io readability gate to report no errors or warnings.
5. If Draw.io CLI is available, export a PNG/SVG and visually inspect it for clipped labels, overlaps, missing edges, edge-through-node paths, and truthful deployment scope. If the CLI is unavailable, retain the generated `.drawio` source and explicitly report that export/visual review is pending; do not claim it was performed.

After a new apply, update the manifest, declarative picture, generated `.drawio`, and any reviewed export in one dedicated progress commit on the same MR.

## Required README content

Document these local rules: current state vs target architecture, proof threshold, canonical-ID requirement, cross-repository context behavior, local-only registry dependency, skill-owned render/validation workflow, and the dedicated-MR-commit rule.
