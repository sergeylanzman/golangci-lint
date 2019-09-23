.DEFAULT_GOAL = test
.PHONY: FORCE

# enable module support across all go commands.
export GO111MODULE = on
# opt-in to vendor deps across all go commands.
export GOFLAGS = -mod=vendor
# enable consistent Go 1.12/1.13 GOPROXY behavior.
export GOPROXY = https://proxy.golang.org

# Build

fast_build: FORCE
	go build -o golangci-lint ./cmd/golangci-lint
build_race: FORCE
	go build -race -o golangci-lint ./cmd/golangci-lint
build: golangci-lint
clean:
	rm -f golangci-lint test/path
	rm -rf tools
.PHONY: fast_build build build_race clean

# Test
test: export GOLANGCI_LINT_INSTALLED = true
test: build
	GL_TEST_RUN=1 time ./golangci-lint run -v
	GL_TEST_RUN=1 time ./golangci-lint run --fast --no-config -v --skip-dirs 'test/testdata_etc,internal/(cache|renameio|robustio)'
	GL_TEST_RUN=1 time ./golangci-lint run --no-config -v --skip-dirs 'test/testdata_etc,internal/(cache|renameio|robustio)'
	GL_TEST_RUN=1 time go test -v ./...
.PHONY: test

test_race:
	go build -race -o golangci-lint ./cmd/golangci-lint
	GL_TEST_RUN=1 ./golangci-lint run -v --deadline=5m
.PHONY: test_race

test_linters:
	GL_TEST_RUN=1 go test -v ./test -count 1 -run TestSourcesFromTestdataWithIssuesDir/$T
.PHONY: test_linters

# Maintenance

generate: README.md docs/demo.svg install.sh pkg/logutils/mock_logutils/mock_log.go vendor
fast_generate: README.md vendor

maintainer-clean: clean
	rm -f docs/demo.svg README.md install.sh pkg/logutils/mock_logutils/mock_log.go
	rm -rf vendor
.PHONY: generate maintainer-clean

check_generated:
	$(MAKE) --always-make generate
	git checkout -- go.mod go.sum # can differ between go1.11 and go1.12
	git checkout -- vendor/modules.txt # can differ between go1.12 and go1.13
	git diff --exit-code # check no changes
.PHONY: check_generated

fast_check_generated:
	$(MAKE) --always-make fast_generate
	git checkout -- go.mod go.sum # can differ between go1.11 and go1.12
	git checkout -- vendor/modules.txt # can differ between go1.12 and go1.13
	git diff --exit-code # check no changes
.PHONY: fast_check_generated

release:
	go run ./vendor/github.com/goreleaser/goreleaser
.PHONY: release

# Non-PHONY targets (real files)

golangci-lint: FORCE pkg/logutils/mock_logutils/mock_log.go
	go build -o $@ ./cmd/golangci-lint

tools:
	@mkdir -p tools

tools/svg-term: tools
	cd tools && npm ci
	ln -sf node_modules/.bin/svg-term $@

tools/Dracula.itermcolors: tools
	curl -fL -o $@ https://raw.githubusercontent.com/dracula/iterm/master/Dracula.itermcolors

docs/demo.svg: tools/svg-term tools/Dracula.itermcolors
	./tools/svg-term --cast=183662 --out docs/demo.svg --window --width 110 --height 30 --from 2000 --to 20000 --profile ./tools/Dracula.itermcolors --term iterm2

install.sh: .goreleaser.yml
	go run ./vendor/github.com/goreleaser/godownloader .goreleaser.yml | sed '/DO NOT EDIT/s/ on [0-9TZ:-]*//' > $@

README.md: FORCE golangci-lint
	go run ./scripts/gen_readme/main.go

pkg/logutils/mock_logutils/mock_log.go: pkg/logutils/log.go
	go generate ./...

go.mod: FORCE
	go mod tidy
	go mod verify
go.sum: go.mod

.PHONY: vendor
vendor: go.mod go.sum
	go mod vendor
