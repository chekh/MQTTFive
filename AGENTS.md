# MQTTFive

Pure MQL5 implementation of the MQTT 5.0 protocol. Zero DLL dependencies; TCP and TLS via the native MQL5 Socket API.

## Git: the v1.1 policy is mandatory

The policy is adopted and mandatory to the extent that does not conflict with the repository's current state (no force, main discipline, tags, §15 branch deletion). Until the transition is complete, feat/fix→dev branching and dev→main integration remain the working practice. Transition to the full regime is a separate owner decision.

Policy copy: [docs/git-collaboration-policy-v1.1.md](docs/git-collaboration-policy-v1.1.md) (canon: trading-signal/docs/handoff/2026-10-31-git-collaboation-policy/git-collaboration-policy-v1.1.md). Essence: the only integration branch is main; task branches are created from a verified main SHA; integration goes through PRs and merge --no-ff (squash only as an explicit accepting exception); only the integration mechanism changes main, force updates are forbidden; tags vX.Y.Z are placed on accepted main SHAs.
