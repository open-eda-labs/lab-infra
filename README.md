# lab-infra

Laboratório como código (etapa P2): k3s de nó único dentro do WSL2, Argo Workflows, InfluxDB, Grafana e MLflow. O modelo (Ollama) roda no Windows, fora do cluster, e é alcançado por HTTP (D-16).

## Estado

Escrito e validado só estaticamente (yamllint, shellcheck, kubeconform). **Nunca foi executado**: ver "O que não foi testado". Etapa do plano: P2. Decisões relacionadas: D-16, D-17, D-23, D-32, D-34, D-40.

## Pré-requisitos

- Windows 11 com WSL2 e uma distribuição Ubuntu com systemd ligado em `/etc/wsl.conf`, como em [wslconfig.md](wslconfig.md).
- No WSL2: `make`, `curl`, `openssl` e `sudo`.
- Ollama no Windows com `OLLAMA_HOST=0.0.0.0`, `OLLAMA_CONTEXT_LENGTH` definido (8192 a 16384; o padrão de 4k trunca o prompt, R-16) e o firewall do Windows liberando a porta 11434 para a rede do WSL2.
- Modelo padrão do laboratório: `ollama pull qwen3:4b` (ADR-0004). Outro modelo: variável `MODEL` no `check-model.sh`.
- Driver NVIDIA do Windows (traz o `nvidia-smi` ao WSL2).

## Subir e derrubar

```sh
make up      # instala o k3s pinado (se preciso), cria os segredos, aplica os manifests e espera tudo ficar pronto
make down    # desinstala o k3s e apaga TUDO, inclusive os volumes (InfluxDB, Grafana, MLflow)
```

`make up` é idempotente: reexecutar não troca versão nem segredos. Depois, `export KUBECONFIG=~/.kube/lab-infra.yaml`. Nada é exposto: acesso por port-forward.

```sh
kubectl -n argo port-forward svc/argo-server 2746:2746    # https://localhost:2746
kubectl -n lab port-forward svc/grafana 3000:3000         # usuário admin
kubectl -n lab port-forward svc/mlflow 5000:5000
kubectl -n lab port-forward svc/influxdb 8086:8086        # usuário admin, org lab, bucket replay
kubectl -n lab get secret lab-credentials -o jsonpath='{.data.grafana-password}' | base64 -d   # também influx-password e influx-token
```

## Versões pinadas

Pinadas em `Makefile` (k3s e Argo, baixados e conferidos por `sha256` contra `checksums.txt` antes de rodar) e `k8s/kustomization.yaml` (imagens). Consulta feita em 2026-11-15; a página de releases do GitHub estava bloqueada nesta sessão (HTTP 403), então onde a fonte é um registry, a versão é "a mais nova tag estável no registry", não "a release anunciada".

| Peça | Versão | Origem | Situação |
| --- | --- | --- | --- |
| k3s | v1.37.2+k3s1 | https://update.k3s.io/v1-release/channels (canal stable) | conferida em 2026-11-15; o arquivo da release no GitHub não foi acessado |
| Argo Workflows | v4.1.6 (manifesto `install.yaml` da release) | tag no registry https://quay.io/api/v1/repository/argoproj/workflow-controller/tag/ (v4.1.6, de 22/10/2026, a mais nova da linha 4.1; a v4.0.15 é da linha anterior) | tag conferida; a URL do `install.yaml` no GitHub **não foi conferida** |
| InfluxDB OSS | 2.9.1 | https://hub.docker.com/v2/repositories/library/influxdb/tags | conferida em 2026-11-15; digest conferido no registry |
| Grafana OSS | 13.0.2 (`grafana/grafana-oss`) | https://hub.docker.com/v2/repositories/grafana/grafana-oss/tags | conferida em 2026-11-15; digest conferido no registry |
| MLflow | v3.18.0 (`ghcr.io/mlflow/mlflow`) | https://pypi.org/pypi/mlflow/json (3.18.0, de 03/11/2026) e o manifesto da imagem em ghcr.io | conferida em 2026-11-15 |
| curl (só no `check-model.sh`) | 8.23.0 | https://hub.docker.com/v2/repositories/curlimages/curl/tags | conferida em 2026-11-15; digest conferido |
| kubeconform (só no CI) | v0.8.0 | https://proxy.golang.org/github.com/yannh/kubeconform/@latest | conferida em 2026-11-15 |

Compatibilidade do Argo v4.1.6 e das imagens com o Kubernetes 1.37 do k3s: não conferida.

## O que cada peça faz

| Peça | Papel |
| --- | --- |
| k3s | Kubernetes de nó único no WSL2, sem Traefik nem servicelb (nada exposto) |
| Argo Workflows | Executa os workflows dos próximos passos; Argo Server com 2 réplicas e ClusterIP (R-08: nunca expor) |
| InfluxDB OSS 2.x | Séries do replay (D-34); bucket `replay` na org `lab` |
| Grafana OSS | Painéis do laboratório, com o datasource do InfluxDB (Flux) provisionado |
| MLflow | Rastreio e avaliação (D-32); SQLite e artefatos em volume; sem autenticação, por isso só ClusterIP e port-forward, nunca exposto fora do cluster; dado D3 nunca vai para lá (D-42); não é trilha de auditoria |
| `check-model.sh` | De um pod efêmero, chama `/v1/chat/completions` do modelo (R-26, Q-10) |
| `footprint.sh` | Mede RAM e VRAM e grava `footprint.md` com a data |

Segredos: `make up` gera as senhas e o token com `openssl rand` e cria o Secret `lab-credentials`; nada disso entra no Git. Volumes: `local-path` do k3s (StorageClass padrão).

Não incluídos (opcionais de P2, fora do caminho mínimo): LiteLLM, Postgres, OTel Collector e Tailscale para o desktop.

## Demo-service e InfluxDB

O demo-service envia métricas com `INFLUX_URL=http://influxdb.lab.svc:8086/api/v2/write?org=lab&bucket=replay&precision=ms` e `INFLUX_TOKEN` igual à chave `influx-token` do Secret `lab-credentials` (de fora do cluster, use um port-forward e `127.0.0.1`). O envio com token está coberto por teste no demo-service; a escrita contra o InfluxDB real nunca foi executada.

## Rede dos Workflows

`k8s/networkpolicy.yaml` vale para todo pod de Workflow do Argo: nenhuma entrada; saída só para DNS, HTTPS e a API do cluster. `NetworkPolicy` não filtra por nome de domínio, então restringir a saída a Maven Central e OSV exige um proxy de saída ou outro CNI; isso não está feito. O efeito da política nunca foi observado em cluster.

Em VM aninhada (k3d, alguns WSL2), a VXLAN do flannel pode falhar com `operation not supported`; uma revisão externa precisou de `--flannel-backend=host-gw`. Se os pods não se alcançarem, acrescente essa opção a `K3S_FLAGS` no `Makefile`.

## O que não foi testado

Tudo o que roda. Não havia cluster, Windows nem GPU. Validado só de forma estática: yamllint, shellcheck, `bash -n` e kubeconform nos manifests locais (o `install.yaml` do Argo foi baixado e renderizado pelo kustomize em 2026-11-17, mas nunca aplicado, porque o GitHub estava bloqueado). Em particular, nunca rodaram:

- `make up` e `make down`, a instalação do k3s e as flags escolhidas;
- o Argo Server com 2 réplicas no cluster (o patch foi conferido por `kubectl kustomize` contra o `install.yaml` real da v4.1.6: o Deployment `argo-server` sai com `replicas: 2`; a subida das duas réplicas nunca foi observada);
- a subida das três imagens com UID fixo e sem privilégios (o namespace `lab` exige Pod Security `restricted`): se um pod entrar em crashloop, comece por aí;
- `MLFLOW_SERVER_ALLOWED_HOSTS` (nome da variável lido no código do MLflow 3.18.0; o efeito não foi observado);
- o datasource do Grafana lendo `$INFLUX_TOKEN` do ambiente;
- `check-model.sh`, a descoberta do Windows pelo gateway do WSL2 e a regra de firewall;
- `footprint.sh`, incluindo a leitura de RAM do Windows por `powershell.exe`;
- a afirmação de que a rede NAT do WSL2 mantém a porta 6443 do k3s fora da LAN.

## Gate G-P2 (Plano Mestre, P2)

Rode `make up`, deixe a stack ociosa com o modelo carregado e marque cada item com a evidência (`footprint.md`, saída do `check-model.sh`).

- [ ] RAM total da máquina com a stack ociosa: até 21 GB (`footprint.sh`; acima disso, cortar os itens opcionais).
- [ ] Pod no k3s alcança o modelo: `./check-model.sh` termina com "RESPONDEU (HTTP 200)" (sem rota: servidor de modelo dentro do WSL2, Q-10).
- [ ] VRAM: `nvidia-smi` mostra o modelo inteiro na GPU e `size_vram` igual a `size` em `/api/ps`; qualquer offload para CPU fica registrado (R-16).
- [ ] Reprodução limpa: `make down && make up` refaz tudo (D-40).

Plano: [Plano Mestre](https://github.com/open-eda-labs/open-eda-labs.github.io/blob/main/docs/PLANO_MESTRE.md). Regras da organização: [perfil da org](https://github.com/open-eda-labs).
