#!/usr/bin/env bash
# LLM-assisted (Claude), see LLM_POLICY.md.
# Record one compile with the locally built recorder: run1.sh <out.jsonl> <classes dir> [scalac options and files...]
set -euo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
V=${REPLAY_SCALA:-2.13.18}
T=$HERE/target/$V
JAVA=${JAVA_HOME_REPLAY:-$HOME/.sdkman/candidates/java/21.0.12+1.1-tem}/bin/java
CS=${COURSIER:-$(command -v coursier || echo cs)}
OUTF=$1; CLASSES=$2; shift 2
CP=$($CS fetch -p "org.scala-lang:scala-compiler:$V")
LIB=$($CS fetch -p "org.scala-lang:scala-library:$V")
mkdir -p "$CLASSES"
exec "$JAVA" -Xss8m -Xmx3g -javaagent:$T/agent/replay-nsc-agent.jar=${REPLAY_AGENT_OPTS:-} ${REPLAY_JVM_OPTS:-} -cp "$CP" scala.tools.nsc.Main \
  -classpath "$LIB" -Xplugin:$T/plugin -P:replay-record:out=$OUTF ${REPLAY_PLUGIN_OPTS:-} -d "$CLASSES" "$@"
