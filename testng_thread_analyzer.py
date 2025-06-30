#!/usr/bin/env python3
"""
XML Test Suite Thread Count Analyzer
Analyzes TestNG XML suite files and generates an HTML report showing thread counts.
"""

import xml.etree.ElementTree as ET
import os
import sys
from pathlib import Path
import argparse

def parse_suite_file(file_path):
    """
    Parse a single XML suite file and extract thread count information.
    
    Args:
        file_path (str): Path to the XML file
        
    Returns:
        dict: Dictionary containing file info and thread count
    """
    try:
        tree = ET.parse(file_path)
        root = tree.getroot()
        
        # Find the suite element
        suite_element = root if root.tag == 'suite' else root.find('.//suite')
        
        if suite_element is not None:
            suite_name = suite_element.get('name', 'Unknown Suite')
            thread_count_attr = suite_element.get('thread-count')
            parallel_attr = suite_element.get('parallel')
            
            # Set parallel value (default to "none" if not set)
            parallel_value = parallel_attr if parallel_attr is not None else "none"
            
            # Set thread count display value
            if thread_count_attr is not None:
                thread_count_display = thread_count_attr
                thread_count_int = int(thread_count_attr)
            else:
                thread_count_display = "default"
                thread_count_int = None
            
            # Calculate actual threads that will be used
            if parallel_value == "none":
                # No parallel execution - always 1 thread regardless of thread-count setting
                actual_threads = 1
            else:
                # Parallel execution enabled
                if thread_count_int is not None:
                    actual_threads = thread_count_int
                else:
                    # Default thread count when parallel is enabled but thread-count not specified
                    actual_threads = 5
            
            return {
                'file_path': file_path,
                'suite_name': suite_name,
                'thread_count_display': thread_count_display,
                'parallel_value': parallel_value,
                'actual_threads': actual_threads,
                'exists': True
            }
        else:
            return {
                'file_path': file_path,
                'suite_name': 'No Suite Found',
                'thread_count_display': '0',
                'parallel_value': 'none',
                'actual_threads': 0,
                'exists': False
            }
            
    except ET.ParseError as e:
        return {
            'file_path': file_path,
            'suite_name': f'Parse Error: {str(e)}',
            'thread_count_display': '0',
            'parallel_value': 'none',
            'actual_threads': 0,
            'exists': False
        }
    except FileNotFoundError:
        return {
            'file_path': file_path,
            'suite_name': 'File Not Found',
            'thread_count_display': '0',
            'parallel_value': 'none',
            'actual_threads': 0,
            'exists': False
        }
    except Exception as e:
        return {
            'file_path': file_path,
            'suite_name': f'Error: {str(e)}',
            'thread_count_display': '0',
            'parallel_value': 'none',
            'actual_threads': 0,
            'exists': False
        }

def analyze_main_suite(main_file_path):
    """
    Analyze the main suite file and extract suite-files information.
    
    Args:
        main_file_path (str): Path to the main XML suite file
        
    Returns:
        dict: Analysis results
    """
    try:
        tree = ET.parse(main_file_path)
        root = tree.getroot()
        
        # Get main suite info
        main_suite_name = root.get('name', 'Unknown Suite')
        main_thread_count_attr = root.get('thread-count')
        main_parallel_attr = root.get('parallel')
        
        # Set main suite parallel value
        main_parallel_value = main_parallel_attr if main_parallel_attr is not None else "none"
        
        # Set main suite thread count display
        if main_thread_count_attr is not None:
            main_thread_count_display = main_thread_count_attr
            main_thread_count_int = int(main_thread_count_attr)
        else:
            main_thread_count_display = "default"
            main_thread_count_int = None
        
        # Calculate main suite actual threads
        if main_parallel_value == "none":
            main_actual_threads = 1
        else:
            main_actual_threads = main_thread_count_int if main_thread_count_int is not None else 5
        
        # Find all suite-file elements
        suite_files = []
        suite_files_elements = root.findall('.//suite-file')
        
        base_dir = os.path.dirname(main_file_path)
        
        for suite_file_elem in suite_files_elements:
            suite_file_path = suite_file_elem.get('path')
            if suite_file_path:
                # Resolve relative path
                full_path = os.path.join(base_dir, suite_file_path)
                suite_info = parse_suite_file(full_path)
                suite_files.append(suite_info)
        
        return {
            'main_file': main_file_path,
            'main_suite_name': main_suite_name,
            'main_thread_count_display': main_thread_count_display,
            'main_parallel_value': main_parallel_value,
            'main_actual_threads': main_actual_threads,
            'suite_files': suite_files,
            'total_actual_threads': sum(sf['actual_threads'] for sf in suite_files if sf['exists'])
        }
        
    except Exception as e:
        return {
            'error': f'Error analyzing main suite file: {str(e)}',
            'main_file': main_file_path,
            'main_suite_name': 'Error',
            'main_thread_count_display': '0',
            'main_parallel_value': 'none',
            'main_actual_threads': 0,
            'suite_files': [],
            'total_actual_threads': 0
        }

def generate_html_report(analysis_result, output_file='thread_count_report.html'):
    """
    Generate an HTML report from the analysis results.
    
    Args:
        analysis_result (dict): Results from analyze_main_suite
        output_file (str): Output HTML file path
    """
    html_template = """<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>TestNG Suite Thread Count Report</title>
    <style>
        body {{ font-family: Arial, sans-serif; margin: 20px; background-color: #f5f5f5; }}
        .container {{ max-width: 1400px; margin: 0 auto; background-color: white; padding: 20px; border-radius: 8px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }}
        h1 {{ color: #333; border-bottom: 2px solid #4CAF50; padding-bottom: 10px; }}
        h2 {{ color: #555; margin-top: 30px; }}
        .main-info {{ background-color: #e8f5e8; padding: 15px; border-radius: 5px; margin: 20px 0; }}
        .summary {{ background-color: #fff3cd; padding: 15px; border-radius: 5px; margin: 20px 0; border-left: 4px solid #ffc107; }}
        table {{ width: 100%; border-collapse: collapse; margin: 20px 0; }}
        th, td {{ border: 1px solid #ddd; padding: 12px; text-align: left; }}
        th {{ background-color: #4CAF50; color: white; }}
        tr:nth-child(even) {{ background-color: #f2f2f2; }}
        .error {{ color: #d32f2f; }}
        .success {{ color: #388e3c; }}
        .thread-count {{ font-weight: bold; color: #1976d2; }}
        .parallel-value {{ font-weight: bold; color: #e91e63; }}
        .actual-threads {{ font-weight: bold; color: #ff9800; }}
        .file-path {{ font-family: monospace; font-size: 0.9em; color: #666; }}
        .default-value {{ font-style: italic; color: #888; }}
    </style>
</head>
<body>
    <div class="container">
        <h1>🧵 TestNG Suite Thread Count Analysis Report</h1>
        
        <div class="main-info">
            <h2>📁 Main Suite File</h2>
            <p><strong>File:</strong> <span class="file-path">{main_file}</span></p>
            <p><strong>Suite Name:</strong> {main_suite_name}</p>
            <p><strong>Thread Count:</strong> <span class="thread-count">{main_thread_count_display}</span></p>
            <p><strong>Parallel:</strong> <span class="parallel-value">{main_parallel_value}</span></p>
            <p><strong>Actual Threads Used:</strong> <span class="actual-threads">{main_actual_threads}</span></p>
        </div>
        
        <div class="summary">
            <h2>📊 Summary</h2>
            <p><strong>Total Suite Files:</strong> {total_files}</p>
            <p><strong>Successfully Parsed:</strong> <span class="success">{successful_files}</span></p>
            <p><strong>Errors/Not Found:</strong> <span class="error">{error_files}</span></p>
            <p><strong>Total Actual Threads (All Suites):</strong> <span class="actual-threads">{total_actual_threads}</span></p>
        </div>
        
        <h2>📋 Suite Files Detail</h2>
        <table>
            <thead>
                <tr>
                    <th>File Path</th>
                    <th>Suite Name</th>
                    <th>Parallel</th>
                    <th>Thread Count</th>
                    <th>Actual Threads</th>
                    <th>Status</th>
                </tr>
            </thead>
            <tbody>
                {suite_files_rows}
            </tbody>
        </table>
        
        <div style="margin-top: 30px; padding-top: 20px; border-top: 1px solid #ddd; color: #666; font-size: 0.9em;">
            <p>Report generated on: {timestamp}</p>
            <p><strong>Notes:</strong></p>
            <ul>
                <li>When parallel="none" (or not set), only 1 thread is used regardless of thread-count setting</li>
                <li>When parallel execution is enabled but thread-count is not specified, TestNG defaults to 5 threads</li>
                <li>"default" indicates the thread-count attribute was not explicitly set in the XML</li>
            </ul>
        </div>
    </div>
</body>
</html>"""
    
    # Generate table rows for suite files
    suite_files_rows = ""
    for sf in analysis_result['suite_files']:
        status = "✅ Success" if sf['exists'] else "❌ Error"
        status_class = "success" if sf['exists'] else "error"
        
        # Style the thread count display
        thread_count_class = "default-value" if sf['thread_count_display'] == "default" else "thread-count"
        
        suite_files_rows += f"""
                <tr>
                    <td><span class="file-path">{sf['file_path']}</span></td>
                    <td>{sf['suite_name']}</td>
                    <td><span class="parallel-value">{sf['parallel_value']}</span></td>
                    <td><span class="{thread_count_class}">{sf['thread_count_display']}</span></td>
                    <td><span class="actual-threads">{sf['actual_threads']}</span></td>
                    <td><span class="{status_class}">{status}</span></td>
                </tr>"""
    
    # Calculate summary stats
    total_files = len(analysis_result['suite_files'])
    successful_files = sum(1 for sf in analysis_result['suite_files'] if sf['exists'])
    error_files = total_files - successful_files
    
    # Get current timestamp
    from datetime import datetime
    timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    
    # Style main thread count display
    main_thread_count_display = analysis_result['main_thread_count_display']
    if main_thread_count_display == "default":
        main_thread_count_display = '<span class="default-value">default</span>'
    else:
        main_thread_count_display = f'<span class="thread-count">{main_thread_count_display}</span>'
    
    # Fill in the template
    html_content = html_template.format(
        main_file=analysis_result['main_file'],
        main_suite_name=analysis_result['main_suite_name'],
        main_thread_count_display=main_thread_count_display,
        main_parallel_value=analysis_result['main_parallel_value'],
        main_actual_threads=analysis_result['main_actual_threads'],
        total_files=total_files,
        successful_files=successful_files,
        error_files=error_files,
        total_actual_threads=analysis_result['total_actual_threads'],
        suite_files_rows=suite_files_rows,
        timestamp=timestamp
    )
    
    # Write the HTML file
    with open(output_file, 'w', encoding='utf-8') as f:
        f.write(html_content)
    
    print(f"HTML report generated: {output_file}")

def main():
    parser = argparse.ArgumentParser(description='Analyze TestNG XML suite files for thread count information')
    parser.add_argument('xml_file', help='Path to the main XML suite file')
    parser.add_argument('-o', '--output', default='thread_count_report.html', 
                       help='Output HTML file (default: thread_count_report.html)')
    
    args = parser.parse_args()
    
    if not os.path.exists(args.xml_file):
        print(f"Error: File '{args.xml_file}' not found.")
        sys.exit(1)
    
    print(f"Analyzing XML suite file: {args.xml_file}")
    
    # Analyze the main suite file
    analysis_result = analyze_main_suite(args.xml_file)
    
    if 'error' in analysis_result:
        print(f"Error: {analysis_result['error']}")
        sys.exit(1)
    
    # Generate HTML report
    generate_html_report(analysis_result, args.output)
    
    # Print summary to console
    print(f"\nAnalysis Summary:")
    print(f"Main Suite: {analysis_result['main_suite_name']}")
    print(f"  Thread Count: {analysis_result['main_thread_count_display']}")
    print(f"  Parallel: {analysis_result['main_parallel_value']}")
    print(f"  Actual Threads: {analysis_result['main_actual_threads']}")
    print(f"Suite Files Found: {len(analysis_result['suite_files'])}")
    print(f"Total Actual Threads (All Suites): {analysis_result['total_actual_threads']}")

if __name__ == '__main__':
    main()