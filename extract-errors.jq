# JQ script for extracting valuable information from results JSON files
# Sanitizes user paths and groups errors by pattern

# Extract project metadata
def project_info:
  {
    projectId: .projectId,
    projectName: .projectName,
    analyzedAt: .analyzedAt,
    totalFiles: .totalFiles,
    metricsAvailable: .metricsAvailable
  };

# Sanitize paths - remove user-specific information
def sanitize_path:
  gsub("C:\\\\Users\\\\[^\\\\]+"; "[USER]")
  | gsub("\\\\OneDrive\\\\[^\\\\]+\\\\[^\\\\]+\\\\[^\\\\]+\\\\Metrics2"; "[WORKSPACE]")
  | gsub("\\\\repositories\\\\"; "\\repos\\");

# Extract error message pattern
def error_pattern:
  if test("TypeError: ") then
    (split("TypeError: ")[1] | split(" (")[0] | "TypeError: " + .)
  elif test("SyntaxError: ") then
    (split("SyntaxError: ")[1] | split(" (")[0] | "SyntaxError: " + .)
  elif test("ReferenceError: ") then
    (split("ReferenceError: ")[1] | split(" (")[0] | "ReferenceError: " + .)
  elif test("Error: ") then
    (split("Error: ")[1] | split(" (")[0] | "Error: " + .)
  else
    .
  end;

# Group and summarize errors
def summarize_errors($error_type):
  .[$error_type] as $errors |
  if ($errors | length) > 0 then
    $errors
    | map(sanitize_path)
    | group_by(split(" -> ")[1] // . | error_pattern)
    | map({
        pattern: (.[0] | split(" -> ")[1] // . | error_pattern),
        occurrences: length,
        examples: (.[0:3] | map(sanitize_path))
      })
  else
    []
  end;

# Main extraction
{
  project: (. | project_info),
  errors: {
    summary: {
      totalFileErrors: (.file | length),
      totalParseErrors: (.parse | length),
      totalMetricErrors: (.metric | length),
      totalTraverseErrors: (.traverse | length),
      total: ((.file | length) + (.parse | length) + (.metric | length) + (.traverse | length))
    },
    details: {
      file: summarize_errors("file"),
      parse: summarize_errors("parse"),
      metric: summarize_errors("metric"),
      traverse: summarize_errors("traverse")
    }
  }
}
