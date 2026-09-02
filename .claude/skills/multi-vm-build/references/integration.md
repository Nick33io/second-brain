# Assembly playbook — turning four lanes into one product

Read this at the start of Phase 5. The merge is the easy part; the craft is in
the seam layer and in *where* you fix what doesn't fit.

## 1. Pre-merge audit

Before merging anything, run `scripts/integrate.sh status` and require:

- every lane branch is clean (no drift outside its folder),
- every lane builds and passes its own tests standalone — check out each
  `origin/lane/<name>` and run the lane's build/test commands from its brief,
- every provided interface matches `contracts/` (spot-check names and shapes).

A lane that fails its own audit goes back to its worker. Never "fix it during
assembly" — assembly-time fixes inside lane folders are invisible to the lane's
owner and rot immediately.

## 2. Merge

```bash
scripts/integrate.sh merge          # → integration/build
```

Disjoint folders merge without conflict. If you get a conflict anyway, a lane
drifted — abort (`git merge --abort`), find it with `status`, and have the lane
fix itself first.

## 3. The seam layer

The lanes are libraries; the product is the small program that composes them.
Write the seam layer yourself (orchestrator-owned), in `product/` or at the
repo root — never inside a lane folder:

- imports/mounts each lane per the contracts (e.g. the server mounts the api
  lane's router, serves the ui lane's build output, runs the data lane's
  migrations, using the infra lane's scripts),
- carries the top-level config: ports, paths, env — things no single lane
  could own,
- stays thin. If the seam layer grows real logic, that logic belonged in a
  lane; move it there in a follow-up, don't grow a fifth unowned lane.

## 4. When pieces don't fit

Diagnose which of exactly three things is wrong, and fix it in its home:

| Symptom | Root cause | Fix where |
|---|---|---|
| Two lanes disagree but each matches `contracts/` | The contract was ambiguous or wrong | Fix `contracts/`, then each affected lane updates itself |
| A lane doesn't match `contracts/` | Lane bug | That lane's folder (its worker if still active, else you — commit to its `lane/*` branch so history stays honest) |
| Both match, product still misbehaves | Missing glue | Seam layer |

Resist fixing a contract mismatch by adapting to it in the seam layer — an
adapter that translates a lane's "almost right" output into the contract shape
means the product now depends on the mistake.

## 5. Verify done

- Fresh clone of the integration branch → one documented command builds and
  runs the whole product.
- Each lane's own tests still pass inside the merged tree.
- At least one end-to-end test crosses every seam (e.g. ui → api → data on
  infra's runtime). Pieces that were only ever tested alone haven't been
  proven to be a product yet.
- Then merge `integration/build` to the base branch (or open the PR the user
  asked for), and retire or reset the worker VMs.

## Running the loop again

For iteration 2 the repo already has lanes and contracts: update `contracts/`
first for whatever the next feature changes, re-brief the workers with deltas,
and reuse the same branches (workers merge the updated base in). The cockpit,
guards, and this playbook are unchanged.
