
from bs4 import BeautifulSoup
import os

path = "Res/Articles/Raw/Jules cikk és fájl letöltés/article_20266.html"
with open(path, 'r', encoding='utf-8', errors='ignore') as f:
    soup = BeautifulSoup(f, 'html.parser')

body = soup.find('div', id='articleContent') or \
       soup.find('div', class_='text') or \
       soup.find('div', itemprop='articleBody')

if body:
    print(f"Found container: {body.name}, class: {body.get('class')}, id: {body.get('id')}")
    # Print first 500 chars of HTML content inside
    print(str(body)[:500])
else:
    print("No container found.")
