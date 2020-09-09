BUILD_DIR ?= $(CURDIR)/build
COMMIT    := $(shell git log -1 --format='%H')

###############################################################################
##                                  Version                                  ##
###############################################################################

ifeq (,$(VERSION))
  VERSION := $(shell git describe --exact-match 2>/dev/null)
  # if VERSION is empty, then populate it with branch's name and raw commit hash
  ifeq (,$(VERSION))
    VERSION := $(BRANCH)-$(COMMIT)
  endif
endif

###############################################################################
##                              Build / Install                              ##
###############################################################################

ldflags = -X github.com/cicizeo/loran/cmd/loran.Version=$(VERSION) \
		  -X github.com/cicizeo/loran/cmd/loran.Commit=$(COMMIT)

BUILD_FLAGS := -ldflags '$(ldflags)'

build: go.sum
	@echo "--> Building..."
	CGO_ENABLED=0 go build -mod=readonly -o $(BUILD_DIR)/ $(BUILD_FLAGS) ./...

install: go.sum
	@echo "--> Installing..."
	CGO_ENABLED=0 go install -mod=readonly $(BUILD_FLAGS) ./...

.PHONY: build install

###############################################################################
##                              Tests & Linting                              ##
###############################################################################

build-docker-test:
	@echo "--> Building docker image..."
	@docker build -f Dockerfile.test -t loran-test .

docker-test:
	@echo "--> Running tests in docker..."
	@docker run loran-test

test-integration:
	@echo "--> Running tests"
	@go test -mod=readonly -race ./test/... -v

lint:
	@echo "--> Running linter"
	@go run github.com/golangci/golangci-lint/cmd/golangci-lint run --timeout=10m

.PHONY: test-integration lint

###############################################################################
##                                 Solidity                                  ##
###############################################################################

gen: solidity-wrappers

SOLIDITY_DIR = solidity
solidity-wrappers: $(SOLIDITY_DIR)/contracts/*.sol
	cd $(SOLIDITY_DIR)/contracts/ ; \
	for file in $(^F) ; do \
			mkdir -p ../wrappers/$${file} ; \
			echo abigen --type=peggy --pkg wrappers --out=../wrappers/$${file}/wrapper.go --sol $${file} ; \
			abigen --type=peggy --pkg wrappers --out=../wrappers/$${file}/wrapper.go --sol $${file} ; \
	done
