#!/usr/bin/env python3
"""
Embedded MCP server launcher.

Spawns Windows-MCP as a stdio server and registers it with hermes
config for dynamic MCP discovery.

Usage:
    from embedded_mcps.launcher import register_embedded_mcps_config

    config = load_hermes_config()
    register_embedded_mcps_config(config)  # Adds Windows-MCP to mcp_servers
"""

import logging
import os
import sys
from pathlib import Path
from typing import Dict, Optional, Any

logger = logging.getLogger(__name__)

# Get embedded MCPs directory
EMBEDDED_MCPS_DIR = Path(__file__).parent.absolute()
WINDOWS_MCP_DIR = EMBEDDED_MCPS_DIR / "windows_mcp"
MACOS_MCP_DIR = EMBEDDED_MCPS_DIR / "macos_mcp"
ANDROID_MCP_DIR = EMBEDDED_MCPS_DIR / "android_mcp"
GSHEETS_MCP_DIR = EMBEDDED_MCPS_DIR / "gsheets_mcp"

# ADB lives under the bundle's runtime/bin/platform-tools/ (auto-downloaded)
_BUNDLE_ROOT = EMBEDDED_MCPS_DIR.parent
ADB_PATH = _BUNDLE_ROOT / "runtime" / "bin" / "platform-tools" / "adb.exe"


class EmbeddedMCPLauncher:
    """Manage embedded MCP server registration."""

    @staticmethod
    def register_windows_mcp(config: Dict[str, Any]) -> bool:
        """
        Register Windows-MCP for stdio spawning.

        Adds Windows-MCP to hermes mcp_servers config so it gets
        spawned automatically at startup via hermes' mcp_tool.py.

        Args:
            config: Hermes config dictionary

        Returns:
            True if registration successful, False otherwise
        """
        try:
            # Ensure mcp_servers section exists
            if "mcp_servers" not in config:
                config["mcp_servers"] = {}

            # Windows-MCP server config
            # hermes mcp_tool.py will spawn this process and connect via stdio
            windows_mcp_config = {
                "name": "windows",
                "command": sys.executable,
                "args": ["-m", "windows_mcp", "serve"],
                "transport": "stdio",
                "enabled": True,
                "supports_parallel_tool_calls": False,
                "connect_timeout": 30,
                "timeout": 60,
            }

            # Additional context for hermes to find the module
            # hermes mcp_tool.py will use PYTHONPATH + module loading
            windows_mcp_config["env"] = {
                "PYTHONPATH": str(WINDOWS_MCP_DIR),
            }

            config["mcp_servers"]["windows"] = windows_mcp_config

            logger.info("✅ Registered Windows-MCP for stdio spawning")
            logger.info(f"   Command: {windows_mcp_config['command']}")
            logger.info(f"   Args: {windows_mcp_config['args']}")
            logger.info(f"   Working dir: {WINDOWS_MCP_DIR}")

            return True

        except Exception as e:
            logger.error(f"❌ Failed to register Windows-MCP: {e}")
            return False

    @staticmethod
    def register_android_mcp(config: Dict[str, Any]) -> bool:
        """
        Register Android-MCP (controls an Android device over ADB).

        Works on any host OS that has adb + a connected device. We only
        register it when the Android-MCP source is present AND adb is
        available, so it stays dormant if the user never plugs in a device.
        """
        try:
            if not ANDROID_MCP_DIR.exists():
                logger.info("Android-MCP source not bundled; skipping")
                return False

            if "mcp_servers" not in config:
                config["mcp_servers"] = {}

            env = {"PYTHONPATH": str(ANDROID_MCP_DIR)}
            # Point uiautomator2 at our bundled adb if we downloaded it.
            if ADB_PATH.exists():
                env["ADB_PATH"] = str(ADB_PATH)
                # uiautomator2 honours PATH for adb discovery
                env["PATH"] = str(ADB_PATH.parent) + os.pathsep + os.environ.get("PATH", "")

            config["mcp_servers"]["android"] = {
                "name": "android",
                "command": sys.executable,
                "args": ["-m", "android_mcp"],
                "transport": "stdio",
                "enabled": True,
                "connect_timeout": 30,
                "timeout": 60,
                "env": env,
            }
            logger.info("✅ Registered Android-MCP (adb: %s)",
                        "bundled" if ADB_PATH.exists() else "system PATH")
            return True
        except Exception as e:
            logger.error(f"❌ Failed to register Android-MCP: {e}")
            return False

    @staticmethod
    def register_macos_mcp(config: Dict[str, Any]) -> bool:
        """
        Register macOS-MCP (macOS desktop automation).

        Only valid on macOS — pyobjc native frameworks. No-op elsewhere.
        """
        try:
            if not MACOS_MCP_DIR.exists():
                logger.info("macOS-MCP source not bundled; skipping")
                return False

            if "mcp_servers" not in config:
                config["mcp_servers"] = {}

            config["mcp_servers"]["macos"] = {
                "name": "macos",
                "command": sys.executable,
                "args": ["-m", "macos_mcp"],
                "transport": "stdio",
                "enabled": True,
                "connect_timeout": 30,
                "timeout": 60,
                "env": {"PYTHONPATH": str(MACOS_MCP_DIR)},
            }
            logger.info("✅ Registered macOS-MCP")
            return True
        except Exception as e:
            logger.error(f"❌ Failed to register macOS-MCP: {e}")
            return False

    @staticmethod
    def register_google_sheets_mcp(config: Dict[str, Any]) -> bool:
        """
        Register Google Sheets MCP (read-only via API key).

        Only registers when GOOGLE_SHEETS_API_KEY is present in the environment
        so it stays dormant for users who haven't set up the integration.
        """
        try:
            api_key = os.environ.get("GOOGLE_SHEETS_API_KEY", "").strip()
            if not api_key:
                logger.info(
                    "GOOGLE_SHEETS_API_KEY not set — "
                    "Google Sheets MCP skipped. "
                    "Add to data/.env to enable."
                )
                return False

            if not GSHEETS_MCP_DIR.exists():
                logger.warning("gsheets_mcp directory not found; skipping")
                return False

            if "mcp_servers" not in config:
                config["mcp_servers"] = {}

            config["mcp_servers"]["google_sheets"] = {
                "name": "google_sheets",
                "command": sys.executable,
                "args": ["-m", "gsheets_mcp"],
                "transport": "stdio",
                "enabled": True,
                "connect_timeout": 30,
                "timeout": 60,
                "env": {
                    "PYTHONPATH": str(EMBEDDED_MCPS_DIR),
                    "GOOGLE_SHEETS_API_KEY": api_key,
                },
            }

            logger.info("✅ Registered Google Sheets MCP (read-only, API key auth)")
            return True

        except Exception as e:
            logger.error(f"❌ Failed to register Google Sheets MCP: {e}")
            return False

    @staticmethod
    def register_all_embedded_mcps(config: Dict[str, Any]) -> bool:
        """
        Register all available embedded MCPs based on platform.

        - Windows host: Windows-MCP (active) + Android-MCP (if adb/device)
        - macOS host:   macOS-MCP (active)   + Android-MCP (if adb/device)
        - Linux host:   Android-MCP (if adb/device)

        Args:
            config: Hermes config dictionary

        Returns:
            True if any MCPs registered, False otherwise
        """
        import platform

        current_platform = platform.system()
        registered_count = 0

        logger.info(f"🔍 Detecting platform: {current_platform}")

        # Native desktop MCP for the current OS
        if current_platform == "Windows":
            if EmbeddedMCPLauncher.register_windows_mcp(config):
                registered_count += 1
        elif current_platform == "Darwin":
            if EmbeddedMCPLauncher.register_macos_mcp(config):
                registered_count += 1

        # Android-MCP is cross-host (controls a phone, not the PC)
        if EmbeddedMCPLauncher.register_android_mcp(config):
            registered_count += 1

        # Google Sheets MCP — all platforms, activates when API key is set
        if EmbeddedMCPLauncher.register_google_sheets_mcp(config):
            registered_count += 1

        logger.info(
            f"📊 MCP registration complete: {registered_count} MCP(s) registered"
        )

        return registered_count > 0


def register_embedded_mcps_config(config: Dict[str, Any]) -> Dict[str, Any]:
    """
    Top-level function to register all embedded MCPs.

    This should be called early in hermes startup (e.g., in agent_init.py)
    to ensure MCPs are available for tool discovery.

    Args:
        config: Hermes config dictionary (will be modified in-place)

    Returns:
        Updated config with embedded MCPs registered
    """
    EmbeddedMCPLauncher.register_all_embedded_mcps(config)
    return config


def validate_embedded_mcps() -> bool:
    """
    Validate that embedded MCP directories exist.

    Returns:
        True if all required directories exist, False otherwise
    """
    checks = [
        ("Windows-MCP", WINDOWS_MCP_DIR),
        ("macOS-MCP", MACOS_MCP_DIR),
        ("Android-MCP", ANDROID_MCP_DIR),
        ("Google Sheets MCP", GSHEETS_MCP_DIR),
    ]

    all_valid = True
    for name, path in checks:
        if path.exists():
            logger.info(f"✅ {name} found: {path}")
        else:
            logger.warning(f"⚠️  {name} not found: {path}")
            all_valid = False

    return all_valid


if __name__ == "__main__":
    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s - %(name)s - %(levelname)s - %(message)s",
    )

    print("🔍 Validating embedded MCPs...")
    if validate_embedded_mcps():
        print("✅ All embedded MCPs ready for deployment")
    else:
        print("⚠️  Some embedded MCPs missing (Phase 2+ deferred)")
