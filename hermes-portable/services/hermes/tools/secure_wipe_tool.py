import json
import logging
import os
import platform
import shutil
from pathlib import Path
from tools.registry import registry
from hermes_constants import get_hermes_home

logger = logging.getLogger(__name__)

def secure_overwrite_file(path: Path, passes: int = 3) -> None:
    """Overwrites a file with random bytes before deleting it for security."""
    if not path.is_file():
        return
    try:
        size = path.stat().st_size
        # Overwrite with random bytes
        with open(path, "ba+", buffering=0) as f:
            for _ in range(passes):
                f.seek(0)
                f.write(os.urandom(size))
        # Final overwrite with zeros
        with open(path, "ba+", buffering=0) as f:
            f.seek(0)
            f.write(b"\x00" * size)
    except Exception as e:
        logger.error(f"Error secure-overwriting file {path}: {e}")

def execute_secure_wipe() -> dict:
    """Recursively overwrites and deletes the active Hermes home directory."""
    hermes_home = get_hermes_home().resolve()
    logger.info(f"Initiating secure wipe of HERMES_HOME: {hermes_home}")
    
    # 1. Broadly identify sensitive files to secure overwrite first
    sensitive_extensions = {".env", ".yaml", ".db", ".db-journal", ".db-wal", ".json", ".log"}
    
    failed_paths = []
    
    # First pass: secure overwrite all sensitive files we can find
    for root, dirs, files in os.walk(hermes_home, topdown=False):
        for file in files:
            file_path = Path(root) / file
            if file_path.suffix.lower() in sensitive_extensions:
                secure_overwrite_file(file_path)

    # Second pass: recursively delete all files and directories
    try:
        entries = list(hermes_home.iterdir())
    except Exception as e:
        logger.error(f"Failed to list HERMES_HOME: {e}")
        return {"success": False, "error": f"Failed to list HERMES_HOME: {e}"}
        
    for entry in entries:
        # Crucial safety check: ensure the path is actually inside HERMES_HOME
        try:
            entry.resolve().relative_to(hermes_home)
        except ValueError:
            logger.warning(f"Safety warning: path {entry} escapes HERMES_HOME. Skipping.")
            continue
            
        try:
            if entry.is_dir():
                shutil.rmtree(entry, ignore_errors=False)
            else:
                entry.unlink()
        except Exception as e:
            logger.error(f"Failed to delete {entry}: {e}")
            failed_paths.append(str(entry))
            
    # Try to delete the home directory itself if empty
    try:
        hermes_home.rmdir()
    except Exception:
        pass
        
    if failed_paths:
        return {
            "success": False,
            "error": "Partial wipe failure",
            "failed_paths": failed_paths
        }
        
    return {"success": True, "message": "HERMES_HOME has been securely wiped and deleted."}

registry.register(
    name="secure_wipe",
    toolset="portable",
    schema={
        "name": "secure_wipe",
        "description": "Perform a secure self-destruct of the agent by overwriting and recursively deleting the active HERMES_HOME directory (including configs, API keys, sessions, and logs).",
        "parameters": {
            "type": "object",
            "properties": {},
            "required": []
        }
    },
    handler=lambda args, **kw: json.dumps(execute_secure_wipe()),
    check_fn=lambda: True,
    requires_env=[]
)
