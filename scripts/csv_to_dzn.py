import csv

# === YOUR CSV DATA HERE - REPLACE THIS WITH YOUR ACTUAL DATA ===
# Make sure to use triple quotes for multi-line strings
csv_data = """,C(1),C(2),C(3),C(4),C(5),C(6),C(7),C(8),C(9),C(10),C(11),C(12),C(13),C(14),C(15),C(16),C(17),C(18),C(19),C(20),C(21),C(22),C(23),C(24),C(25),C(26),C(27),C(28),X(1),X(2)
LYG(1),,,,,,,,,,,,,,,O,O,,,,,,,,,,,O,,,
LYG(2),O,,,,,,,,,,,O,O,,,,,,,,,,,,,,,,,
LYG(3),,,,,,,,,,,,,O,,,,,,,O,O,,,,,,,,,
LYG(4),,,,,,O,O,O,O,,,,,,,,,,,,,,,,,,,,,,,
BFY(1),,,,,O,O,O,O,O,,,,,,,A,,,,,,,,,,,,,,,,
BFY(2),,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
BFY(3),O,,O,,,,,,,,,,,,,,A,,,O,,,,,,,,,,,,
BFY(4),,,,,,,,,,,,,,,,,,,,O,O,O,O,O,,,,,,,,,
DNY(1),,,,,,,,,,,,,,O,O,O,O,O,,,,,,,,,,,,,,,
DNY(2),,,,O,O,O,,,,,,,,,,,,,,O,O,,,,,,,O,,,,,
DNY(3),,,,,,,,,,O,O,O,,,,,,,,,,O,O,,,,,,,,,,
DNY(4),,,,,,,,,,,,,A,O,,,,,,,,,,,,,,O,,,,,
BEE(1),,,,,,,,,,,O,O,,,,,,,,,,,,,,O,,,,,,,
BEE(2),,,O,O,O,O,O,O,,,,,,,,,,,,,,,,,,,,,,,,,
BEE(3),,O,,,,,,,,,,,,,,,,,,,O,O,O,O,,,,,,,,,
BEE(4),,,,,,,,,O,O,O,,P,,,,,,,O,,,,,,,,,,,,,
NGT(1),O,O,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
NGT(2),O,O,,,,,,O,O,,,,,,,,,,,,,,,,,,,,,,,,
NGT(3),,,,,,,,,,,,O,O,O,O,,,,,,,O,O,,,,,,,,,,
NGT(4),,,,,,,,,,,,,,,,,O,O,O,O,O,O,O,O,O,,,,,,,,
"""
# ================================================================

# Parse the CSV data
lines = csv_data.strip().split('\n')
reader = list(csv.reader(lines))

# Get headers (skip the first empty cell)
headers = [h for h in reader[0][1:] if h and h.strip()]

# Process data rows
records = []
for row in reader[1:]:
    if not row or len(row) < 1:
        continue
    
    staff = row[0].strip() if row[0] else ""
    if not staff:
        continue
    
    # Process each cell
    for i, val in enumerate(row[1:]):
        if i < len(headers) and val and val.strip():
            day = headers[i]
            duty = val.strip()
            records.append(f"(staff: {staff}, day: {day}, duty: {duty})")

# Generate the DZN output
if records:
    print()
    print("WARD_REQ_DUTIES = [")
    for i, r in enumerate(records):
        if i < len(records) - 1:
            print(f"  {r},")
        else:
            print(f"  {r}")
    print("];")
else:
    print("WARD_REQ_DUTIES = [];")