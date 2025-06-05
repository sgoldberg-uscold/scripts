#!/bin/bash

# PDF Comparison Script with Enhanced HTML Output
# Compares PDFs from two directories and creates beautiful HTML diff reports

# Check if correct number of arguments provided
if [ $# -ne 2 ]; then
    echo "Usage: $0 <directory1> <directory2>"
    echo "Example: $0 ./old_reports ./new_reports"
    echo ""
    echo "This script will:"
    echo "- Compare PDFs with the same name from both directories"
    echo "- Generate beautiful HTML diff reports"
    echo "- Create an index page linking all comparisons"
    exit 1
fi

DIR1="$1"
DIR2="$2"

# Check if directories exist
if [ ! -d "$DIR1" ]; then
    echo "Error: Directory '$DIR1' does not exist."
    exit 1
fi

if [ ! -d "$DIR2" ]; then
    echo "Error: Directory '$DIR2' does not exist."
    exit 1
fi

# Check if pdftotext is available
if ! command -v pdftotext &> /dev/null; then
    echo "Error: pdftotext is not installed."
    echo "Install it with: brew install poppler"
    exit 1
fi

echo "Starting PDF comparison with HTML output..."
echo "Directory 1: $DIR1"
echo "Directory 2: $DIR2"
echo "================================="

# Create output directory
OUTPUT_DIR="pdf_comparison_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$OUTPUT_DIR"

# Create temporary directory for extracted text
TEMP_DIR=$(mktemp -d)
trap "rm -rf $TEMP_DIR" EXIT

# Arrays to track results
declare -a identical_files
declare -a different_files
declare -a missing_files

# Create CSS for better styling
cat > "$OUTPUT_DIR/style.css" << 'EOF'
body {
    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
    line-height: 1.6;
    margin: 0;
    padding: 20px;
    background-color: #f5f5f5;
}

.container {
    max-width: 1200px;
    margin: 0 auto;
    background: white;
    padding: 30px;
    border-radius: 8px;
    box-shadow: 0 2px 10px rgba(0,0,0,0.1);
}

.header {
    background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
    color: white;
    padding: 20px;
    margin: -30px -30px 30px -30px;
    border-radius: 8px 8px 0 0;
}

.header h1 {
    margin: 0;
    font-size: 24px;
}

.header p {
    margin: 5px 0 0 0;
    opacity: 0.9;
}

.diff-container {
    background: #f8f9fa;
    border-radius: 5px;
    overflow-x: auto;
    margin: 20px 0;
}

.diff-line {
    padding: 2px 10px;
    font-family: 'Monaco', 'Menlo', 'Ubuntu Mono', monospace;
    font-size: 13px;
    white-space: pre-wrap;
    border-left: 3px solid transparent;
}

.diff-added {
    background-color: #d1ecf1;
    border-left-color: #28a745;
    color: #155724;
}

.diff-removed {
    background-color: #f8d7da;
    border-left-color: #dc3545;
    color: #721c24;
}

.diff-unchanged {
    color: #6c757d;
    background-color: #ffffff;
}

.diff-context {
    background-color: #fff3cd;
    border-left-color: #ffc107;
    color: #856404;
    font-weight: bold;
}

.status-identical {
    color: #28a745;
    font-weight: bold;
}

.status-different {
    color: #dc3545;
    font-weight: bold;
}

.stats {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
    gap: 15px;
    margin: 20px 0;
}

.stat-card {
    background: white;
    padding: 15px;
    border-radius: 5px;
    border-left: 4px solid #667eea;
    box-shadow: 0 1px 3px rgba(0,0,0,0.1);
}

.back-link {
    display: inline-block;
    background: #667eea;
    color: white;
    padding: 8px 15px;
    text-decoration: none;
    border-radius: 4px;
    margin-bottom: 20px;
    font-size: 14px;
}

.back-link:hover {
    background: #5a6fd8;
}

.file-list {
    list-style: none;
    padding: 0;
}

.file-list li {
    padding: 10px;
    margin: 5px 0;
    background: #f8f9fa;
    border-radius: 4px;
    border-left: 4px solid #28a745;
}

.file-list li.different {
    border-left-color: #dc3545;
}

.file-list li.missing {
    border-left-color: #ffc107;
}

.file-list a {
    text-decoration: none;
    color: #495057;
    font-weight: 500;
}

.file-list a:hover {
    color: #667eea;
}

.no-differences {
    text-align: center;
    padding: 40px;
    color: #28a745;
    font-size: 18px;
    background: #d4edda;
    border-radius: 5px;
    margin: 20px 0;
}
EOF

# Process each PDF in directory 1
for pdf1 in "$DIR1"/*.pdf; do
    # Check if any PDF files exist
    if [ ! -f "$pdf1" ]; then
        echo "No PDF files found in $DIR1"
        break
    fi
    
    # Get just the filename without path
    filename=$(basename "$pdf1")
    base_name="${filename%.pdf}"
    
    # Check if corresponding file exists in directory 2
    pdf2="$DIR2/$filename"
    
    if [ ! -f "$pdf2" ]; then
        echo "⚠️  Skipping $filename - not found in $DIR2"
        missing_files+=("$filename")
        continue
    fi
    
    echo "📄 Processing: $filename"
    
    # Extract text from both PDFs
    temp1="$TEMP_DIR/${base_name}_1.txt"
    temp2="$TEMP_DIR/${base_name}_2.txt"
    
    pdftotext "$pdf1" "$temp1" 2>/dev/null
    pdftotext "$pdf2" "$temp2" 2>/dev/null
    
    # Check if text extraction was successful
    if [ ! -f "$temp1" ] || [ ! -f "$temp2" ]; then
        echo "❌ Error extracting text from $filename"
        continue
    fi
    
    # Generate HTML comparison
    html_file="$OUTPUT_DIR/${base_name}.html"
    
    # Check if files are identical
    if cmp -s "$temp1" "$temp2"; then
        echo "✅ Files are identical: $filename"
        identical_files+=("$filename")
        
        # Create simple identical file report
        cat > "$html_file" << EOF
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>PDF Comparison: $filename</title>
    <link rel="stylesheet" href="style.css">
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>📄 $filename</h1>
            <p>Generated: $(date)</p>
        </div>
        
        <a href="index.html" class="back-link">← Back to Index</a>
        
        <div class="no-differences">
            <h2>✅ Files are Identical</h2>
            <p>No differences found between the two versions.</p>
        </div>
        
        <div class="stats">
            <div class="stat-card">
                <strong>Source 1:</strong><br>
                <code>$(basename "$DIR1")</code>
            </div>
            <div class="stat-card">
                <strong>Source 2:</strong><br>
                <code>$(basename "$DIR2")</code>
            </div>
        </div>
    </div>
</body>
</html>
EOF
    else
        echo "🔍 Differences found: $filename"
        different_files+=("$filename")
        
        # Create detailed diff report
        cat > "$html_file" << EOF
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>PDF Comparison: $filename</title>
    <link rel="stylesheet" href="style.css">
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>📄 $filename</h1>
            <p>Generated: $(date)</p>
        </div>
        
        <a href="index.html" class="back-link">← Back to Index</a>
        
        <div class="stats">
            <div class="stat-card">
                <strong>Source 1:</strong><br>
                <code>$(basename "$DIR1")</code>
            </div>
            <div class="stat-card">
                <strong>Source 2:</strong><br>
                <code>$(basename "$DIR2")</code>
            </div>
            <div class="stat-card">
                <strong>Status:</strong><br>
                <span class="status-different">Differences Found</span>
            </div>
        </div>
        
        <h2>Differences</h2>
        <p><strong>Legend:</strong> <span class="diff-removed">Red = Removed</span> | <span class="diff-added">Green = Added</span> | <span class="diff-unchanged">Gray = Unchanged</span></p>
        
        <div class="diff-container">
EOF
        
        # Generate unified diff and convert to HTML
        diff -u "$temp1" "$temp2" | while IFS= read -r line; do
            if [[ $line == @@* ]]; then
                echo "            <div class=\"diff-line diff-context\">$line</div>" >> "$html_file"
            elif [[ $line == +* ]]; then
                escaped_line=$(echo "$line" | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g')
                echo "            <div class=\"diff-line diff-added\">$escaped_line</div>" >> "$html_file"
            elif [[ $line == -* ]]; then
                escaped_line=$(echo "$line" | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g')
                echo "            <div class=\"diff-line diff-removed\">$escaped_line</div>" >> "$html_file"
            else
                escaped_line=$(echo "$line" | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g')
                echo "            <div class=\"diff-line diff-unchanged\">$escaped_line</div>" >> "$html_file"
            fi
        done
        
        cat >> "$html_file" << EOF
        </div>
    </div>
</body>
</html>
EOF
    fi
done

# Create index page
cat > "$OUTPUT_DIR/index.html" << EOF
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>PDF Comparison Report</title>
    <link rel="stylesheet" href="style.css">
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>📊 PDF Comparison Report</h1>
            <p>Generated: $(date)</p>
            <p>Comparing: $(basename "$DIR1") ↔ $(basename "$DIR2")</p>
        </div>
        
        <div class="stats">
            <div class="stat-card">
                <h3>✅ Identical Files</h3>
                <strong>${#identical_files[@]}</strong>
            </div>
            <div class="stat-card">
                <h3>❌ Different Files</h3>
                <strong>${#different_files[@]}</strong>
            </div>
            <div class="stat-card">
                <h3>⚠️ Missing Files</h3>
                <strong>${#missing_files[@]}</strong>
            </div>
        </div>
EOF

if [ ${#different_files[@]} -gt 0 ]; then
    cat >> "$OUTPUT_DIR/index.html" << EOF
        <h2>Files with Differences</h2>
        <ul class="file-list">
EOF
    for file in "${different_files[@]}"; do
        base_name="${file%.pdf}"
        echo "            <li class=\"different\"><a href=\"${base_name}.html\">$file</a></li>" >> "$OUTPUT_DIR/index.html"
    done
    cat >> "$OUTPUT_DIR/index.html" << EOF
        </ul>
EOF
fi

if [ ${#identical_files[@]} -gt 0 ]; then
    cat >> "$OUTPUT_DIR/index.html" << EOF
        <h2>Identical Files</h2>
        <ul class="file-list">
EOF
    for file in "${identical_files[@]}"; do
        base_name="${file%.pdf}"
        echo "            <li><a href=\"${base_name}.html\">$file</a></li>" >> "$OUTPUT_DIR/index.html"
    done
    cat >> "$OUTPUT_DIR/index.html" << EOF
        </ul>
EOF
fi

if [ ${#missing_files[@]} -gt 0 ]; then
    cat >> "$OUTPUT_DIR/index.html" << EOF
        <h2>Missing Files</h2>
        <ul class="file-list">
EOF
    for file in "${missing_files[@]}"; do
        echo "            <li class=\"missing\">$file (not found in $(basename "$DIR2"))</li>" >> "$OUTPUT_DIR/index.html"
    done
    cat >> "$OUTPUT_DIR/index.html" << EOF
        </ul>
EOF
fi

cat >> "$OUTPUT_DIR/index.html" << EOF
    </div>
</body>
</html>
EOF

echo "================================="
echo "✅ HTML comparison complete!"
echo "📊 Files processed: $((${#identical_files[@]} + ${#different_files[@]}))"
echo "📁 Report saved in: $OUTPUT_DIR"
echo ""
echo "🌐 Open in browser:"
echo "   open '$OUTPUT_DIR/index.html'"

# Automatically open in default browser
if command -v open &> /dev/null; then
    echo ""
    echo "🚀 Opening report in browser..."
    open "$OUTPUT_DIR/index.html"
fi