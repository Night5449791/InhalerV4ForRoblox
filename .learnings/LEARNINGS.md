# Learnings

## [LRN-20261005-001] correction

**Logged**: 2026-10-05
**Priority**: Medium
**Status**: resolved
**Area**: frontend

### Summary
"Only spam/load one X" means keep the looping behavior, but instantiate X once — not convert it to a single one-shot action.

### Details
Asked to make `UniversalLagger` "load only one broken anim", I removed the `repeat ... until not Enabled` loop and played a single animation once. The user corrected me: they wanted the module to keep *spamming* (looping) the broken animation, but build the `Animation` instance / random ID **once** outside the loop and replay that same instance, instead of generating a new random animation every frame.

Original code created a fresh `Animation` + new random ID each iteration; the desired behavior keeps spam but reuses one.

### Suggested Action
When a request pairs a repetition verb ("spam", "loop", "keep doing") with "only one X", preserve the repetition and hoist the resource creation outside the loop. Only drop the loop if the user explicitly says "single / one-shot / play once".

### Metadata
- Source: user_feedback
- Related Files: src/games/universal - base/World/UniversalLagger.lua
- Tags: intent-parsing, roblox, lua
- Pattern-Key: clarify.repetition_scope
- Recurrence-Count: 1
- First-Seen: 2026-10-05
- Last-Seen: 2026-10-05

### Resolution
- **Resolved**: 2026-10-05
- **Notes**: Restored the `repeat ... until not UniversalLagger.Enabled` loop; `Animation` instance and the randomized ID are now built once before the loop, and each iteration re-loads/plays that same instance.
