# My variables
IMAGE_NAME = electron-release-server
VERSION_NUMBER = 1.4.3

# Docker image vars
IMAGE_TAG = $(VERSION_NUMBER)-b$(BUILD_NUMBER)
FULL_IMAGE = $(DOCKER_REGISTRY)/$(IMAGE_NAME):$(IMAGE_TAG)

# AWS vars
ECS_LOGIN = $(shell aws ecr get-login --no-include-email)

# Helm charts
HELM_DEPLOY_CHART = $(IMAGE_NAME)-$(IMAGE_TAG).tgz

.PHONY: build
build:
	docker rmi -f $(IMAGE_NAME) || true
	docker build -t $(IMAGE_NAME) .

.PHONY: docker-publish build
docker-publish: build
	@$(ECS_LOGIN)
	aws ecr describe-repositories --repository-names ${IMAGE_NAME} || aws ecr create-repository --repository-name ${IMAGE_NAME}docker tag $(IMAGE_NAME) $(FULL_IMAGE)
	docker tag $(IMAGE_NAME) $(FULL_IMAGE)
	docker push $(FULL_IMAGE)

.PHONY: helm-package docker-publish
helm-publish: docker-publish
	yaml set ./helm/$(IMAGE_NAME)/values.yaml image.tag $(IMAGE_TAG) > ./new-values.yaml
	mv ./new-values.yaml ./helm/$(IMAGE_NAME)/values.yaml
	mkdir -p ./out
	helm package --destination ./out --version $(IMAGE_TAG) ./helm/$(IMAGE_NAME)
	curl -i -X POST -F chart=@$(shell pwd)/out/$(HELM_DEPLOY_CHART) $(HELM_PUBLISHER)/chart
