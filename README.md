# lab-infra

Laboratório como código: WSL2, k3s, values do Argo Workflows, InfluxDB, Grafana, MLflow, ACLs da Tailscale e footprint medido. Recriação do zero com um comando.

## Estado

Esqueleto inicial, sem implementação. Etapas do plano: P2. Decisões relacionadas: D-16, D-17, D-23, D-32, D-40.

## Contexto

Este repositório faz parte do laboratório open-eda-labs: workflows agênticos disparados por eventos, com Argo Workflows e padrões abertos. Cada peça trocável é um repositório que só depende do contrato versionado em `triage-contract` (D-01, D-27).

A fonte da verdade é o [Plano Mestre](https://github.com/open-eda-labs/open-eda-labs.github.io/blob/main/docs/PLANO_MESTRE.md).

## Regras

- Só dados sintéticos ou públicos; nenhum dado, código ou nome de empresa (D-24, D-27).
- Tudo como código, versões pinadas e segredos fora do Git (D-40).
- Mudanças entram por pull request; o agente nunca faz merge (D-02, D-31).
