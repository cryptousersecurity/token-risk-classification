.PHONY: generate-docs
generate-docs:
	@cp README.md docs/index.md
	@go run hack/gendocs/main.go