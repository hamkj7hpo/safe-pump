#!/usr/bin/env python3
import os
import logging
from pathlib import Path
import toml

# --- Config ---
BASE_DIR = Path("/var/www/html/program/safe_pump")
SOLANA_PROGRAM_DIR = BASE_DIR / "solana-program/src"
REPORT_FILE = Path("solana_program_diagnostic_report.txt")

# Dependencies we want to enforce everywhere
DEPENDENCY_FIXES = {
    "solana-program": {"version": "2.1.0", "path": "./solana-program"},
    "solana-sdk": {"version": "1.25.0", "path": "./solana-sdk"},
    "spl-program-error": {
        "version": "0.4.2",
        "path": "./solana-program-library/libraries/program-error",
    },
    "curve25519-dalek": {"version": "5.0.0-pre.0", "path": "./curve25519-dalek"},
}

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s - %(levelname)s - %(message)s",
    handlers=[
        logging.FileHandler("solana_program_diagnostic.log"),
        logging.StreamHandler(),
    ],
)


def analyze_rust_file(file_path):
    """Check Rust source for ProgramResult and unbalanced braces/parens/brackets."""
    issues = []
    try:
        with open(file_path, "r", encoding="utf-8") as f:
            content = f.read()

        # ProgramResult usage
        if "ProgramResult" in content:
            issues.append("ProgramResult used, may be incompatible with solana-program v2.1.0")

        # Simple delimiter balance check
        if content.count("{") != content.count("}"):
            issues.append("Unbalanced braces")
        if content.count("(") != content.count(")"):
            issues.append("Unbalanced parentheses")
        if content.count("[") != content.count("]"):
            issues.append("Unbalanced brackets")

    except Exception as e:
        issues.append(f"Error reading file: {str(e)}")

    return issues


def analyze_cargo_toml(file_path):
    """Check Cargo.toml against DEPENDENCY_FIXES rules."""
    issues = []
    try:
        toml_data = toml.load(file_path)

        for section in ["dependencies", "dev-dependencies", "build-dependencies", "workspace.dependencies"]:
            if section not in toml_data:
                continue
            for dep, rules in DEPENDENCY_FIXES.items():
                if dep in toml_data[section]:
                    entry = toml_data[section][dep]
                    if isinstance(entry, str):
                        if entry != rules["version"]:
                            issues.append(f"{dep} in {file_path}: version {entry}, expected {rules['version']}")
                    elif isinstance(entry, dict):
                        ver = entry.get("version")
                        path = entry.get("path")
                        if ver != rules["version"]:
                            issues.append(f"{dep} in {file_path}: version {ver}, expected {rules['version']}")
                        if path != rules["path"]:
                            issues.append(f"{dep} in {file_path}: path {path}, expected {rules['path']}")

    except Exception as e:
        issues.append(f"Error reading Cargo.toml: {str(e)}")

    return issues


def scan_workspace(root: Path):
    """Scan Rust + Cargo.toml files in the workspace."""
    issues_by_file = {}

    # Rust source files
    for rs_file in SOLANA_PROGRAM_DIR.rglob("*.rs"):
        issues = analyze_rust_file(rs_file)
        if issues:
            issues_by_file[str(rs_file)] = issues

    # Cargo.toml files
    for toml_file in root.rglob("Cargo.toml"):
        issues = analyze_cargo_toml(toml_file)
        if issues:
            issues_by_file[str(toml_file)] = issues

    return issues_by_file


def generate_report(issues_by_file):
    """Generate a summary report of mismatches."""
    with open(REPORT_FILE, "w", encoding="utf-8") as f:
        f.write("Solana Program Diagnostic Summary\n")
        f.write("=" * 40 + "\n\n")
        if not issues_by_file:
            f.write("No issues found. 🎉\n")
            logging.info("No issues found. 🎉")
        else:
            for file, issues in issues_by_file.items():
                f.write(f"\nFile: {file}\n")
                for issue in issues:
                    f.write(f"  - {issue}\n")
    logging.info(f"Diagnostic report generated at {REPORT_FILE}")


def main():
    logging.info("Starting diagnostic scan...")
    if not BASE_DIR.exists():
        logging.error(f"Directory {BASE_DIR} does not exist")
        return

    issues_by_file = scan_workspace(BASE_DIR)
    generate_report(issues_by_file)


if __name__ == "__main__":
    main()
