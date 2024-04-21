# Adapted from https://www.thapaliya.com/en/writings/well-documented-makefiles/
.PHONY: help
help: ## Display this help and any documented user-facing targets. Other undocumented targets may be present in the Makefile.
help:
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make <target>\n\nTargets:\n"} /^[a-zA-Z_-]+:.*?##/ { printf "  %-45s %s\n", $$1, $$2 }' $(MAKEFILE_LIST)

.DEFAULT_GOAL := all
.PHONY: all clean-protos protos
.PHONY: clean-protos

SHELL = /usr/bin/env bash -o pipefail

#############
# Variables #
#############

# We don't want find to scan inside a bunch of directories, to accelerate the
# 'make: Entering directory '/src/loki' phase.
DONT_FIND := -name .swiftpm -prune -o -name .build -prune -o

# Protobuf files
PROTO_DEFS := $(shell find . $(DONT_FIND) -type f -name '*.proto' -print)
PROTO_SWIFTS := $(patsubst %.proto,%.pb.swift,$(PROTO_DEFS))

################
# Main Targets #
################
all: protos ## run all (clean-protos, protos)

# This is really a check for the CI to make sure generated files are built and checked in manually
check-generated-files: protos
	@if ! (git diff --exit-code $(PROTO_DEFS) $(PROTO_SWIFTS)); then \
		echo "\nChanges found in generated files"; \
		echo "Run 'make check-generated-files' and commit the changes to fix this error."; \
		echo "If you are actively developing these files you can ignore this error"; \
		echo "(Don't forget to check in the generated files when finished)\n"; \
		exit 1; \
	fi

#########
# Clean #
#########

clean-protos: ## remove swift protos
	rm -rf $(PROTO_SWIFTS)

#############
# Protobufs #
#############

protos: clean-protos $(PROTO_SWIFTS) ## regenerate swift protos

%.pb.swift:
	protoc --swift_out=. $(patsubst %.pb.swift,%.proto,$@)
