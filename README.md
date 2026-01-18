# Token Top-Up Challenge

Ruby application that processes user token top-ups based on company policies and generates formatted reports.

## Installation

```bash
git clone <repository-url>
cd token-topup-challenge
# No dependencies required - uses Ruby stdlib only
```

**Requirements:** Ruby 2.5+

## Usage

```bash
# Basic usage
ruby challenge.rb

# Custom file paths
ruby challenge.rb -u users.json -c companies.json -o output.txt

# Help
ruby challenge.rb --help
```

## Business Rules

- Only **active users** (`active_status: true`) get top-ups
- Users must belong to a **valid company**
- **Email sent** only when both user AND company `email_status` are true
- **Output sorted** by company ID, then user last name

## Input Files

**users.json** - User data with: id, first_name, last_name, email, company_id, email_status, active_status, tokens

**companies.json** - Company data with: id, name, top_up, email_status

### Test Coverage (45+ tests)

**Functionality:**
- File loading, JSON parsing, output generation
- Token calculations, email logic, sorting

**Error Handling:**
- Missing files, invalid JSON, bad data types
- Missing fields, null values, orphaned users

**Edge Cases:**
- Special characters, negative/zero values
- Duplicates, empty data, large numbers
- Email status combinations (4 scenarios)

**Output Format:**
- Indentation, structure, content validation

## Error Handling

Gracefully handles missing files, invalid JSON, bad data types, null values, and invalid references. Errors logged to STDERR.

- Exit code 0 = Success
- Exit code 1 = Failure

## Project Structure

```
├── challenge.rb          # Main application
├── users.json           # Sample data
├── companies.json       # Sample data
├── README.md
└── spec/
    └── challenge_spec.rb # Test suite
```

