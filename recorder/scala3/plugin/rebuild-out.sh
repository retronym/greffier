#!/usr/bin/env bash
# LLM-assisted (Claude), see LLM_POLICY.md.
# Rebuild $REPLAY_OUT (see env.sh; the viewer's data directory) with the richest streams: stock compiler + agent with
# the fork's fix and the agent-only hooks, so it has the fork's events, JVM records, Scope/Rejected and
# Tentative events. Runs jvm-verify.sh (which records the corpus and util, default and -opt, into ../out
# and checks them), then adds agent/test/Ranking.scala.
set -uo pipefail
P=$(cd "$(dirname "$0")" && pwd)
export REPLAY_VARIANT=agent REPLAY_AGENT_OPTS=${REPLAY_AGENT_OPTS:-fixTypeApply,rejected,tentative}
"$P/jvm-verify.sh"
source "$P/env.sh"
cd "$P/.."
# Ranking.scala has an ambiguous summon on purpose: the compile stops after typer (no JVM records, no stats line)
plugin/record.sh "$REPLAY_OUT/Ranking.jsonl" agent/test/Ranking.scala >/dev/null 2>&1 || echo "Ranking: dotc exit $? (expected: ambiguity error)"
echo "Ranking: $(python3 plugin/analyze.py "$REPLAY_OUT/Ranking.jsonl" | head -1)"
