# Source me. LLM-assisted (Claude), see LLM_POLICY.md.
# Developer setup for a scala3 checkout: runs a locally built nonbootstrapped compiler directly with java (no sbt per
# compile). The server (server/versions.py) does not use this; it builds its own workspaces.
#
# Inputs (from a scala3 checkout, see below):
#   REPLAY_COMPILER_CLASSPATH  file holding the colon-separated classpath of the nonbootstrapped compiler, e.g. from
#                              `sbt "export scala3-compiler-nonbootstrapped/Runtime/fullClasspath"` (default:
#                              ./compiler.classpath if present). Its compiler/target/... entry is replaced by the
#                              classes below; the checkout itself is found from that entry (REPLAY_SCALA3_CHECKOUT
#                              overrides), for util-run.sh and agent/compare.sh.
#   REPLAY_COMPILER_CLASSES    the compiler classes to run (a copy of compiler/target/.../classes). Required for
#                              REPLAY_VARIANT=fork (a build of the TyperObserver fork, compiler-patches/scala3).
#   REPLAY_STOCK_CLASSES       stock (unpatched) compiler classes: the default compiler for REPLAY_VARIANT=agent|stock
#                              and what agent/build.sh compiles against.
# Both classes variables fall back to ../classes-fork and ../classes-stock (recorder/scala3/classes-*) if they exist.
#
# REPLAY_VARIANT selects compiler and hook delivery:
#   fork  (default) REPLAY_COMPILER_CLASSES, plugin classes-fork
#   agent           REPLAY_STOCK_CLASSES + -javaagent, plugin classes-agent;
#                   REPLAY_AGENT_OPTS is passed as the agent's options (e.g. fixTypeApply,rejected)
#   stock           REPLAY_STOCK_CLASSES, no agent (the plugin can still be built as classes-agent)
# REPLAY_JAVA_OPTS adds JVM options; DOTC_USER_CP overrides the -classpath of the compiled sources (default: the
# library). Outputs: REPLAY_OUT (default recorder/scala3/target/out) for the scripts that write recordings.
export JAVA_HOME=${JAVA_HOME_REPLAY:-$HOME/.sdkman/candidates/java/21.0.12+1.1-tem}
HERE=$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)
export REPLAY_HOME=$HERE                                   # recorder/scala3/plugin
export REPLAY_SCALA3=$(cd "$HERE/.." && pwd)               # recorder/scala3 (agent/, plugin/)
export REPLAY_REPO=$(cd "$HERE/../../.." && pwd)           # repository root
export REPLAY_CORPUS=${REPLAY_CORPUS:-$REPLAY_REPO/corpus}
export REPLAY_OUT=${REPLAY_OUT:-$REPLAY_SCALA3/target/out}
export REPLAY_VARIANT=${REPLAY_VARIANT:-fork}
export AGENT_JAR=$REPLAY_SCALA3/agent/target/replay-agent.jar
_replay_err() { echo "env.sh: $*" >&2; }
_cpf=${REPLAY_COMPILER_CLASSPATH:-}
[ -z "$_cpf" ] && [ -f "$HERE/compiler.classpath" ] && _cpf=$HERE/compiler.classpath
[ -n "$_cpf" ] || { _replay_err "set REPLAY_COMPILER_CLASSPATH to a file with the nonbootstrapped compiler's classpath (in a scala3 checkout: sbt \"export scala3-compiler-nonbootstrapped/Runtime/fullClasspath\" > compiler.classpath)"; return 1 2>/dev/null || exit 1; }
[ -f "$_cpf" ] || { _replay_err "REPLAY_COMPILER_CLASSPATH=$_cpf: no such file"; return 1 2>/dev/null || exit 1; }
export REPLAY_COMPILER_CLASSPATH=$_cpf
_stock=${REPLAY_STOCK_CLASSES:-}; [ -z "$_stock" ] && [ -d "$REPLAY_SCALA3/classes-stock" ] && _stock=$REPLAY_SCALA3/classes-stock
_fork=${REPLAY_COMPILER_CLASSES:-}; [ -z "$_fork" ] && [ -d "$REPLAY_SCALA3/classes-fork" ] && _fork=$REPLAY_SCALA3/classes-fork
export REPLAY_STOCK_CLASSES=$_stock
case $REPLAY_VARIANT in
  fork)  _cc=$_fork; _need="REPLAY_COMPILER_CLASSES (the fork's compiler classes)"; export PLUGIN_CLASSES=$HERE/classes-fork; _jo="" ;;
  agent) _cc=${REPLAY_COMPILER_CLASSES:-$_stock}; _need="REPLAY_STOCK_CLASSES (stock compiler classes)"; export PLUGIN_CLASSES=$HERE/classes-agent; _jo="-javaagent:$AGENT_JAR${REPLAY_AGENT_OPTS:+=$REPLAY_AGENT_OPTS}" ;;
  stock) _cc=${REPLAY_COMPILER_CLASSES:-$_stock}; _need="REPLAY_STOCK_CLASSES (stock compiler classes)"; export PLUGIN_CLASSES=$HERE/classes-agent; _jo="" ;;
  *) _replay_err "unknown REPLAY_VARIANT=$REPLAY_VARIANT (fork, agent or stock)"; return 1 2>/dev/null || exit 1 ;;
esac
[ -n "$_cc" ] || { _replay_err "REPLAY_VARIANT=$REPLAY_VARIANT needs $_need: set it to a compiler/target/scala3-compiler-nonbootstrapped/scala-*/classes directory (or a copy of one)"; return 1 2>/dev/null || exit 1; }
[ -d "$_cc" ] || { _replay_err "compiler classes $_cc: no such directory"; return 1 2>/dev/null || exit 1; }
export COMPILER_CLASSES=$_cc
_ccre='.*/compiler/target/scala3-compiler-nonbootstrapped/scala-[^/]*/classes$'
export REPLAY_SCALA3_CHECKOUT=${REPLAY_SCALA3_CHECKOUT:-$(tr ':' '\n' < "$_cpf" | grep -m1 "$_ccre" | sed 's#/compiler/target/.*##')}
export DOTC_CP=$(tr ':' '\n' < "$_cpf" | sed "s#$_ccre#$COMPILER_CLASSES#" | paste -sd: -)
export LIB_CP=$(tr ':' '\n' < "$_cpf" | grep '/library/target/' | paste -sd: -)
export DOTC_JAVA_OPTS="$_jo ${REPLAY_JAVA_OPTS:-}"
dotc() { "$JAVA_HOME/bin/java" -Xss8m -Xmx4g $DOTC_JAVA_OPTS -cp "$DOTC_CP" dotty.tools.dotc.Main -color:never -classpath "${DOTC_USER_CP:-$LIB_CP}" "$@"; }
