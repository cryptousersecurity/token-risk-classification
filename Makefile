.PHONY: generate-docs
generate-docs:
	@cp README.md docs/index.md
ifeq ($(shell uname),Darwin)
	@sed -i '' 's/\.\/CONTRIBUTING\.md/contributing\.md/g' docs/index.md
else
	@sed -i 's/\.\/CONTRIBUTING\.md/contributing\.md/g' docs/index.md
endif
	@cp CONTRIBUTING.md docs/contributing.md
	@go run hack/gendocs/main.go