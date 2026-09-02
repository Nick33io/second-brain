# Virtualization strategy — provisioning the four workers

The workflow is topology-agnostic: lanes, contracts, branches, and assembly are
identical whether the workers are real VMs, containers, or worktrees. Pick the
lightest topology that satisfies the isolation the user actually needs.

## Decision ladder

| Need | Topology |
|---|---|
| OS-level isolation, disposable machines, "real VMs" requested | VMs + SSH |
| Isolated toolchains, fast reset, no kernel needed | Containers |
| Just the parallel workflow on one machine | Git worktrees |
| Workers are remote/cloud (big builds, GPU, always-on) | Cloud VMs + SSH |

Four workers per host is the sweet spot for a 2×2 screen; give each VM
2-4 vCPUs and 4-8 GB RAM and check the host has headroom for itself.

## macOS host

- **Tart** (Apple Silicon, lightest for macOS/Linux guests):
  `brew install cirruslabs/cli/tart`, then
  `tart clone ghcr.io/cirruslabs/ubuntu:latest worker1 && tart run --no-graphics worker1 &`
  and `ssh admin@$(tart ip worker1)`. Clone one configured "golden" VM four
  times — configuration happens once.
- **Multipass** (simplest CLI Ubuntu VMs):
  `multipass launch -n worker1 -c 4 -m 6G`, then `multipass shell worker1`
  or enable SSH. `multipass list` gives IPs.
- **UTM** when the user wants visible VM windows (each VM's display in its own
  window on the big monitor) instead of SSH panes.

## Linux host

- **Multipass** works identically to macOS.
- **KVM/libvirt** (`virt-install`/`virt-manager`) for full control; use
  `virsh domifaddr worker1` for the IP, SSH in as usual.

## Multiple physical Macs (preferred when available)

With 2-3 Macs the fleet spreads out and each worker gets real cores; the
cockpit doesn't change, since panes are just SSH commands. Recommended split
for 3 Macs: strongest Mac is the host (cockpit + orchestrator) and runs 2
worker VMs; the other two Macs carry one worker each — bare metal over SSH
(System Settings → General → Sharing → Remote Login) to start, or a single
VM per Mac when disposable/resettable workers are worth the setup.

Note Apple's licensing/framework limit: at most **2 concurrent macOS guest
VMs per Apple Silicon host**. One Mac cannot run 4 macOS VMs — use Linux
guests for extra workers, or spread macOS VMs across Macs (3 Macs → up to 6
macOS VMs, useful when lanes need Xcode). Linux guests have no such limit.

Connect the Macs with Tailscale or plain LAN `.local` hostnames, add them to
`~/.ssh/config`, and mix freely:

```bash
scripts/cockpit.sh build "ssh vm1" "ssh vm2" "ssh mac2" "ssh mac3"
```

## Containers (fallback one)

`docker run -d --name worker1 -v worker1-src:/work <toolchain-image> sleep infinity`
then `docker exec -it worker1 bash` as the pane command. Same for 2-4. Podman
is a drop-in. Each container clones the repo inside its own volume.

## Git worktrees (fallback two — no infrastructure)

From one clone on the host:

```bash
git worktree add ../wt-api  -b lane/api
git worktree add ../wt-ui   -b lane/ui
git worktree add ../wt-data -b lane/data
git worktree add ../wt-infra -b lane/infra
```

Each cockpit pane is `cd ../wt-<lane> && exec $SHELL`. Isolation is only the
lane guard hook — install it in every worktree.

## Preparing a worker (any topology)

Do this once on a golden image/VM, then clone it:

1. Toolchain for its lane (language runtimes, build tools).
2. `git config user.name / user.email` — give each worker a distinct name
   (`worker-api`, …) so history shows who built what.
3. Push credentials for **its** branch: a fine-grained GitHub token or deploy
   key with write access to the one repo is enough; workers don't need org-wide
   credentials.
4. Clone the repo, `git checkout -b lane/<name> origin/<base>`.
5. Run `lane-guard.sh install workstreams/<name>`.
6. If workers are Claude sessions: install `claude` in the VM and start it in
   the lane folder with the worker brief as the opening prompt.

## SSH for the cockpit

Put the four workers in `~/.ssh/config` on the host so pane commands stay short:

```
Host vm1 vm2 vm3 vm4
  User worker
  StrictHostKeyChecking accept-new
Host vm1
  HostName 192.168.64.11
# ... etc
```

Then: `scripts/cockpit.sh build "ssh vm1" "ssh vm2" "ssh vm3" "ssh vm4"`.
Use `ssh -t vm1 tmux new -As work` if you also want a tmux *inside* each VM so
a dropped connection doesn't kill the worker's shell.

## Screen layouts

- **Default: tmux 2×2 on the host** (`scripts/cockpit.sh`). One attach, four
  workers, a control window, synchronized-panes for fleet-wide commands.
- **Large display, separate windows**: open four terminal windows, each running
  one SSH command, and tile them with the OS (macOS Sequoia window tiling,
  Rectangle, or a Linux tiling WM). Or with UTM, show each VM's actual display.
  Choose this when the user wants to *watch* four GUIs, not four shells.
- Either way the host machine "takes over the desktop": it renders all four
  workers plus the orchestrator's control shell; nobody works directly on the
  host's own checkout except the orchestrator.
