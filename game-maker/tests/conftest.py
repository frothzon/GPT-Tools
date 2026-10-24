"""Permit both repository-root and tests-directory pytest invocation."""
from pathlib import Path
import sys
sys.path.insert(0, str(Path(__file__).resolve().parent))
