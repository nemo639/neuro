import requests

COOKIE = {"talkbank": "s%3A620ID0eifnFPiN6bcrTSZu8Go-0PbLxl.YvxZfArlF4gKN6ZQlh5LZpK8Wr%2Bo8Zlxe7svOj8Siv8"}
session = requests.Session()
session.cookies.update(COOKIE)
session.headers.update({
    "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
})

# Test a single MP3 download
url = "https://media.talkbank.org/dementia/English/Pitt/Control/cookie/192-0.mp3"
print(f"Testing: {url}")

# Test 1: Without Range header (gets partial)
r = session.get(url)
print(f"Test 1 (no Range header):")
print(f"  Status: {r.status_code}")

# Extract full size from Content-Range
cr = r.headers.get("Content-Range", "")
print(f"  Content-Range: {cr}")
print(f"  Got {len(r.content)} bytes")

# Test 2: With explicit Range header requesting full file
print()
print("Test 2 (Range: bytes=0-):")
r2 = session.get(url, headers={"Range": "bytes=0-"})
print(f"  Status: {r2.status_code}")
cr2 = r2.headers.get("Content-Range", "NONE")
cl2 = r2.headers.get("Content-Length", "NONE")
print(f"  Content-Range: {cr2}")
print(f"  Content-Length: {cl2}")
print(f"  Got {len(r2.content)} bytes")
print(f"  First 10: {repr(r2.content[:10])}")

print()
ct_len = r.headers.get("Content-Length", "NONE")
ct_type = r.headers.get("Content-Type", "NONE")
print(f"Content-Length header: {ct_len}")
print(f"Content-Type: {ct_type}")
print(f"Actual content length: {len(r.content)}")
print(f"First 200 bytes repr: {repr(r.content[:200])}")
print()
print("All response headers:")
for k, v in r.headers.items():
    print(f"  {k}: {v}")
