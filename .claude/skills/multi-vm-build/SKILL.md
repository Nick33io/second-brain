---
name: multi-vm-build
description: >
  Orchestrate a parallel build across 4 worker VMs shown on one screen. The host
  machine provisions the VMs (or containers/worktrees as fallback), splits a
  product into 4 independent lanes with contracts defined up front, gives each
  worker its own folder in the repo to write and push to GitHub, and then an
  orchestrator/engineer pieces the lanes together into a working product. Use
  this skill whenever the user wants to develop with multiple VMs, split a build
  across parallel workers or machines, SSH into a fleet of workers from one
  screen, run "4 agents at once", assign separate folders to separate coders, or
  assemble independently built pieces into one product — even if they don't say
  the word "VM".
---

# Multi-VM Build

One host, four workers, one screen. Each worker builds a self-contained lane of
the product in its own folder and pushes it to GitHub on its own branch. The
orchestrator (you, on the host) defines the contracts before anyone writes code,
watches all four from a single cockpit, and does the final assembly.

The whole method rests on one idea: **the puzzle pieces only fit if the seams
were drawn first.** Parallelism buys nothing if the workers have to guess each
other's interfaces. So the orchestrator's real job happens in Phase 1
(contracts) and Phase 5 (assembly); everything in between is supervision.

## The phases

```
Phase 0  Topology     — pick VMs / containers / worktrees; pick the screen layout
Phase 1  Partition    — split the product into 4 lanes; write contracts/
Phase 2  Cockpit      — provision workers, bring all 4 onto one screen
Phase 3  Brief        — hand each worker its brief, folder, branch, and guard
Phase 4  Build        — workers code, commit, push; orchestrator supervises
Phase 5  Assemble     — merge the lanes, wire the seams, build, test, ship
```

## Phase 0 — Topology

Decide two things: what the workers run on, and how they appear on screen.
Read `references/virtualization.md` for the per-OS options (macOS: Tart, UTM,
Multipass; Linux: Multipass, KVM; cloud VMs; and the no-hypervisor fallbacks).
Summary of the decision:

- **Real VMs + SSH** when the user asked for VMs, needs OS isolation, or the
  workers run untrusted/heavy toolchains. Host stays clean; workers are
  disposable.
- **Containers** when the workers just need isolated toolchains, not a kernel.
- **Git worktrees on the host** when the machine can't virtualize or the user
  wants the workflow without the infrastructure. Same lanes, same contracts,
  same assembly — only the isolation is weaker.

For the screen: the default cockpit is a tmux 2×2 grid — one pane per worker,
each pane an SSH session (or a shell in the worker's directory). It works over
any terminal and survives disconnects. On a large display the alternative is
four terminal windows tiled by the OS window manager; prefer tmux unless the
user explicitly wants separate windows, because tmux gives you synchronized
input, scriptable panes, and a fifth status window for free.

## Phase 1 — Partition and contracts

This phase decides whether assembly is an afternoon or a rewrite. Do it
carefully, on the host, before any worker starts.

1. **Split the product into 4 lanes** that are independent in the build sense:
   no lane imports another lane's code directly; lanes touch each other only
   through the contracts. Good splits follow natural seams — e.g. for a web
   product: `api`, `ui`, `data` (schema/migrations/seeds), `infra`
   (build/deploy/CI); for a game: `engine`, `world`, `ui`, `audio-assets`.
   If the product doesn't split into 4 real lanes, use fewer workers — an
   artificial lane produces an artificial piece that fits nothing.
2. **Write the contracts** into `contracts/` at the repo root: API shapes,
   shared types, file formats, directory conventions, naming. Every symbol two
   lanes both touch must be defined here, by you, before Phase 3. Workers may
   read `contracts/` and must never edit it; a needed change is a message to
   the orchestrator, who edits and tells all affected lanes.
3. **Lay out the repo**:

```
repo/
├── contracts/            orchestrator-owned; read-only for workers
├── workstreams/
│   ├── <lane-1>/         worker 1 writes ONLY here
│   ├── <lane-2>/         worker 2 writes ONLY here
│   ├── <lane-3>/         worker 3 writes ONLY here
│   └── <lane-4>/         worker 4 writes ONLY here
└── product/              created in Phase 5 by the orchestrator (or assembly
                          happens at the root — see references/integration.md)
```

Each lane must build and test **on its own** inside its folder (its own
package.json / Makefile / etc., depending only on `contracts/`). That's what
makes the pieces verifiable before assembly.

## Phase 2 — Cockpit

Provision the four workers (per Phase 0 choice), then bring them onto one
screen:

```bash
scripts/cockpit.sh <session-name> "<cmd1>" "<cmd2>" "<cmd3>" "<cmd4>"
# e.g. real VMs:
scripts/cockpit.sh build ssh vm1 ssh vm2 ssh vm3 ssh vm4
# e.g. worktree fallback:
scripts/cockpit.sh build "cd wt/api && $SHELL" "cd wt/ui && $SHELL" ...
```

This creates a tmux session with a 2×2 grid (one worker per pane, titled) plus
a `control` window for the orchestrator. Useful cockpit moves:
`Ctrl-b q <n>` jump to pane n; `setw synchronize-panes on` to type into all
four at once (git pull, env setup); `Ctrl-b z` to zoom one worker full-screen.

Each worker needs: git configured, a clone of the repo, credentials to push its
own branch, and its toolchain. With real VMs, do this once and snapshot the VM
so workers are cheap to reset.

## Phase 3 — Brief the workers

For each lane, fill in `assets/worker-brief.md` and give it to the worker (a
person, a Claude session, or `claude` running inside the VM). The brief names
the one folder it may write, the branch it pushes, the contracts it must obey,
and its definition of done. Don't paraphrase the template from memory — copy
it and fill it in, so no worker starts without knowing its boundary.

Branch and push convention — each worker stays in its own lane end to end:

- Worker N works on branch `lane/<lane-name>`, only touches
  `workstreams/<lane-name>/`, and pushes with
  `git push -u origin lane/<lane-name>`.
- Separate branches (not four workers on one branch) so pushes never race;
  the folders keep the *content* separate, the branches keep the *history*
  separate. GitHub ends up with one branch per lane, each containing changes
  in exactly one folder.

Install the guard in each worker's clone so the boundary is mechanical, not
aspirational:

```bash
scripts/lane-guard.sh install workstreams/<lane-name>
```

This adds a pre-commit hook that rejects any commit touching files outside the
lane's folder (contracts/ is readable but a diff there fails the commit).

## Phase 4 — Build

Workers work; the orchestrator supervises from the cockpit and the `control`
window:

- `scripts/integrate.sh status` shows every `lane/*` branch: latest commit,
  whether its folder builds, and whether it drifted outside its folder.
- When a worker hits a contract problem, the orchestrator updates `contracts/`
  on `main`, and all workers pull. That is the only cross-lane communication
  channel — workers never coordinate pairwise, because pairwise agreements are
  invisible to the other two lanes and to the assembler.
- A worker finishing early gets hardening work inside its own lane (tests,
  docs, edge cases), not a reassignment into someone else's folder.

## Phase 5 — Assemble

The orchestrator (or the engineer doing final integration) turns four folders
into one product. Read `references/integration.md` before starting — it covers
merge order, seam wiring, and what to do when pieces don't fit. The short
version:

```bash
scripts/integrate.sh merge        # octopus-merge all lane/* into integration/build
# then: wire the seams, build the whole, run the whole, fix at the seams
```

Merging is trivial by construction (disjoint folders can't conflict); the real
work is the seam layer — the small amount of top-level code that imports each
lane and composes them per the contracts. Keep seam code in `product/` (or the
repo root), owned by the orchestrator, and fix integration bugs *at the seam or
in the contract*, only dipping into a lane's folder when the lane demonstrably
violated its contract.

Done means: the assembled product builds and runs from a fresh clone of the
integration branch, each lane's own tests still pass, and the seam layer has at
least one end-to-end test proving the pieces actually talk to each other.

## Bundled resources

| File | When to read/use |
|---|---|
| `references/virtualization.md` | Phase 0 — choosing and provisioning VMs per host OS, SSH setup, screen layouts |
| `references/integration.md` | Phase 5 — the assembly playbook |
| `scripts/cockpit.sh` | Phase 2 — build the one-screen tmux cockpit |
| `scripts/lane-guard.sh` | Phase 3 — enforce folder boundaries per worker |
| `scripts/integrate.sh` | Phases 4–5 — lane status and the integration merge |
| `assets/worker-brief.md` | Phase 3 — template for each worker's assignment |
