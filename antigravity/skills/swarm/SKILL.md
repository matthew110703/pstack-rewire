---
name: swarm
description: "Fan out N parallel workers, drain them, and return one report. Use for /swarm, 'swarm this', or parallel coverage, races, gauntlets, and exploration."
---

# Swarm

## Start

Open a todolist with one entry per phase before launching anything.

1. Frame
2. Fan out
3. Aggregate
4. Report

## Phase A: Frame

1. State the done predicate and the artifact or report the swarm must return.
2. Choose the shape. Partition into slices, race N workers on identical briefs, or mix both. For a race or mixed shape, declare `first pass`, `rank all`, or `best-of` before spawning.
3. Pick the worker model from the `swarm workers` line in `.agents/rules/pstack-models.md` or `~/.gemini/config/pstack-models.md`. If the rule or that line is missing, use `flash` (conserving rate-limited `inherit`/Argon quota across high-fanout runs). Resolve any fallback chain (`pro -> inherit -> flash`) dynamically. For a model race, name each arm's `Model` (`pro`, `inherit`, `flash`, `flash_lite`) or structural prior up front. Pick each subagent's `Model` for the job, per the Subagents section of the **poteto-mode** skill.
4. Give each worker its own writable output when it writes (`Workspace: "share"` or `"branch"`, or a disjoint directory). When workers verify or measure commits, each brief names the exact SHAs. A measurement brief also names the method (sample count, what one sample is, order). The worker records both in its result.

## Phase B: Fan out

Spawn all N workers in one turn via `invoke_subagent` with `TypeName: "self"` (or `TypeName: "research"` / `"poteto-explorer"` for strictly read-only exploration, or `"poteto-agent"` when running inside a nested custom subagent where `self`/`research` are restricted), `Workspace: "share"` (or `"branch"` when isolating branches, `"inherit"` when read-only), and the step 3 `Model`. Immediately end your turn (never poll with `schedule` or `manage_subagents`) and wait for their reactive wakeup notifications.

When a worker must start from a non-default pushed branch, instruct it to check out that ref in its isolated `Workspace: "share"` worktree before running.

Every brief stands alone. Include the goal, scope, exact slice or race arm, how to verify, and what to report. Reports use `PASS`, `ISSUES`, or `BLOCKED` with evidence. A worker that can prove a defect reports `ISSUES` and lists every issue it can prove, not only the first.

If a worker drops out, proceed with N-1 and note it.

## Phase C: Aggregate

Read the terminal results. Drop a result that does not record the SHAs and method its brief names, and respawn that worker once (or message it via `send_message`). After a second miss, record a gap. A gap does not count as a pass. For coverage, every required slice needs a result. For a race, apply the selection rule declared up front. Use first pass, rank all, or best-of. Do not paste raw worker dumps.

## Phase D: Report

Return one consolidated in-chat report with a result table, issue one-liners, gaps or dropouts, and the race rule when used.
