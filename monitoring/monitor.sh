#!/usr/bin/env bash
set -euo pipefail
MON_DIR="/workspace/monitoring"
mkdir -p "$MON_DIR"
LOG_PROC="$MON_DIR/process.log"
LOG_NET_FULL="$MON_DIR/net_full.log"
LOG_NET_HTTP="$MON_DIR/net_http.log"
LOG_ERR="$MON_DIR/monitor.err"
PID_FILE="$MON_DIR/monitor.pid"
INTERVAL="2"
FILTER_PORTS=":80|:443|:8080|:3000|:8000|:5000|:9000"
# Choose network command
NET_CMD=""
if command -v ss >/dev/null 2>&1; then
  NET_CMD="ss -tpnH"
elif command -v lsof >/dev/null 2>&1; then
  NET_CMD="lsof -nP -iTCP -sTCP:LISTEN,ESTABLISHED"
elif command -v netstat >/dev/null 2>&1; then
  NET_CMD="netstat -tnp"
else
  NET_CMD="cat /proc/net/tcp /proc/net/tcp6"
fi
{
  echo "===== monitoring started at $(date -Is) ====="
  echo "proc_log=$LOG_PROC"
  echo "net_full=$LOG_NET_FULL net_http=$LOG_NET_HTTP"
  echo "interval=${INTERVAL}s using=${NET_CMD}"
} | tee -a "$LOG_ERR"
echo $$ > "$PID_FILE"
while true; do
  TS=$(date -Is)
  # Process snapshot (top memory users)
  { echo "timestamp $TS"; ps -eo pid,ppid,user,%mem,%cpu,stime,etime,cmd --sort=-%mem | head -n 60; } >> "$LOG_PROC" 2>>"$LOG_ERR"
  # Network snapshot (full)
  {
    echo "timestamp $TS"
    bash -lc "$NET_CMD"
  } >> "$LOG_NET_FULL" 2>>"$LOG_ERR"
  # HTTP-ish filter (by common ports)
  {
    echo "timestamp $TS"
    if command -v ss >/dev/null 2>&1; then
      ss -tpnH | egrep -E "${FILTER_PORTS}" || true
    elif command -v lsof >/dev/null 2>&1; then
      lsof -nP -iTCP -sTCP:LISTEN,ESTABLISHED | egrep -E "${FILTER_PORTS}" || true
    elif command -v netstat >/dev/null 2>&1; then
      netstat -tnp | egrep -E "${FILTER_PORTS}" || true
    else
      egrep -E "( 06 )" /proc/net/tcp /proc/net/tcp6 || true
    fi
  } >> "$LOG_NET_HTTP" 2>>"$LOG_ERR"
  sleep "$INTERVAL"
done
