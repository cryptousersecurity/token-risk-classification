.PHONY: generate-docs
generate-docs:
	@cp README.md docs/index.md
	@cp CONTRIBUTING.md docs/contributing.md
	@go run hack/gendocs/main.go