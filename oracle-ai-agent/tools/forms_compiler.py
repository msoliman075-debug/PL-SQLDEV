"""
Oracle Forms 12c Compiler and Analyzer
"""
import os
import subprocess
import xml.etree.ElementTree as ET
from pathlib import Path
from typing import Optional
from dataclasses import dataclass


@dataclass
class FormInfo:
    name: str
    path: str
    blocks: list
    triggers: list
    program_units: list


class FormsCompiler:
    """Compile and analyze Oracle Forms 12c modules."""

    def __init__(
        self,
        oracle_home: str = None,
        domain_home: str = None,
        source_path: str = None,
    ):
        self.oracle_home = oracle_home or os.getenv(
            "FORMS_ORACLE_HOME", "/u01/oracle/middleware"
        )
        self.domain_home = domain_home or os.getenv(
            "FORMS_DOMAIN_HOME", "/u01/oracle/config/domains/forms"
        )
        self.source_path = Path(
            source_path or os.getenv("FORMS_SOURCE_PATH", "/u01/forms/source")
        )

        self.frmcmp = f"{self.oracle_home}/bin/frmcmp_batch.sh"
        self.frmf2xml = f"{self.oracle_home}/bin/frmf2xml.sh"
        self.frmxml2f = f"{self.oracle_home}/bin/frmxml2f.sh"

    def compile_form(
        self, fmb_file: str, userid: str = None, output_dir: str = None
    ) -> dict:
        """
        Compile .fmb to .fmx
        
        Args:
            fmb_file: Path to .fmb file (relative to source_path or absolute)
            userid: Database connection string (user/pass@db)
            output_dir: Output directory for .fmx (defaults to same as .fmb)
        """
        fmb_path = self._resolve_path(fmb_file)
        if not fmb_path.exists():
            return {"status": "failed", "error": f"File not found: {fmb_path}"}

        output_file = fmb_path.with_suffix(".fmx")
        if output_dir:
            output_file = Path(output_dir) / output_file.name

        # Build frmcmp command
        cmd = [
            self.frmcmp,
            f"module={fmb_path}",
            f"output_file={output_file}",
            "compile_all=yes",
            "batch=yes",
        ]

        if userid:
            cmd.append(f"userid={userid}")

        env = os.environ.copy()
        env["ORACLE_HOME"] = self.oracle_home
        env["FORMS_PATH"] = str(self.source_path)

        try:
            result = subprocess.run(
                cmd,
                capture_output=True,
                text=True,
                timeout=300,
                env=env,
            )

            # Parse compilation output for errors
            errors = self._parse_compile_errors(result.stdout + result.stderr)

            return {
                "status": "success" if result.returncode == 0 else "failed",
                "fmb": str(fmb_path),
                "fmx": str(output_file) if result.returncode == 0 else None,
                "errors": errors,
                "output": result.stdout,
            }
        except subprocess.TimeoutExpired:
            return {"status": "failed", "error": "Compilation timeout (300s)"}
        except Exception as e:
            return {"status": "failed", "error": str(e)}

    def convert_to_xml(self, fmb_file: str, output_xml: str = None) -> dict:
        """
        Convert .fmb to XML for analysis and text-based editing.
        Uses frmf2xml utility from Forms 12c.
        """
        fmb_path = self._resolve_path(fmb_file)
        if not fmb_path.exists():
            return {"status": "failed", "error": f"File not found: {fmb_path}"}

        xml_path = Path(output_xml) if output_xml else fmb_path.with_suffix(".xml")

        cmd = [
            self.frmf2xml,
            str(fmb_path),
            str(xml_path),
        ]

        env = os.environ.copy()
        env["ORACLE_HOME"] = self.oracle_home

        try:
            result = subprocess.run(
                cmd,
                capture_output=True,
                text=True,
                timeout=120,
                env=env,
            )
            return {
                "status": "success" if result.returncode == 0 else "failed",
                "xml_file": str(xml_path) if result.returncode == 0 else None,
                "output": result.stdout,
                "error": result.stderr if result.returncode != 0 else None,
            }
        except Exception as e:
            return {"status": "failed", "error": str(e)}

    def convert_from_xml(self, xml_file: str, output_fmb: str = None) -> dict:
        """Convert XML back to .fmb binary."""
        xml_path = Path(xml_file)
        if not xml_path.exists():
            return {"status": "failed", "error": f"File not found: {xml_path}"}

        fmb_path = Path(output_fmb) if output_fmb else xml_path.with_suffix(".fmb")

        cmd = [
            self.frmxml2f,
            str(xml_path),
            str(fmb_path),
        ]

        env = os.environ.copy()
        env["ORACLE_HOME"] = self.oracle_home

        try:
            result = subprocess.run(
                cmd,
                capture_output=True,
                text=True,
                timeout=120,
                env=env,
            )
            return {
                "status": "success" if result.returncode == 0 else "failed",
                "fmb_file": str(fmb_path) if result.returncode == 0 else None,
                "error": result.stderr if result.returncode != 0 else None,
            }
        except Exception as e:
            return {"status": "failed", "error": str(e)}

    def analyze_form(self, fmb_file: str) -> dict:
        """
        Analyze form structure - extract blocks, triggers, program units.
        Converts to XML first for analysis.
        """
        # First convert to XML
        xml_result = self.convert_to_xml(fmb_file)
        if xml_result["status"] != "success":
            return xml_result

        xml_path = xml_result["xml_file"]

        try:
            tree = ET.parse(xml_path)
            root = tree.getroot()

            blocks = []
            triggers = []
            program_units = []

            # Extract blocks
            for block in root.findall(".//Block"):
                block_info = {
                    "name": block.get("Name", ""),
                    "items": [item.get("Name", "") for item in block.findall(".//Item")],
                    "triggers": [
                        trig.get("Name", "") for trig in block.findall(".//Trigger")
                    ],
                }
                blocks.append(block_info)

            # Extract form-level triggers
            for trigger in root.findall("./Trigger"):
                triggers.append(
                    {
                        "name": trigger.get("Name", ""),
                        "type": trigger.get("TriggerType", ""),
                    }
                )

            # Extract program units
            for pu in root.findall(".//ProgramUnit"):
                program_units.append(
                    {
                        "name": pu.get("Name", ""),
                        "type": pu.get("ProgramUnitType", ""),
                        "code": pu.text if pu.text else "",
                    }
                )

            return {
                "status": "success",
                "form_name": root.get("Name", Path(fmb_file).stem),
                "blocks": blocks,
                "triggers": triggers,
                "program_units": program_units,
                "xml_file": xml_path,
            }

        except ET.ParseError as e:
            return {"status": "failed", "error": f"XML parse error: {e}"}
        except Exception as e:
            return {"status": "failed", "error": str(e)}

    def extract_plsql(self, fmb_file: str) -> dict:
        """Extract all PL/SQL code from a form."""
        analysis = self.analyze_form(fmb_file)
        if analysis["status"] != "success":
            return analysis

        plsql_code = {
            "program_units": {},
            "triggers": {},
        }

        # Get program unit code
        for pu in analysis.get("program_units", []):
            if pu.get("code"):
                plsql_code["program_units"][pu["name"]] = pu["code"]

        # Would need to parse XML more deeply for trigger code
        # This is a simplified version

        return {
            "status": "success",
            "form_name": analysis["form_name"],
            "plsql": plsql_code,
        }

    def list_forms(self, pattern: str = "*.fmb") -> list:
        """List all forms matching pattern in source directory."""
        forms = []
        for fmb in self.source_path.glob(pattern):
            forms.append(
                {
                    "name": fmb.stem,
                    "path": str(fmb),
                    "size": fmb.stat().st_size,
                    "modified": fmb.stat().st_mtime,
                }
            )
        return sorted(forms, key=lambda x: x["name"])

    def _resolve_path(self, file_path: str) -> Path:
        """Resolve file path (absolute or relative to source_path)."""
        path = Path(file_path)
        if path.is_absolute():
            return path
        return self.source_path / path

    def _parse_compile_errors(self, output: str) -> list:
        """Parse compilation output for errors."""
        errors = []
        for line in output.splitlines():
            line_lower = line.lower()
            if "error" in line_lower or "frm-" in line_lower:
                errors.append(line.strip())
        return errors
