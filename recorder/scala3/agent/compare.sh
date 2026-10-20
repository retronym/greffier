#!/usr/bin/env bash
# LLM-assisted (Claude), see LLM_POLICY.md.
# Acceptance experiment: record the corpus and dotc/util with the fork and with stock+agent, and
# compare the streams after the `meta` line (which holds the output path and compiler git hash).
# usage: compare.sh [agent opts, default fixTypeApply] [-opt]   outputs in $REPLAY_OUT-fork, $REPLAY_OUT-agent[-<opts>]
# (REPLAY_OUT, the corpus and the scala3 checkout: see ../plugin/env.sh)
# -opt compiles with -opt -opt-inline:<sources> (JVM optimiser phases in the stream); file names get -opt.
set -uo pipefail
R=$(cd "$(dirname "$0")/.." && pwd)
eval "$(REPLAY_VARIANT=stock; source "$R/plugin/env.sh" || exit 1; declare -p REPLAY_OUT REPLAY_CORPUS REPLAY_SCALA3_CHECKOUT DOTC_CP | sed 's/^declare -x DOTC_CP=/UCP=/')" || exit 1
OPTS=${1-fixTypeApply}
M=${2:-}; OPT=(); [ "$M" = -opt ] && OPT=(-opt '-opt-inline:<sources>')
OUTF=$REPLAY_OUT-fork
OUTA=$REPLAY_OUT-agent${OPTS:+-${OPTS//,/-}}; [ "$OPTS" = fixTypeApply ] && OUTA=$REPLAY_OUT-agent
mkdir -p "$OUTF" "$OUTA"
UTIL=$(ls "$REPLAY_SCALA3_CHECKOUT"/compiler/src/dotty/tools/dotc/util/*.scala)
# util is compiled against the stock compiler classes in both runs (UCP, above), so the inputs are the same
run() { # variant out srcs... -- args
  local v=$1 out=$2; shift 2
  REPLAY_VARIANT=$v REPLAY_AGENT_OPTS=$OPTS "$R/plugin/record.sh" "$out" "$@" >/dev/null 2>&1 || echo "  ($v exit $?)"
}
for f in Closures ForDesugar Givens Mixins Patmat; do
  [ -n "${SKIP_FORK:-}" ] || run fork "$OUTF/$f$M.jsonl" "$REPLAY_CORPUS/$f.scala" -- ${OPT[@]+"${OPT[@]}"}
  run agent "$OUTA/$f$M.jsonl" "$REPLAY_CORPUS/$f.scala" -- ${OPT[@]+"${OPT[@]}"}
done
[ -n "${SKIP_FORK:-}" ] || DOTC_USER_CP=$UCP run fork "$OUTF/util$M.jsonl" $UTIL -- -Yexplicit-nulls -nowarn ${OPT[@]+"${OPT[@]}"}
DOTC_USER_CP=$UCP run agent "$OUTA/util$M.jsonl" $UTIL -- -Yexplicit-nulls -nowarn ${OPT[@]+"${OPT[@]}"}
for f in Closures ForDesugar Givens Mixins Patmat util; do
  a=$OUTF/$f$M.jsonl; b=$OUTA/$f$M.jsonl
  if cmp -s <(tail -n +2 "$a") <(tail -n +2 "$b"); then r=identical
  else r="DIFFER: $(diff <(tail -n +2 "$a") <(tail -n +2 "$b") | grep -c '^[<>]') lines"; fi
  printf '%-10s %10d %10d %6d  %s\n' "$f$M" "$(wc -c < "$a")" "$(wc -c < "$b")" "$(grep -c '"ir":"jvm"' "$b")" "$r"
done
