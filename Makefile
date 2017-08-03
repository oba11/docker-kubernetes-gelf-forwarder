APP = $(shell find ./kube/* -maxdepth 0 -type d -exec basename {} \;)

init: upgrade

install: package
	cd kube && helm install -n $(APP) ./$(APP)-0.1.0.tgz

upgrade: package
	cd kube && helm upgrade -f $(APP)/values.yaml $(APP) $(APP)-0.1.0.tgz

package:
	cd kube && helm package $(APP)

build:
	@eval $$(minikube docker-env) && docker build -t $(APP):latest .

delete:
	helm delete --purge $(APP)

logs:
	kubectl logs --tail 50 -f deploy/$(APP)

status:
	helm status $(APP)

clean: delete
