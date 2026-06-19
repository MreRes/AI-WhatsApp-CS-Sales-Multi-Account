"""
Embedded MCP registration module.

This module discovers and registers embedded MCPs (Windows-MCP, macOS-MCP, Android-MCP)
into the hermes tool registry at startup.
"""

import logging
import os
import sys
from pathlib import Path

logger = logging.getLogger(__name__)

# Get embedded MCPs directory
EMBEDDED_MCPS_DIR = Path(__file__).parent.absolute()


def register_embedded_mcps(config: dict) -> None:
    """
    Register all embedded MCPs into hermes config.

    This function should be called at hermes startup to add embedded MCPs
    to the mcp_servers configuration.

    Args:
        config: The hermes config dictionary with mcp_servers key

    Platform-specific behavior:
    - Windows: Register Windows-MCP
    - macOS: Register macOS-MCP (Phase 2)
    - Linux: Register only base MCPs (Android-MCP)
    """
    import platform

    current_platform = platform.system()
    logger.info(f"Registering embedded MCPs for platform: {current_platform}")

    # Ensure mcp_servers exists
    if "mcp_servers" not in config:
        config["mcp_servers"] = {}

    # Windows: Register Windows-MCP
    if current_platform == "Windows":
        windows_mcp_config = {
            "name": "windows",
            "command": sys.executable,
            "args": ["-m", "windows_mcp", "serve"],
            "transport": "stdio",
            "enabled": True,
            "cwd": str(EMBEDDED_MCPS_DIR / "windows_mcp")
        }
        config["mcp_servers"]["windows"] = windows_mcp_config
        logger.info("✅ Registered Windows-MCP")

    # macOS: Register macOS-MCP (Phase 2)
    elif current_platform == "Darwin":
        logger.info("⏳ macOS-MCP registration deferred to Phase 2")

    # Linux: Base MCPs only
    elif current_platform == "Linux":
        logger.info("ℹ️  Linux mode: only base MCPs available")

    logger.info(f"MCP registration complete. Total MCPs: {len(config.get('mcp_servers', {}))}")


__all__ = ["register_embedded_mcps", "EMBEDDED_MCPS_DIR"]
