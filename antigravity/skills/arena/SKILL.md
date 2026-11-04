---
name: arena
description: "Spawn N parallel candidates at the same task, pick a base, graft the strongest parts of the losers into it. Use for /arena, 'arena this', 'throw it in the arena', or when one attempt at a non-trivial artifact would lock in the wrong shape."
---

# Arena

Open a todolist with one entry per phase (Frame, Fan out, Cross-judge, Pick, Graft, Verify) before launching anything.

## Phase A: Frame

Every candidate gets the same core prompt, so the prompt is the contract.

1. State the artifact each candidate is producing.
2. Derive the rubric, 3-6 concrete gradeable criteria for what success looks like on *this* task. It is the picker's tool in Phase D. Candidates only see the task.
3. Pick the runners. Use the `arena runners` line in `.agents/rules/pstack-models.md` or `~/.gemini/config/pstack-models.md`. If the rule or that line is missing, default to two runners: `pro -> inherit` and `flash`. Resolve fallback chains dynamically: if `pro` is unavailable in the environment, use `inherit` (parent model, e.g., Argon), or `flash` when conserving parent quota. When multiple runners resolve to the same model tier (for example, both resolve to `flash` or `inherit`), assign each runner a distinct **structural prior** (e.g., Runner 1: *minimal-surface / functional-core*, Runner 2: *deep-module / state-machine / data-oriented*) so the arena still explores genuinely different shapes rather than converging on identical defaults. Spawn more runners when the arena covers multiple design directions. Pick each subagent's `Model` for the job, per the Subagents section of the **poteto-mode** skill.
4. Give each candidate its own isolated workspace (`invoke_subagent` with `Workspace: "share"` or `"branch"`, or a separate directory `/tmp/arena-<slug>/candidate-<n>/`), per the **principle-separate-before-serializing-shared-state** skill.

## Phase B: Fan out

Spawn all N subagents in one turn via `invoke_subagent` (`TypeName: "self"`, `Workspace: "share"`), each with the task, the path to the shared grounding, its own output path, any assigned structural prior, and instructions to produce the artifact and a short rationale naming the alternatives it considered and what it rejected. End your turn and wait for their reactive wakeup notifications.

If a candidate produces no output, proceed with N-1 and note the dropout.

## Phase C: Cross-judge

After all Phase B candidates complete, choose one model from the `arena cross-judge pool` line in `.agents/rules/pstack-models.md` or `~/.gemini/config/pstack-models.md` (default `flash, pro -> inherit`). Spawn one read-only judge subagent via `invoke_subagent` (`TypeName: "research"`, or `TypeName: "poteto-explorer"` defined with `EnableWriteTools: false` if running inside a nested subagent where `research` is restricted). Prefer a model tier distinct from the parent's (`flash` when the parent is `inherit`/Argon, or `inherit` when the parent is `flash`). The judge sees the rubric and the candidates by path label, scores each criterion, and recommends a base with rationale. It runs while you read the candidates in Phase D. Don't spawn it while candidates are still writing.

## Phase D: Pick a base

Read every candidate end to end before picking. Score each against the rubric criterion by criterion, not on holistic feel, and compare with the cross-judge when Phase C ran one. Agreement on the base confirms the pick. Disagreement means one of you is biased or the rubric was ambiguous. Read both rationales before deciding.

Pick the base a future maintainer can extend most easily without breaking invariants. When two feel tied, prefer the cleaner boundary or smaller API, per the Laziness Protocol.

## Phase E: Graft

Walk each losing candidate once more for what is worth porting into the base, usually one or two things per candidate, not most of it. Fold each graft in by hand, per the **principle-redesign-from-first-principles** skill, so the result stays coherent under one mental model. Don't paste mechanically.

If the candidates converge on one shape, that is strong agreement. Note it and ship the consensus shape. No graft is needed. If they wildly diverge, Phase A was under-specified. Reframe and re-run rather than averaging the divergence.

## Phase F: Verify

Verify the synthesized artifact like any other output, per the **principle-prove-it-works** skill. If verification finds a problem the arena missed, either Phase A was wrong (re-frame and re-run) or a candidate caught it and you missed the graft (go back to Phase E). Don't paper over it.

## Outputs

One synthesized artifact, with a short synthesis note alongside naming the base and why, the cross-judge's verdict or that Phase C skipped the judge, each graft with its source candidate, what was rejected and why, any convergence or dropouts, and the verification result.
