#!/usr/bin/env bash
# Teste de R-26/Q-10: um pod efêmero do k3s alcança o modelo em /v1/chat/completions?
# MODEL_URL: o padrão é o Windows visto do WSL2 (gateway da VM, Ollama na porta 11434).
# O Ollama no Windows precisa escutar fora do loopback (OLLAMA_HOST=0.0.0.0) e o firewall do Windows precisa liberar a porta.
set -euo pipefail
export KUBECONFIG=${KUBECONFIG:-$HOME/.kube/lab-infra.yaml}
MODEL_URL=${MODEL_URL:-http://$(ip route show default | awk '{print $3; exit}'):11434}
MODEL=${MODEL:-qwen3:8b}

body=$(printf '{"model":"%s","messages":[{"role":"user","content":"Responda apenas: ok"}],"max_tokens":16,"stream":false}' "$MODEL")
echo "Chamando $MODEL_URL/v1/chat/completions (modelo $MODEL) de dentro de um pod..."
# Namespace default: o namespace lab exige Pod Security restricted e este pod não é restrito.
saida=$(kubectl run "check-model-$$" -n default --rm -i --quiet --restart=Never \
  --image=curlimages/curl:8.23.0@sha256:3fb7e13e5d179a845c97d78204f3f1064d1907037f26a3ebf91710571151fd93 \
  --command -- curl -sS -m 180 -w '\nHTTP %{http_code}\n' -H 'Content-Type: application/json' -d "$body" "$MODEL_URL/v1/chat/completions") || {
  echo "SEM ROTA: o pod não alcançou $MODEL_URL (R-26). Alternativa do plano: servidor de modelo dentro do WSL2."
  exit 1
}
echo "$saida"
if grep -q '^HTTP 200$' <<<"$saida"; then echo "RESPONDEU (HTTP 200)."; else echo "ALCANÇOU, MAS NÃO RESPONDEU 200 (modelo ausente? veja o corpo acima)."; exit 1; fi
