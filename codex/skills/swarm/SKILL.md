---
name: swarm
description: "Fan out N parallel workers, drain them, and return one report. Use for $pstack:swarm, 'swarm this', or parallel coverage, races, gauntlets, and exploration."
---

# Swarm

`<pstack>` is the pstack plugin root, two folders above this SKILL.md (Codex shows each skill's path; if not, run `ls -d ~/.codex/plugins/cache/*/pstack/*/ | sort -V | tail -1`). To run another pstack skill or `$pstack:<name>`, read `<pstack>/skills/<name>/SKILL.md` and follow it.

## Start

Open a task list (`update_plan`, else a markdown checklist in your first message, repeated and updated at the top of your final reply) with one entry per phase before launching anything.

1. Frame
2. Fan out
3. Aggregate
4. Report

## Phase A: Frame

1. State the done predicate and the artifact or report the swarm must return.
2. Choose the shape. Partition into slices, race N workers on identical briefs, or mix both. For a race or mixed shape, declare `first pass`, `rank all`, or `best-of` before spawning.
3. Pick the worker model from the `swarm workers` line in the `pstack-models` block of `~/.codex/AGENTS.md`. If the block or that line is missing, use `inherit-parent`. For `auto` or `inherit-parent`, omit `model` so the workers run on the parent model. The line's slug is the `model` and its level is the `reasoning_effort`. If the slug is not listed (`visibility: "list"`) in `~/.codex/models_cache.json`, or `spawn_agent` rejects it, use the default and say so. For a model race, name each arm's model up front. Pick each subagent's effort level for the job, per the Subagents section of the **poteto-mode** skill.
4. Give each worker its own writable output when it writes. When workers verify or measure commits, each brief names the exact SHAs. A measurement brief also names the method (sample count, what one sample is, order). The worker records both in its result.

## Phase B: Fan out

Spawn all N workers in one turn with `spawn_agent`, `agent_type: "worker"`, and the step 3 model, left unset for `auto` or `inherit-parent`. Tell each worker to create its own worktree first with `git worktree add <repo>/.pstack/worktrees/swarm-<slug>-<n> -b swarm-<slug>-<n> <base>` and to use that absolute path for every command and edit. Skip the worktree only when the worker needs the user's checkout itself.

The `<base>` is HEAD. When a worker must start from a non-default pushed branch, use that branch as its `<base>`.

Every brief stands alone. Include the goal, scope, exact slice or race arm, how to verify, and what to report. Reports use `PASS`, `ISSUES`, or `BLOCKED` with evidence. A worker that can prove a defect reports `ISSUES` and lists every issue it can prove, not only the first.

If a worker drops out, proceed with N-1 and note it.

## Phase C: Aggregate

Read the terminal results. Drop a result that does not record the SHAs and method its brief names, and respawn that worker once. After a second miss, record a gap. A gap does not count as a pass. For coverage, every required slice needs a result. For a race, apply the selection rule declared up front. Use first pass, rank all, or best-of. Do not paste raw worker dumps.

## Phase D: Report

Return one consolidated in-chat report with a result table, issue one-liners, gaps or dropouts, and the race rule when used.
