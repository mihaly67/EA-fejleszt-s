import urllib.request
import json

def search_github(query):
    url = f"https://api.github.com/search/repositories?q={urllib.parse.quote(query)}&per_page=3"
    req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'})
    try:
        with urllib.request.urlopen(req) as response:
            data = json.loads(response.read().decode())
            for item in data.get('items', []):
                print(f"{item['name']}: {item['clone_url']}")
    except Exception as e:
        print(f"Error: {e}")

search_github("tvchart-python-websocket")
search_github("tradingview charting library python")
