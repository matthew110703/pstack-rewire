---
name: arena
description: "Spawn N parallel candidates at the same task, pick a base, graft the strongest parts of the losers into it. Use for $pstack:arena, 'arena this', 'throw it in the arena', or when one attempt at a non-trivial artifact would lock in the wrong shape."
---

# Arena

`<pstack>` is the pstack plugin root, two folders above this SKILL.md (Codex shows each skill's path; if not, run `ls -d ~/.codex/plugins/cache/*/pstack/*/ | sort -V | tail -1`). To run another pstack skill or `$pstack:<name>`, read `<pstack>/skills/<name>/SKILL.md` and follow it.

Open a task list (`update_plan`, else a markdown checklist in your first message, repeated and updated at the top of your final reply) with one entry per phase (Frame, Fan out, Cross-judge, Pick, Graft, Verify) before launching anything.

## Phase A: Frame

Every candidate gets the same prompt, so the prompt is the contract.

1. State the artifact each candidate is producing.
2. Derive the rubric, 3-6 concrete gradeable criteria for what success looks like on *this* task. It is the picker's tool in Phase D. Candidates only see the task.
3. Pick the runners. Use the `arena runners` line in the `pstack-models` block of `~/.codex/AGENTS.md`. If the block or that line is missing, default to one each on `gpt-6-astra xhigh` and `gpt-6.1-sol xhigh`. An `auto` or `inherit-parent` entry in this line means the parent model, so omit `model` for it. An entry's slug is its `model` and its level is its `reasoning_effort`. Never set `ultra`. A family is a model slug. If a configured entry's slug is not listed (`visibility: "list"`) in `~/.codex/models_cache.json`, or `spawn_agent` rejects the entry, run that seat on its family's default and say so. The default for `gpt-6-astra` is `gpt-6-astra xhigh`, and for `gpt-6.1-sol` it is `gpt-6.1-sol xhigh`. If the family has no default, the default is not listed, or `spawn_agent` rejects it, omit `model` so the seat runs on the parent model and say so, or drop the seat and say so when that spawn fails too. If dropped seats leave fewer than two runners, add runners until there are two, or one when the line has one entry. Run each added runner on a remaining runner's model, or omit `model` so it runs on the parent model when none remain, and say so. Spawn more runners when the arena covers multiple design directions. Use the same model N times when the work is generation-bound rather than judgment-sensitive. Pick each subagent's effort level for the job, per the Subagents section of the **poteto-mode** skill.
4. Give each candidate its own output location (where possible a git worktree the candidate creates first with `git worktree add <repo>/.pstack/worktrees/arena-<slug>-<n> -b arena-<slug>-<n> HEAD` and uses by absolute path, otherwise `/tmp/arena-<slug>/candidate-<n>/`), per the **separate-before-serializing-shared-state** principle skill.

## Phase B: Fan out

Spawn all N subagents in one turn with `spawn_agent` and `agent_type: "worker"`, each with the task, the path to the shared grounding, its own output path, and instructions to produce the artifact and a short rationale naming the alternatives it considered and what it rejected.

If a candidate produces no output, proceed with N-1 and note the dropout.

## Phase C: Cross-judge

After all Phase B candidates complete, choose one model from the `arena cross-judge pool` line in the `pstack-models` block of `~/.codex/AGENTS.md`. If the block or that line is missing, choose from `gpt-6-astra xhigh` and `gpt-6.1-sol xhigh`. Spawn one judge subagent with `agent_type: "explorer"`, tell it not to edit files, and check `git status` after it returns. The judge is never from the parent's family, as Phase A step 3 defines families, so its slug differs from the parent's. Try only the entries from another family, in pool order. An `auto` or `inherit-parent` entry is the parent model, so it never judges. Skip an entry whose slug is not listed in `~/.codex/models_cache.json`. With the default pool, a `gpt-6.1-sol` parent gets `gpt-6-astra xhigh` and a `gpt-6-astra` parent gets `gpt-6.1-sol xhigh`. A parent on any other slug gets `gpt-6-astra xhigh` first. If `spawn_agent` rejects an entry, move to the next entry. If no entry from another family runs, try the default pool's entries from another family the same way. If none of those runs, skip the judge, pick the base alone in Phase D, and say so. If you do not know the parent's model, try the pool's listed slugs in pool order and say that the family check did not run. The judge sees the rubric and the candidates by path label, scores each criterion, and recommends a base with rationale. It runs in parallel with your reading in Phase D. Don't spawn it while candidates are still writing.

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
