# README: Error Extraction and Analysis Scripts

## Overview
Collection of scripts for extracting and analyzing error information from metrics analysis results. These scripts sanitize paths, group errors by pattern, and export data to Excel format.

## Files

### 1. `extract-errors.jq`
JQ script for processing JSON error files. Sanitizes user-specific paths and groups errors by pattern.

**Features:**
- Removes user-specific directory information
- Groups similar errors together
- Extracts error patterns (TypeError, SyntaxError, etc.)
- Limits examples to first 3 occurrences per pattern

### 2. `extract-single-project.ps1`
PowerShell script to extract analysis for a single project.

**Usage:**
```powershell
.\extract-single-project.ps1 -ProjectName "P1-googleapis"
```

**Output:**
- Creates `analysis-summary.json` in project's results directory
- Contains error summaries and metrics complexity data

### 3. `extract-with-jq.ps1`
PowerShell script using jq for single project extraction.

**Requirements:**
- jq must be installed (https://stedolan.github.io/jq/download/)
- Windows: `scoop install jq` or `choco install jq`

**Usage:**
```powershell
.\extract-with-jq.ps1 -ProjectName "P1-googleapis"
```

**Output:**
- Creates `analysis-jq.json` in project's results directory

### 4. `extract-all-projects.ps1`
Processes all projects and generates consolidated Excel report.

**Usage:**
```powershell
.\extract-all-projects.ps1
```

**Output:**
- `analysis-output/all-projects-analysis.json` - Consolidated JSON
- `analysis-output/metrics-analysis.xlsx` - Excel report with multiple sheets
- CSV fallback if ImportExcel module not available

**Excel Sheets:**
- Summary: Project overview with error counts
- Error Details: Detailed error patterns per project

### 5. `extract-all-with-jq.ps1`
Processes all projects using jq and generates comprehensive Excel report.

**Requirements:**
- jq installed
- Optional: ImportExcel module for Excel export

**Usage:**
```powershell
.\extract-all-with-jq.ps1
```

**Output:**
- `analysis-output/all-projects-jq-analysis.json` - Consolidated JSON
- `analysis-output/metrics-analysis-jq.xlsx` - Excel report

**Excel Sheets:**
- Summary: Project statistics and error rates
- Error Details: All errors with examples per project
- Error Patterns: Aggregated error patterns across all projects

## Installation

### Required Tools

**jq (for jq-based scripts):**
```powershell
# Using Scoop
scoop install jq

# Using Chocolatey
choco install jq
```

**ImportExcel Module (for Excel export):**
```powershell
Install-Module -Name ImportExcel -Scope CurrentUser
```

## Workflow

### Quick Start (Without jq)
```powershell
# Extract all projects and generate Excel
.\extract-all-projects.ps1
```

### Recommended (With jq)
```powershell
# Install jq first
scoop install jq

# Extract all projects with jq processing
.\extract-all-with-jq.ps1
```

### Single Project Analysis
```powershell
# Using PowerShell only
.\extract-single-project.ps1 -ProjectName "P1-googleapis"

# Using jq
.\extract-with-jq.ps1 -ProjectName "P1-googleapis"
```

## Output Structure

### analysis-summary.json / analysis-jq.json
```json
{
  "project": {
    "id": "P1",
    "name": "googleapis",
    "analyzedAt": "2025-12-07T08:23:25.517Z",
    "totalFiles": 1301
  },
  "errors": {
    "summary": {
      "totalFileErrors": 0,
      "totalParseErrors": 0,
      "totalMetricErrors": 0,
      "totalTraverseErrors": 295,
      "total": 295
    },
    "details": {
      "traverse": [
        {
          "pattern": "TypeError: Cannot read properties of undefined (reading 'getAPI')",
          "occurrences": 250,
          "examples": ["...", "...", "..."]
        }
      ]
    }
  }
}
```

## Path Sanitization

User-specific paths are sanitized to protect privacy:
- `C:\Users\username` → `[USER]`
- Full workspace path → `[WORKSPACE]`
- `\repositories\` → `\repos\`

## Error Grouping

Errors are grouped by pattern to identify systemic issues:
- Extracts error type (TypeError, SyntaxError, etc.)
- Groups by error message
- Shows occurrence count
- Provides up to 3 examples per pattern

## Performance

- Single project: ~1-2 seconds
- All projects (40+): ~30-60 seconds
- Excel generation: Additional 5-10 seconds

## Troubleshooting

**"jq is not installed"**
```powershell
scoop install jq
```

**"ImportExcel module not found"**
```powershell
Install-Module -Name ImportExcel -Scope CurrentUser
```
Scripts will create CSV files as fallback.

**"Project path not found"**
Ensure project exists in `results/` directory with proper structure.

## Data Privacy

All scripts automatically sanitize:
- User directory paths
- Absolute file paths
- System-specific information

Only relative paths within repositories are preserved for context.
