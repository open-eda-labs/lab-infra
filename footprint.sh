#!/usr/bin/env bash
# Mede RAM e VRAM com a stack ociosa e grava footprint.md (critérios do G-P2).
# Rode com o modelo carregado no Ollama e nada mais em execução.
set -uo pipefail
cd "$(dirname "$0")" || exit 1
export KUBECONFIG=${KUBECONFIG:-$HOME/.kube/lab-infra.yaml}
MODEL_URL=${MODEL_URL:-http://$(ip route show default | awk '{print $3; exit}'):11434}

bloco() { printf '\n## %s\n\n```\n' "$1"; shift; "$@" 2>&1 || echo "(falhou ou indisponível)"; printf '```\n'; }
# shellcheck disable=SC2016  # o PowerShell é que expande $o, não o bash
win_ram() { powershell.exe -NoProfile -Command '$o=Get-CimInstance Win32_OperatingSystem; "{0:N1} GB usados de {1:N1} GB" -f (($o.TotalVisibleMemorySize-$o.FreePhysicalMemory)/1MB),($o.TotalVisibleMemorySize/1MB)' | tr -d '\r'; }

{
  echo "# Footprint"
  echo
  echo "Medido em $(date -Is). Gate G-P2: RAM total da máquina até 21 GB, modelo inteiro na GPU."
  bloco "RAM total do Windows (gate: até 21 GB)" win_ram
  bloco "RAM da VM do WSL2 (free -m)" free -m
  bloco "Pods (kubectl top; precisa do metrics-server do k3s)" kubectl top pod -A --sort-by=memory
  bloco "VRAM (nvidia-smi)" nvidia-smi --query-gpu=name,memory.used,memory.total --format=csv
  bloco "Modelo carregado: size_vram menor que size indica offload para CPU (R-16)" curl -sS -m 5 "$MODEL_URL/api/ps"
} > footprint.md
cat footprint.md
