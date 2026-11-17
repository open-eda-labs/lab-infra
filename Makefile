# Ponto de entrada único: make up | make down. Roda no WSL2 (Ubuntu com systemd), usuário comum com sudo.
# Versão do k3s: canal stable em https://update.k3s.io/v1-release/channels (conferida em 2026-11-15).
# A do Argo fica em ARGO_INSTALL_URL; as das imagens, em k8s/kustomization.yaml.
K3S_VERSION := v1.37.2+k3s1
# Baixados a cada subida e conferidos contra checksums.txt antes de qualquer execução (D-40).
K3S_INSTALL_URL := https://raw.githubusercontent.com/k3s-io/k3s/$(subst +,%2B,$(K3S_VERSION))/install.sh
ARGO_INSTALL_URL := https://github.com/argoproj/argo-workflows/releases/download/v4.1.6/install.yaml
# Sem Traefik nem servicelb: nada é exposto fora do cluster; o acesso é por port-forward.
K3S_FLAGS := server --disable traefik --disable servicelb --write-kubeconfig-mode 600

export KUBECONFIG := $(HOME)/.kube/lab-infra.yaml

.PHONY: up down

up:
	curl -sfL -o .k3s-install.sh "$(K3S_INSTALL_URL)"
	curl -sfL -o k8s/argo-install.yaml "$(ARGO_INSTALL_URL)"
	sha256sum -c checksums.txt
	k3s --version 2>/dev/null | grep -qF "$(K3S_VERSION)" || \
	  sudo env INSTALL_K3S_VERSION="$(K3S_VERSION)" INSTALL_K3S_EXEC="$(K3S_FLAGS)" sh .k3s-install.sh
	mkdir -p $(dir $(KUBECONFIG))
	sudo install -o $$(id -u) -g $$(id -g) -m 600 /etc/rancher/k3s/k3s.yaml $(KUBECONFIG)
	kubectl wait --for=condition=Ready node --all --timeout=180s
	kubectl apply -f k8s/namespaces.yaml
	# Segredos gerados aqui e nunca versionados; só criados se ainda não existem.
	kubectl -n lab get secret lab-credentials >/dev/null 2>&1 || kubectl -n lab create secret generic lab-credentials \
	  --from-literal=influx-password=$$(openssl rand -hex 16) \
	  --from-literal=influx-token=$$(openssl rand -hex 32) \
	  --from-literal=grafana-password=$$(openssl rand -hex 16)
	kubectl apply -k k8s
	test "$$(kubectl -n argo get deploy argo-server -o jsonpath={.spec.replicas})" = 2 || { echo "o patch de 2 réplicas do argo-server não pegou"; exit 1; }
	for d in argo/workflow-controller argo/argo-server lab/influxdb lab/grafana lab/mlflow; do kubectl -n $${d%%/*} rollout status deploy/$${d##*/} --timeout=300s || exit 1; done

down:
	if [ -x /usr/local/bin/k3s-uninstall.sh ]; then sudo /usr/local/bin/k3s-uninstall.sh; fi
	rm -f $(KUBECONFIG)
