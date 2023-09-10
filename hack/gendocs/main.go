package main

import (
	"encoding/json"
	"fmt"
	"log"
	"os"
	"path"
	"path/filepath"
	"strings"
	"text/template"
)

type RiskItem struct {
	ID          string   `json:"id,omitempty"`
	Name        string   `json:"name,omitempty"`
	Description string   `json:"description,omitempty"`
	Pattern     string   `json:"pattern,omitempty"`
	Samples     []Sample `json:"samples,omitempty"`
}

type Sample struct {
	Name  string `json:"name,omitempty"`
	Start int    `json:"start,omitempty"`
	End   int    `json:"end,omitempty"`
}

const itemTemplate = `
# {{ .ID }} {{ .Name }}
## Description

{{ .Description }}

## Pattern

{{ .Pattern }}

## Samples
{{ range .Samples }}
  {{- if eq 0 .Start .End }} 
- [{{ .Name }}](https://github.com/cryptousersecurity/token-security-benchmark/blob/main/src/{{ $.ID }}/samples/{{ .Name }})
  {{- else }}
- [{{ .Name }}](https://github.com/cryptousersecurity/token-security-benchmark/blob/main/src/{{ $.ID }}/samples/{{ .Name }}#L{{ .Start }}-L{{ .End }})
  {{- end }}
{{- end }}
`

func main() {
	src := "./src"
	entries, err := os.ReadDir(src)
	if err != nil {
		log.Fatalf("failed to read directory: %v", err)
	}

	for _, entry := range entries {
		if entry.IsDir() && strings.HasPrefix(entry.Name(), "TSB-") {
			itemPath := filepath.Join(src, entry.Name())
			item, err := parseRiskItem(itemPath)
			if err != nil {
				log.Fatalf("failed to parse risk item: %v", err)
			}
			t, err := template.New(item.ID).Parse(itemTemplate)
			if err != nil {
				log.Fatalf("failed to parse template: %v", err)
			}
			f, err := os.Create(filepath.Join("./docs", fmt.Sprintf("%s.md", item.ID)))
			if err != nil {
				log.Fatalf("failed to create the docs file for risk item: %s, %v", item.ID, err)
			}
			if err := t.Execute(f, &item); err != nil {
				log.Fatalf("failed to execute the risk item tempalte: %s, %v", item.ID, err)
			}
		}
	}
}

func validateRiskItem(item RiskItem) error {
	if item.ID == "" {
		return fmt.Errorf("missing risk item id")
	}
	if item.Name == "" {
		return fmt.Errorf("missing risk item name")
	}
	if item.Description == "" {
		return fmt.Errorf("missing risk item description")
	}
	var errs []string
	for _, sample := range item.Samples {
		if err := validateSample(sample); err != nil {
			errs = append(errs, err.Error())
		}
	}
	if len(errs) != 0 {
		return fmt.Errorf(strings.Join(errs, "\n"))
	}
	return nil
}

func validateSample(sample Sample) error {
	if sample.Name == "" {
		return fmt.Errorf("missing sample name")
	}
	if sample.Start == 0 && sample.Start == sample.End {
		return nil
	}
	if sample.Start <= 0 {
		return fmt.Errorf("start line should be positive integer, sample: %s", sample.Name)
	}
	if sample.End <= sample.Start {
		return fmt.Errorf("end line number should be bigger than start line number, sample: %s", sample.Name)
	}
	return nil
}

func parseRiskItem(itemPath string) (*RiskItem, error) {
	fileData, err := os.ReadFile(path.Join(itemPath, "metadata.json"))
	if err != nil {
		return nil, fmt.Errorf("failed to read metadata.json: %w", err)
	}
	var item RiskItem
	if err := json.Unmarshal(fileData, &item); err != nil {
		return nil, fmt.Errorf("failed to unmarshal metadata.json to risk item: %w", err)
	}
	if err := validateRiskItem(item); err != nil {
		return nil, fmt.Errorf("failed to validate risk item: %w", err)
	}
	patternData, err := os.ReadFile(path.Join(itemPath, "pattern.sol"))
	if err != nil {
		return nil, fmt.Errorf("failed to read pattern.sol: %w", err)
	}
	item.Pattern = "```solidity\n" + string(patternData) + "\n```"
	for _, sample := range item.Samples {
		_, err := os.ReadFile(path.Join(itemPath, "samples", sample.Name))
		if err != nil {
			return nil, fmt.Errorf("failed to read sample file: %s: %w", sample.Name, err)
		}
	}
	return &item, nil
}
