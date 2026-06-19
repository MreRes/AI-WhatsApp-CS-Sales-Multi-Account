"""
Portable configuration module.

Handles config generation, template rendering, and environment setup
for hermes-portable bundle.
"""

from pathlib import Path

CONFIG_DIR = Path(__file__).parent.absolute()
TEMPLATES_DIR = CONFIG_DIR

__all__ = ["CONFIG_DIR", "TEMPLATES_DIR"]
