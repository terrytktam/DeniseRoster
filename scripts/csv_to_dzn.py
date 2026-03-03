import csv
import sys
import os
import re

def clean_header(header):
    """
    Clean header values by removing empty strings and stripping whitespace
    """
    return [h.strip() for h in header if h and h.strip()]

def clean_value(value, remove_parentheses=False):
    """
    Clean cell values for Minizinc compatibility
    
    Args:
        value: The raw value from CSV
        remove_parentheses: If True, replace parentheses with underscores
    """
    if not value:
        return value
    
    cleaned = value.strip()
    
    if remove_parentheses:
        # Replace parentheses with underscores to make Minizinc-compatible identifiers
        cleaned = re.sub(r'[()]', '_', cleaned)
        # Remove any double underscores
        cleaned = re.sub(r'_+', '_', cleaned)
        # Remove trailing underscore
        cleaned = cleaned.rstrip('_')
    
    return cleaned

def csv_to_minizinc_2d_array(csv_file_path, output_file_path=None, clean_values=False):
    """
    Convert a sparse CSV matrix to Minizinc 2D array format [| ... |]
    
    Expected CSV format:
    - First row: column headers (days) starting from column 2
    - First column: row headers (staff) starting from row 2
    - Empty cells are ignored
    
    Args:
        csv_file_path: Path to input CSV file
        output_file_path: Path to output file (optional)
        clean_values: If True, clean values to be Minizinc-compatible
    
    Returns:
        String containing Minizinc 2D array definition
    """
    
    if not os.path.exists(csv_file_path):
        print(f"Error: File '{csv_file_path}' not found")
        return None
    
    rows = []
    row_count = 0
    col_count = 0
    warnings = []
    
    try:
        with open(csv_file_path, 'r', newline='', encoding='utf-8') as csvfile:
            # Read all rows
            reader = list(csv.reader(csvfile))
            
            if len(reader) < 2:
                print("Error: CSV file must have at least a header row and one data row")
                return None
            
            # Process header row - clean and filter out empty columns
            if len(reader[0]) < 2:
                print("Error: CSV file must have at least one column header")
                return None
            
            # First row contains column headers (days)
            # Skip the first empty cell and filter out any empty headers
            raw_headers = reader[0][1:]
            column_headers = clean_header(raw_headers)
            
            # Also track which original column indices correspond to valid headers
            valid_col_indices = []
            for idx, header in enumerate(raw_headers):
                if header and header.strip():
                    valid_col_indices.append(idx)
            
            col_count = len(column_headers)
            print(f"Found {col_count} valid column headers: {', '.join(column_headers)}")
            
            if col_count == 0:
                print("Error: No valid column headers found")
                return None
            
            # Process data rows
            for row_idx, row in enumerate(reader[1:], 1):
                if len(row) < 1:
                    continue
                    
                row_header = row[0]  # First column is row header (staff)
                if not row_header or not row_header.strip():
                    warnings.append(f"Skipping row {row_idx + 1} - empty row header")
                    continue
                
                row_header = clean_value(row_header, clean_values)
                row_count += 1
                
                # Process only cells that correspond to valid headers
                for valid_idx, col_idx in enumerate(valid_col_indices):
                    # Check if we have data at this column index
                    if col_idx + 1 < len(row):  # +1 because we skipped first column
                        cell_value = row[col_idx + 1]
                        
                        # Check if cell is non-empty
                        if cell_value and cell_value.strip():
                            column_header = column_headers[valid_idx]
                            cell_value_clean = clean_value(cell_value, clean_values)
                            
                            # Check for potential Minizinc issues
                            if '(' in cell_value_clean or ')' in cell_value_clean:
                                if not clean_values:
                                    warnings.append(f"Cell value '{cell_value}' contains parentheses at row {row_idx+1}, col {col_idx+2}")
                            
                            # Add as a row in the 2D array (staff, day, duty)
                            rows.append(f" {row_header}, {column_header}, {cell_value_clean}")
            
            print(f"Processed {row_count} staff rows")
            print(f"Found {len(rows)} non-empty entries")
            
            # Print warnings
            if warnings:
                print("\nWarnings:")
                for w in warnings[:10]:  # Show first 10 warnings
                    print(f"  {w}")
                if len(warnings) > 10:
                    print(f"  ... and {len(warnings) - 10} more warnings")
    
    except Exception as e:
        print(f"Error processing CSV file: {e}")
        return None
    
    # Create the Minizinc 2D array definition in [| ... |] format
    if rows:
        # Join with " |\n" between rows, and add final " |]"
        result = "ward_requested_duties = [|\n" + " |\n".join(rows) + " |];"
    else:
        result = "ward_requested_duties = [| |];"
        print("Warning: No non-empty entries found")
    
    # Write to file if output path provided
    if output_file_path:
        try:
            with open(output_file_path, 'w', encoding='utf-8') as outfile:
                outfile.write(result)
            print(f"Output written to {output_file_path}")
        except Exception as e:
            print(f"Error writing output file: {e}")
    
    return result

def main():
    if len(sys.argv) < 2:
        print("Usage: python csv_to_minizinc.py <input_csv_file> [output_file] [--clean]")
        print("\nOptions:")
        print("  --clean    Clean values by replacing parentheses with underscores")
        print("\nExample CSV format:")
        print("     ,C1,C2,C3")
        print("LYG(1),A,,")
        print("LYG(2),,A,")
        print("BFY(1),A,,")
        print("\nThis will generate:")
        print("ward_requested_duties = [|")
        print(" LYG(1), C1, A |")
        print(" LYG(2), C2, A |")
        print(" BFY(1), C1, A |];")
        return
    
    # Parse arguments
    input_file = sys.argv[1]
    output_file = None
    clean_values = False
    
    for arg in sys.argv[2:]:
        if arg == "--clean":
            clean_values = True
        elif not output_file and not arg.startswith('--'):
            output_file = arg
    
    # If no output file specified, create one based on input filename
    if not output_file:
        base_name = os.path.splitext(input_file)[0]
        output_file = f"{base_name}.dzn"
        print(f"No output file specified, using: {output_file}")
    
    if clean_values:
        print("Cleaning values: parentheses will be replaced with underscores")
    
    result = csv_to_minizinc_2d_array(input_file, output_file, clean_values)
    
    if result:
        print("\nGenerated Minizinc 2D array:")
        # Show first few lines as preview
        lines = result.split('\n')
        for i, line in enumerate(lines[:15]):  # Show first 15 lines
            print(line)
        if len(lines) > 15:
            print(f"... and {len(lines) - 15} more lines")

if __name__ == "__main__":
    main()