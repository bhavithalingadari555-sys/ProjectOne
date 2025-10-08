#!/bin/bash

# Get total allocatable CPU and Memory using jq, handling m suffix and Ki
read total_cpu_m total_mem_ki <<< $(kubectl get nodes -o json | jq -r '
  [
    .items[].status.allocatable |
    {
      cpu: (if .cpu | test("m$") then (.cpu | sub("m$"; "") | tonumber) else (.cpu | tonumber * 1000) end),
      mem: (.memory | sub("Ki$"; "") | tonumber)
    }
  ] |
  reduce .[] as $i (
    {"cpu":0, "mem":0};
    .cpu += $i.cpu | .mem += $i.mem
  ) |
  "\(.cpu) \(.mem)"')

# Get current usage from metrics server
read used_cpu_m used_mem_mi <<< $(kubectl top nodes --no-headers | awk '
  {cpu+=$2; mem+=$4} END {print cpu " " mem}')

# Convert values
cpu_used_cores=$(echo "scale=2; $used_cpu_m / 1000" | bc)
cpu_total_cores=$(echo "scale=2; $total_cpu_m / 1000" | bc)
cpu_free_cores=$(echo "scale=2; $cpu_total_cores - $cpu_used_cores" | bc)

mem_used_gib=$(echo "scale=2; $used_mem_mi / 1024" | bc)
mem_total_gib=$(echo "scale=2; $total_mem_ki / 1024 / 1024" | bc)
mem_free_gib=$(echo "scale=2; $mem_total_gib - $mem_used_gib" | bc)

# Output
echo "====== EKS Cluster Resource Usage ======"
echo "CPU Used     : $cpu_used_cores cores"
echo "CPU Free     : $cpu_free_cores cores"
echo "CPU Total    : $cpu_total_cores cores"
echo
echo "Memory Used  : $mem_used_gib GiB"
echo "Memory Free  : $mem_free_gib GiB"
echo "Memory Total : $mem_total_gib GiB"

