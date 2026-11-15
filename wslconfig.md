# .wslconfig recomendado

Arquivo `%UserProfile%\.wslconfig` no Windows (não dentro do WSL2). Depois de editar, rode `wsl --shutdown` e abra o WSL2 de novo.

```ini
[wsl2]
memory=14GB
swap=0

[boot]
systemd=true
```

- `memory=14GB`: o WSL2 dá à VM 50% da RAM por padrão (16 GB dos 32 GB). O orçamento estimado da stack é de 14 a 21 GB em toda a máquina, não medido (Plano Mestre, "Ambiente de laboratório"). A VM só abriga k3s, Argo, InfluxDB, Grafana e MLflow; o modelo e o Windows ficam do lado de fora e precisam do resto. 14 GB é um ponto de partida: ajuste depois de rodar `footprint.sh`.
- `swap=0`: sem swap, uma falta de memória aparece como pod morto (OOMKilled), não como lentidão que falseia a medida. Se o k3s não subir por falta de memória, volte ao padrão.
- `systemd=true`: o instalador do k3s registra um serviço systemd. Alternativa: `systemd=true` em `/etc/wsl.conf` dentro da distribuição. Precisa de WSL 0.67.6 ou mais novo.
- Não use `networkingMode=mirrored`: o `check-model.sh` descobre o Windows pelo gateway da VM (rede NAT, o padrão), e a rede NAT mantém a porta 6443 do k3s fora da LAN. Se precisar do modo espelhado, defina `MODEL_URL` e revise a exposição das portas.

Origem: D-16, D-17 e R-26 do Plano Mestre. Os valores de memória e de swap são escolha desta implementação, não do plano; o `systemd=true` e o limite padrão de 50% são de documentação da Microsoft que não foi reconferida nesta sessão.
