---
name: arena
description: "Spawn N parallel candidates at the same task, pick a base, graft the strongest parts of the losers into it. Use for /arena, 'arena this', 'throw it in the arena', or when one attempt at a non-trivial artifact would lock in the wrong shape."
disable-model-invocation: true
---

# Arena

`<skills>` is the folder that holds this skill's folder, one above this SKILL.md. To run another pstack skill, read `<skills>/<name>/SKILL.md` and follow it.

Open a plan list (your agent's plan tool, else a markdown checklist in your first message, repeated and updated at the top of the final reply) with one entry per phase (Frame, Fan out, Cross-judge, Pick, Graft, Verify) before launching anything.

## Phase A: Frame

Every candidate gets the same prompt, so the prompt is the contract.

1. State the artifact each candidate is producing.
2. Derive the rubric, 3-6 concrete gradeable criteria for what success looks like on *this* task. It is the picker's tool in Phase D. Candidates only see the task.
3. Pick the runners. Use the `arena runners` line in `~/.agents/pstack-models.md`. If the file or that line is missing, default to `inherit, inherit`. An `inherit`, `auto` or `inherit-parent` entry in this line means the parent model, so omit the model for it. A family is a distinct model id. If your subagent tool rejects a configured entry, omit the model so that seat runs on the parent model, and say so. If that spawn fails too, drop the seat and say so. If dropped seats leave fewer than two runners, add runners until there are two, or one when the line has one entry. Run each added runner on a remaining runner's model, or omit `model` so it runs on the parent model when none remain, and say so. Spawn more runners when the arena covers multiple design directions. Use the same model N times when the work is generation-bound rather than judgment-sensitive. Pick each subagent's effort level for the job, per the Subagents section of the **poteto-mode** skill.
4. Give each candidate its own output location (an isolated worktree where possible, else `git worktree add <repo>/.pstack/worktrees/<slug>-<n> -b <branch> HEAD`, otherwise `/tmp/arena-<slug>/candidate-<n>/`), per the **separate-before-serializing-shared-state** principle skill.

## Phase B: Fan out

Spawn all N subagents in one message as background subagents, each with the task, the path to the shared grounding, its own output path, and instructions to produce the artifact and a short rationale naming the alternatives it considered and what it rejected.

If your agent cannot spawn subagents, write the N candidates yourself one at a time, re-reading the task and grounding fresh before each and not looking back at earlier candidates, and say so.

If a candidate produces no output, proceed with N-1 and note the dropout.

## Phase C: Cross-judge

After all Phase B candidates complete, choose one model from the `arena cross-judge pool` line in `~/.agents/pstack-models.md`. If the file or that line is missing, the pool is `inherit, inherit`. Spawn one read-only judge subagent. The judge is never from the parent's family, as Phase A step 3 defines families, so its model id differs from the parent's. Try only the entries from another family, in pool order. An `inherit`, `auto` or `inherit-parent` entry is the parent model, so it never judges as another family. If your subagent tool rejects an entry, move to the next entry. If no entry from another family runs, or the models file names only one model, spawn the judge as a fresh-context read-only subagent on the parent model and say "no cross-family judge available". If your agent cannot spawn subagents, skip the judge, pick the base alone in Phase D, and say so. If you do not know the parent's model, try the pool's named model ids in pool order and say that the family check did not run. The judge sees the rubric and the candidates by path label, scores each criterion, and recommends a base with rationale. It runs in parallel with your reading in Phase D. Don't spawn it while candidates are still writing.

## Phase D: Pick a base

Read every candidate end to end before picking. Score each against the rubric criterion by criterion, not on holistic feel, and compare with the cross-judge when Phase C ran one. Agreement on the base confirms the pick. Disagreement means one of you is biased or the rubric was ambiguous. Read both rationales before deciding.

Pick the base a future maintainer can extend most easily without breaking invariants. When two feel tied, prefer the cleaner boundary or smaller API, per the Laziness Protocol.

## Phase E: Graft

Walk each losing candidate once more for what is worth porting into the base, usually one or two things per candidate, not most of it. Fold each graft in by hand, per the **redesign-from-first-principles** principle skill, so the result stays coherent under one mental model. Don't paste mechanically.

If the candidates converge on one shape, that is strong agreement. Note it and ship the consensus shape. No graft is needed. If they wildly diverge, Phase A was under-specified. Reframe and re-run rather than averaging the divergence.

## Phase F: Verify

Verify the synthesized artifact like any other output, per the **prove-it-works** principle skill. If verification finds a problem the arena missed, either Phase A was wrong (re-frame and re-run) or a candidate caught it and you missed the graft (go back to Phase E). Don't paper over it.

## Outputs

One synthesized artifact, with a short synthesis note alongside naming the base and why, the cross-judge's verdict or that Phase C skipped the judge, each graft with its source candidate, what was rejected and why, any convergence or dropouts, and the verification result.
