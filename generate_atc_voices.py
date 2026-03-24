import os
import requests
import time

# User-provided ElevenLabs API token (keep private!)
ELEVENLABS_API_KEY = "sk_f7e528180870dcc51c01513be47e60a88926a6a5cee574a5"

# Voice IDs for each controller
VOICE_IDS = {
    "adam":   "pNInz6obpgDQGcFmaJgB",   # Adam - American male
    "alice":  "Xb7hH8MSUJpSbSDYk0k2",   # Alice - British female
    "daniel": "ErXwobaYiN019PkySvjV",   # Daniel - American male
    "gary":   "QLOrGSLtlFUlfQRSaOtQ",   # Gary - user provided
}

# Output folders
OUTPUT_BASE = os.path.join(os.path.dirname(__file__), "phrases")

# Read phrases from file
with open("ATC_Phrase_List.txt", "r", encoding="utf-8") as f:
    lines = f.readlines()

# Filter to just phrase lines (skip comments/headers)
phrases = [l.strip() for l in lines if l.strip() and not l.startswith("#")]

# For Gary, only generate phrases under phrases/gary (full set)
gary_phrases = phrases.copy()  # You can filter if needed

# ElevenLabs API endpoint
TTS_URL = "https://api.elevenlabs.io/v1/text-to-speech/{voice_id}/stream"

# TTS settings
def tts_request(text, voice_id):
    headers = {
        "xi-api-key": ELEVENLABS_API_KEY,
        "Content-Type": "application/json"
    }
    payload = {
        "text": text,
        "voice_settings": {
            "stability": 0.5,
            "similarity_boost": 0.75
        }
    }
    url = TTS_URL.format(voice_id=voice_id)
    resp = requests.post(url, headers=headers, json=payload, stream=True)
    if resp.status_code == 200:
        return resp.content
    else:
        print(f"Error: {resp.status_code} for '{text}'")
        return None

def save_audio(voice, phrase, audio_bytes):
    folder = os.path.join(OUTPUT_BASE, voice)
    os.makedirs(folder, exist_ok=True)
    # Sanitize filename to remove invalid Windows characters
    import re
    safe_phrase = re.sub(r'[<>:"/\\|?*]', '', phrase)
    safe_phrase = safe_phrase.replace('(', '').replace(')', '').replace("'", '').replace('"', '')
    fname = safe_phrase.lower().replace(" ", "-").replace("/", "-").replace(".", "").replace(",", "")
    fname = fname[:64]  # limit length
    path = os.path.join(folder, f"{fname}.ogg")
    if os.path.exists(path):
        print(f"Skipping (already exists): {path}")
        return
    with open(path, "wb") as f:
        f.write(audio_bytes)
    print(f"Saved: {path}")

# Generate for Adam, Alice, Daniel
for voice in ["adam", "alice", "daniel"]:
    print(f"Generating for {voice}...")
    for phrase in phrases:
        audio = tts_request(phrase, VOICE_IDS[voice])
        if audio:
            save_audio(voice, phrase, audio)
        time.sleep(0.7)  # avoid rate limits

# Generate for Gary (all phrases)
print("Generating for gary...")
for phrase in gary_phrases:
    audio = tts_request(phrase, VOICE_IDS["gary"])
    if audio:
        save_audio("gary", phrase, audio)
    time.sleep(0.7)

print("All done!")
