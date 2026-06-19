import json
import logging
import platform
import re
import subprocess
from tools.registry import registry

logger = logging.getLogger(__name__)

# Windows clipboard formats
CF_UNICODETEXT = 13

# Sensitivity regexes
SENSITIVE_PATTERNS = [
    r"-----BEGIN\s+(RSA\s+|OPENSSH\s+|EC\s+|DSA\s+)?PRIVATE\s+KEY-----",
    r"-----BEGIN\s+(CERTIFICATE|PRIVATE\s+KEY|RSA\s+PRIVATE\s+KEY)-----",
    r"-----BEGIN\s+PGP\s+PRIVATE\s+KEY\s+BLOCK-----",
    r"(aws_access_key_id|aws_secret_access_key|api_key|token|password|secret)\s*=",
    r"^[A-Z_]+=.+"
]

def is_content_sensitive(text: str) -> bool:
    """Returns True if the clipboard text matches any sensitive credential pattern."""
    if not text:
        return False
    for pattern in SENSITIVE_PATTERNS:
        if re.search(pattern, text, re.IGNORECASE | re.MULTILINE):
            return True
    return False

# --- Windows ctypes implementation ---
def _win_open_clipboard() -> bool:
    import ctypes
    return bool(ctypes.windll.user32.OpenClipboard(None))

def _win_close_clipboard() -> None:
    import ctypes
    ctypes.windll.user32.CloseClipboard()

def _win_get_clipboard_text() -> str | None:
    import ctypes
    if not _win_open_clipboard():
        return None
    try:
        if not ctypes.windll.user32.IsClipboardFormatAvailable(CF_UNICODETEXT):
            return None
        ctypes.windll.user32.GetClipboardData.argtypes = [ctypes.c_uint]
        ctypes.windll.user32.GetClipboardData.restype = ctypes.c_void_p
        handle = ctypes.windll.user32.GetClipboardData(CF_UNICODETEXT)
        if not handle:
            return None
        kernel32 = ctypes.windll.kernel32
        kernel32.GlobalLock.argtypes = [ctypes.c_void_p]
        kernel32.GlobalLock.restype = ctypes.c_void_p
        ptr = kernel32.GlobalLock(handle)
        if not ptr:
            return None
        try:
            text = ctypes.wstring_at(ptr)
            return text if text else None
        finally:
            kernel32.GlobalUnlock.argtypes = [ctypes.c_void_p]
            kernel32.GlobalUnlock(handle)
    finally:
        _win_close_clipboard()

def _win_set_clipboard_text(text: str) -> bool:
    import ctypes
    if not _win_open_clipboard():
        return False
    try:
        ctypes.windll.user32.EmptyClipboard()
        encoded = text.encode("utf-16-le") + b"\x00\x00"
        size = len(encoded)
        
        kernel32 = ctypes.windll.kernel32
        GMEM_MOVEABLE = 0x0002
        kernel32.GlobalAlloc.argtypes = [ctypes.c_uint, ctypes.c_size_t]
        kernel32.GlobalAlloc.restype = ctypes.c_void_p
        h_mem = kernel32.GlobalAlloc(GMEM_MOVEABLE, size)
        if not h_mem:
            return False
            
        kernel32.GlobalLock.argtypes = [ctypes.c_void_p]
        kernel32.GlobalLock.restype = ctypes.c_void_p
        ptr = kernel32.GlobalLock(h_mem)
        if not ptr:
            kernel32.GlobalFree.argtypes = [ctypes.c_void_p]
            kernel32.GlobalFree(h_mem)
            return False
            
        ctypes.memmove(ptr, encoded, size)
        kernel32.GlobalUnlock.argtypes = [ctypes.c_void_p]
        kernel32.GlobalUnlock(h_mem)
        
        ctypes.windll.user32.SetClipboardData.argtypes = [ctypes.c_uint, ctypes.c_void_p]
        ctypes.windll.user32.SetClipboardData.restype = ctypes.c_void_p
        result = ctypes.windll.user32.SetClipboardData(CF_UNICODETEXT, h_mem)
        if not result:
            kernel32.GlobalFree.argtypes = [ctypes.c_void_p]
            kernel32.GlobalFree(h_mem)
            return False
        return True
    finally:
        _win_close_clipboard()

# --- Cross-platform paste/copy implementation ---
def read_clipboard_text() -> str | None:
    system = platform.system()
    if system == "Windows":
        try:
            return _win_get_clipboard_text()
        except Exception:
            pass
    elif system == "Darwin":  # macOS
        try:
            return subprocess.check_output("pbpaste", text=True)
        except Exception:
            pass
    elif system == "Linux":
        # Try xclip
        try:
            return subprocess.check_output(["xclip", "-selection", "clipboard", "-o"], text=True)
        except Exception:
            pass
        # Try xsel
        try:
            return subprocess.check_output(["xsel", "--clipboard", "--output"], text=True)
        except Exception:
            pass
            
    # Pyperclip fallback
    try:
        import pyperclip
        return pyperclip.paste()
    except Exception:
        return None

def write_clipboard_text(text: str) -> bool:
    system = platform.system()
    if system == "Windows":
        try:
            return _win_set_clipboard_text(text)
        except Exception:
            pass
    elif system == "Darwin":  # macOS
        try:
            p = subprocess.Popen("pbcopy", stdin=subprocess.PIPE, text=True)
            p.communicate(input=text)
            return p.returncode == 0
        except Exception:
            pass
    elif system == "Linux":
        # Try xclip
        try:
            p = subprocess.Popen(["xclip", "-selection", "clipboard"], stdin=subprocess.PIPE, text=True)
            p.communicate(input=text)
            return p.returncode == 0
        except Exception:
            pass
            
    # Pyperclip fallback
    try:
        import pyperclip
        pyperclip.copy(text)
        return True
    except Exception:
        return False

# --- Tool handlers ---
def get_clipboard() -> str:
    text = read_clipboard_text()
    if text is None:
        return json.dumps({"success": False, "error": "Clipboard is empty or contains non-text data."})
    if is_content_sensitive(text):
        return json.dumps({
            "success": False,
            "error": "Clipboard content blocked: text matches a sensitive pattern (e.g. private keys, credentials)."
        })
    return json.dumps({"success": True, "text": text})

def set_clipboard(text: str) -> str:
    if not text:
        return json.dumps({"success": False, "error": "Text argument cannot be empty."})
    success = write_clipboard_text(text)
    if success:
        return json.dumps({"success": True, "message": "Text placed on the clipboard successfully."})
    return json.dumps({"success": False, "error": "Failed to set clipboard content."})

# Register get_clipboard
registry.register(
    name="clipboard_get",
    toolset="portable",
    schema={
        "name": "clipboard_get",
        "description": "Read text from the host system's clipboard. Protects sensitive credentials from leak.",
        "parameters": {
            "type": "object",
            "properties": {}
        }
    },
    handler=lambda args, **kw: get_clipboard(),
    check_fn=lambda: True,
    requires_env=[]
)

# Register set_clipboard
registry.register(
    name="clipboard_set",
    toolset="portable",
    schema={
        "name": "clipboard_set",
        "description": "Place the specified text on the host system's clipboard.",
        "parameters": {
            "type": "object",
            "properties": {
                "text": {
                    "type": "string",
                    "description": "The text to copy to the clipboard."
                }
            },
            "required": ["text"]
        }
    },
    handler=lambda args, **kw: set_clipboard(args.get("text", "")),
    check_fn=lambda: True,
    requires_env=[]
)
