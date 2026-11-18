# WSL2

O k3s precisa de systemd. Ele se liga dentro da distribuição, em `/etc/wsl.conf` (não no `.wslconfig` do Windows):

```ini
[boot]
systemd=true
```

Depois rode `wsl --shutdown` no Windows e abra o WSL2 de novo. `systemctl is-system-running` deve responder.

Memória: fique com o padrão do WSL2 (metade da RAM da máquina para a VM). Só crie um `%UserProfile%\.wslconfig` com `memory=` se o `footprint.sh` mostrar que a VM ou o Windows ficaram sem folga.

Não use `networkingMode=mirrored`: o `check-model.sh` descobre o Windows pelo gateway da VM (rede NAT, o padrão), e a rede NAT mantém a porta 6443 do k3s fora da LAN. Se precisar do modo espelhado, defina `MODEL_URL` e revise a exposição das portas.

Origem: D-16, D-17 e R-26 do Plano Mestre. O comportamento do WSL2 descrito aqui vem da documentação da Microsoft e não foi reconferido nesta sessão.
