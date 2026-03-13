import requests

COOKIE_VALUE = "s%3A620ID0eifnFPiN6bcrTSZu8Go-0PbLxl.YvxZfArlF4gKN6ZQlh5LZpK8Wr%2Bo8Zlxe7svOj8Siv8"
session = requests.Session()
session.cookies.update({"talkbank": COOKIE_VALUE})
session.headers.update({"User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36"})

r = session.get("https://media.talkbank.org/dementia/English/Pitt/", timeout=30)
print(f"Status: {r.status_code}")
print(f"Length: {len(r.text)}")
print("--- FULL RESPONSE ---")
print(r.text)
print("--- END ---")
