import json
import logging
import time
from pathlib import Path
from tools.registry import registry
from hermes_constants import get_hermes_home

logger = logging.getLogger(__name__)

def get_media_cache_dir() -> Path:
    media_dir = get_hermes_home() / "cache" / "media"
    media_dir.mkdir(parents=True, exist_ok=True)
    return media_dir

def capture_webcam(device_index: int = 0) -> str:
    """Captures a photo from the host webcam at the specified device index."""
    try:
        import cv2  # type: ignore
    except ImportError:
        return json.dumps({
            "success": False,
            "error": "opencv-python is not installed. Install it with: pip install opencv-python"
        })
        
    cap = cv2.VideoCapture(device_index)
    try:
        if not cap.isOpened():
            return json.dumps({
                "success": False,
                "error": f"Cannot open camera at index {device_index}. It may be in use, missing, or disabled."
            })
            
        # Warmup the camera sensor
        for _ in range(5):
            cap.read()
            
        ret, frame = cap.read()
        if not ret or frame is None:
            return json.dumps({
                "success": False,
                "error": f"Failed to capture frame from camera at index {device_index}."
            })
    finally:
        cap.release()
        
    # Save the photo
    timestamp = int(time.time() * 1000)
    filepath = get_media_cache_dir() / f"webcam_{timestamp}.jpg"
    success = cv2.imwrite(str(filepath), frame)
    if not success:
        return json.dumps({
            "success": False,
            "error": f"Failed to save captured photo to {filepath}."
        })
        
    return json.dumps({
        "success": True,
        "message": "Webcam photo captured successfully.",
        "path": str(filepath.resolve())
    })

def record_audio(duration_seconds: int = 5) -> str:
    """Records audio from the default microphone for a given duration in seconds."""
    try:
        import sounddevice as sd  # type: ignore
    except ImportError:
        return json.dumps({
            "success": False,
            "error": "sounddevice is not installed. Install it with: pip install sounddevice"
        })
        
    try:
        import scipy.io.wavfile  # type: ignore
    except ImportError:
        return json.dumps({
            "success": False,
            "error": "scipy is not installed. Install it with: pip install scipy"
        })
        
    # Standard settings
    sample_rate = 44100
    duration_seconds = max(1, min(duration_seconds, 60))  # clamp between 1 and 60 seconds
    
    try:
        logger.info(f"Recording audio for {duration_seconds} seconds...")
        recording = sd.rec(
            int(duration_seconds * sample_rate),
            samplerate=sample_rate,
            channels=1,
            dtype="int16"
        )
        sd.wait()  # Block until done
    except Exception as e:
        return json.dumps({
            "success": False,
            "error": f"Failed to record audio from input device: {e}"
        })
        
    # Save as WAV
    timestamp = int(time.time() * 1000)
    filepath = get_media_cache_dir() / f"mic_{timestamp}.wav"
    try:
        audio_data = recording.flatten()
        scipy.io.wavfile.write(str(filepath), sample_rate, audio_data)
    except Exception as e:
        return json.dumps({
            "success": False,
            "error": f"Failed to save audio recording: {e}"
        })
        
    return json.dumps({
        "success": True,
        "message": f"Audio recorded successfully for {duration_seconds} seconds.",
        "path": str(filepath.resolve())
    })

# Register Webcam capture tool
registry.register(
    name="capture_webcam",
    toolset="portable",
    schema={
        "name": "capture_webcam",
        "description": "Capture a single photo from the host PC's webcam. Saves to local directory and returns the absolute file path.",
        "parameters": {
            "type": "object",
            "properties": {
                "device_index": {
                    "type": "integer",
                    "description": "The camera index (0 = default webcam).",
                    "default": 0
                }
            }
        }
    },
    handler=lambda args, **kw: capture_webcam(device_index=args.get("device_index", 0)),
    check_fn=lambda: True,
    requires_env=[]
)

# Register audio recording tool
registry.register(
    name="record_audio",
    toolset="portable",
    schema={
        "name": "record_audio",
        "description": "Record audio from the default host PC microphone. Saves to a local WAV file and returns the absolute path.",
        "parameters": {
            "type": "object",
            "properties": {
                "duration_seconds": {
                    "type": "integer",
                    "description": "Recording duration in seconds (clamped between 1 and 60 seconds).",
                    "default": 5
                }
            },
            "required": ["duration_seconds"]
        }
    },
    handler=lambda args, **kw: record_audio(duration_seconds=args.get("duration_seconds", 5)),
    check_fn=lambda: True,
    requires_env=[]
)
