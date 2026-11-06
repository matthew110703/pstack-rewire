---
name: swarm
description: "Fan out N parallel workers, drain them, and return one report. Use for /pstack:swarm, 'swarm this', or parallel coverage, races, gauntlets, and exploration."
disable-model-invocation: true
---

# Swarm

`<pstack>` is the pstack plugin root, `${CLAUDE_PLUGIN_ROOT}` (two folders above this file when that is not expanded). To run another pstack skill or `/pstack:<name>`, read `<pstack>/skills/<name>/SKILL.md` and follow it. The Skill tool refuses pstack skills.

## Start

Open a task list (`TodoWrite` or `TaskCreate`, else a checklist kept in your reply) with one entry per phase before launching anything.

1. Frame
2. Fan out
3. Aggregate
4. Report

## Phase A: Frame

1. State the done predicate and the artifact or report the swarm must return.
2. Choose the shape. Partition into slices, race N workers on identical briefs, or mix both. For a race or mixed shape, declare `first pass`, `rank all`, or `best-of` before spawning.
3. Pick the worker model from the `swarm workers` line in `~/.claude/rules/pstack-models.md`. If the rule or that line is missing, use `inherit-parent`. For `auto` or `inherit-parent`, omit `model` so the workers run on the parent model. The `model` value must be `opus`, `sonnet`, `haiku`, or `fable`, and the line's level is the `effort`. If the line names anything else, or the Agent tool rejects it, use the default and say so. For a model race, name each arm's model up front. Pick each subagent's effort level for the job, per the Subagents section of the **poteto-mode** skill.
4. Give each worker its own writable output when it writes. When workers verify or measure commits, each brief names the exact SHAs. A measurement brief also names the method (sample count, what one sample is, order). The worker records both in its result.

## Phase B: Fan out

Spawn all N workers in one message with `subagent_type: "general-purpose"`, `isolation: "worktree"`, and the step 3 model, left unset for `auto` or `inherit-parent`. Name the branch or commit each worker starts from in its brief. Omit `isolation` only when the worker needs the user's checkout itself.

When a worker must start from a non-default pushed branch, tell it to check out that branch first.

Every brief stands alone. Include the goal, scope, exact slice or race arm, how to verify, and what to report. Reports use `PASS`, `ISSUES`, or `BLOCKED` with evidence. A worker that can prove a defect reports `ISSUES` and lists every issue it can prove, not only the first.

If a worker drops out, proceed with N-1 and note it.

## Phase C: Aggregate

Read the terminal results. Drop a result that does not record the SHAs and method its brief names, and respawn that worker once. After a second miss, record a gap. A gap does not count as a pass. For coverage, every required slice needs a result. For a race, apply the selection rule declared up front. Use first pass, rank all, or best-of. Do not paste raw worker dumps.

## Phase D: Report

Return one consolidated in-chat report with a result table, issue one-liners, gaps or dropouts, and the race rule when used.
