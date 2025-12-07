# JQ script for extracting coupling and complexity metrics analysis
# Processes file-coupling, function-coupling, classes-per-file, and functions-per-file

# Sanitize paths - remove user-specific information
def sanitize_path:
  gsub("C:\\\\Users\\\\[^\\\\]+"; "[USER]")
  | gsub("\\\\OneDrive\\\\[^\\\\]+\\\\[^\\\\]+\\\\[^\\\\]+\\\\Metrics2"; "[WORKSPACE]")
  | gsub("\\\\repositories\\\\"; "\\repos\\");

# Extract filename from full path
def extract_filename:
  split("\\") | last;

# Process file coupling metrics
def process_file_coupling:
  .result
  | to_entries
  | map({
      file: (.key | sanitize_path),
      filename: (.key | extract_filename),
      fanOut: (.value.fanOut | length),
      fanIn: (.value.fanIn | length),
      totalCoupling: ((.value.fanOut | length) + (.value.fanIn | length))
    })
  | sort_by(-.totalCoupling);

# Calculate file coupling statistics
def file_coupling_stats($data):
  {
    totalFiles: ($data | length),
    filesWithCoupling: ($data | map(select(.totalCoupling > 0)) | length),
    highCouplingFiles: ($data | map(select(.totalCoupling > 20)) | length),
    averageFanOut: (($data | map(.fanOut) | add) / ($data | length)),
    averageFanIn: (($data | map(.fanIn) | add) / ($data | length)),
    maxCoupling: ($data | map(.totalCoupling) | max),
    top10MostCoupled: ($data | sort_by(-.totalCoupling) | .[0:10] | map({
      filename: .filename,
      fanOut: .fanOut,
      fanIn: .fanIn,
      total: .totalCoupling
    }))
  };

# Process functions per file metrics
def process_functions_per_file:
  .result
  | to_entries
  | map({
      file: (.key | sanitize_path),
      filename: (.key | extract_filename),
      functionCount: (.value | keys | length)
    })
  | sort_by(-.functionCount);

# Calculate functions per file statistics
def functions_per_file_stats($data):
  {
    totalFiles: ($data | length),
    filesWithFunctions: ($data | map(select(.functionCount > 0)) | length),
    highFunctionCountFiles: ($data | map(select(.functionCount > 10)) | length),
    veryHighFunctionCountFiles: ($data | map(select(.functionCount > 20)) | length),
    averageFunctionsPerFile: (($data | map(.functionCount) | add) / ($data | length)),
    maxFunctions: ($data | map(.functionCount) | max),
    top10LargestFiles: ($data | sort_by(-.functionCount) | .[0:10] | map({
      filename: .filename,
      functions: .functionCount
    }))
  };

# Main output structure
if .name == "File Coupling" then
  {
    metricType: "file-coupling",
    data: process_file_coupling,
    statistics: file_coupling_stats(process_file_coupling)
  }
elif .name == "Functions Per File" then
  {
    metricType: "functions-per-file",
    data: process_functions_per_file,
    statistics: functions_per_file_stats(process_functions_per_file)
  }
else
  {
    metricType: "unknown",
    name: .name,
    description: .description
  }
end
