"""Quick test of TalkBank cookie authentication."""
import requests
from bs4 import BeautifulSoup

COOKIE = {"talkbank": "s%3A9fFFg_HTk4sKyJM9a3kIjRxdqL3_jX0B.uO0J2je6gSwkUGaMcZ2BdKrtmHfRTUuSyM%2BEC98SxOs"}
session = requests.Session()
session.cookies.update(COOKIE)

# Test 1: Directory listing
url = "https://media.talkbank.org/dementia/English/Pitt/"
print(f"Testing: {url}")
r = session.get(url, timeout=30)
print(f"Status: {r.status_code}")
print(f"Content-Type: {r.headers.get('Content-Type', '?')}")
print(f"Length: {len(r.text)}")
print()

if "authModals" in r.text or "initAuth" in r.text:
    print(">>> COOKIE NOT WORKING - got auth/login page")
    print(">>> You need to get a fresh cookie from your browser")
    print()
    print("HOW TO GET FRESH COOKIE:")
    print("1. Open Chrome -> go to https://media.talkbank.org/dementia/English/Pitt/")
    print("2. Log in if needed")
    print("3. Press F12 -> Application tab -> Cookies -> media.talkbank.org")
    print("4. Find the 'talkbank' cookie, copy its Value")
    print("5. Paste it in download.py COOKIE line")
else:
    print(">>> COOKIE WORKS! Got real content")
    soup = BeautifulSoup(r.text, "html.parser")
    links = soup.find_all("a")
    print(f"Found {len(links)} links:")
    for l in links[:15]:
        href = l.get("href", "?")
        print(f"  {href}")

# Test 2: Direct MP3 file
print()
mp3_url = "https://media.talkbank.org/dementia/English/Pitt/Control/cookie/002-0.mp3"
print(f"Testing direct MP3: {mp3_url}")
r2 = session.get(mp3_url, stream=True, timeout=30)
print(f"Status: {r2.status_code}")
ct = r2.headers.get("Content-Type", "?")
cl = r2.headers.get("Content-Length", "?")
print(f"Content-Type: {ct}")
print(f"Content-Length: {cl}")
chunk = r2.content[:100]
if b"<html" in chunk.lower() or b"script" in chunk.lower():
    print(">>> Got HTML instead of MP3 - auth failed")
else:
    print(f">>> Got binary data ({len(r2.content)} bytes) - likely real MP3!")
