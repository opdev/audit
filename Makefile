#!/usr/bin/env bash

#  Copyright 2021 The Audit Authors.
#
#  Licensed under the Apache License, Version 2.0 (the "License");
#  you may not use this file except in compliance with the License.
#  You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
#  Unless required by applicable law or agreed to in writing, software
#  distributed under the License is distributed on an "AS IS" BASIS,
#  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#  See the License for the specific language governing permissions and
#  limitations under the License.

# Get the default container engine
CONTAINER_ENGINE?=docker

# Get the currently used golang install path (in GOPATH/bin, unless GOBIN is set)
ifeq (,$(shell go env GOBIN))
GOBIN=$(shell go env GOPATH)/bin
else
GOBIN=$(shell go env GOBIN)
endif

##@ General

.PHONY: help
help: ## Display this help
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make \033[36m<target>\033[0m\n"} /^[a-zA-Z_0-9-]+:.*?##/ { printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2 } /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) } ' $(MAKEFILE_LIST)

##@ Build
GO_ASMFLAGS = -asmflags "all=-trimpath=$(shell dirname $(PWD))"
GO_GCFLAGS = -gcflags "all=-trimpath=$(shell dirname $(PWD))"
LD_FLAGS=-ldflags " \
    -X main.goos=$(shell go env GOOS) \
    -X main.goarch=$(shell go env GOARCH) \
    -X main.gitCommit=$(shell git rev-parse HEAD) \
    -X main.buildDate=$(shell date -u +'%Y-%m-%dT%H:%M:%SZ') \
    "
.PHONY: build
build: ## Build the project locally
	go build $(GO_GCFLAGS) $(GO_ASMFLAGS) $(LD_FLAGS) -o bin/audit-tool ./cmd
	cp ./bin/audit-tool $(GOBIN)/audit-tool

.PHONY: install
install: ## Build the project locally
	make build
	cp ./bin/audit-tool $(GOBIN)/audit-tool

##@ Development

.PHONY: lint
lint: golangci-lint ## Run golangci-lint linter
	$(GOLANGCI_LINT) run

.PHONY: lint-fix
lint-fix: golangci-lint ## Run golangci-lint linter and perform fixes
	$(GOLANGCI_LINT) run --fix

GOLANGCI_LINT = $(shell pwd)/bin/golangci-lint
golangci-lint:
	@[ -f $(GOLANGCI_LINT) ] || { \
	set -e ;\
	curl -sSfL https://raw.githubusercontent.com/golangci/golangci-lint/master/install.sh | sh -s -- -b $(shell dirname $(GOLANGCI_LINT)) v1.37.1 ;\
	}

##@ Tests

.PHONY: test
test: ## Run the unit tests
	go test -race -v ./pkg/...

.PHONY: test-coverage
test-coverage: ## Run unit tests creating the output to report coverage
	- rm -rf *.out  # Remove all coverage files if exists
	go test -race -failfast -tags=integration -coverprofile=coverage-all.out -coverpkg="./pkg/..." ./pkg/...

.PHONY: test-license
test-license: ## Check if all files has the license
	./hack/check-license.sh

##@ Reports

.PHONY: generate-samples ## Generate the samples in the testdata
generate-samples: install
	go run ./hack/samples/generate_samples.go

.PHONY: generate-testdata ## Generate the full testdata directory
generate-testdata: install
	$(CONTAINER_ENGINE) login https://registry.redhat.io
	make generate-samples
	go run ./hack/report/bundles/generate.go
	make generate-dashboards

.PHONY: generate-dashboards ## Generate the testdata custom dashboards
generate-dashboards:
	go run ./hack/deprecate-api/generate.go
	go run ./hack/maxocpversion/generate.go
	go run ./hack/grade/generate.go
	go run ./hack/catalogs/generate.go
	go run ./hack/muiltarch/generate.go
	go run ./hack/index/generate.go

.PHONY: generate-all ## Generate all testdata with the helpers which are only valid to address special needs to 4.9-GA
generate-all:
	make generate-testdata
	make generate-dashboards

.PHONY: generate-test ## Generate the full testdata directory
generate-test: install
	$(CONTAINER_ENGINE) login https://registry.redhat.io
	go run ./hack/report/bundles/generate.go
	go run ./hack/deprecate-api/generate.go