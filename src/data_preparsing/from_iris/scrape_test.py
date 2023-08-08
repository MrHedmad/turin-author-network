import requests as rq
import os
import json

API_KEY = os.getenv("ELSEVIER_AUTH_KEY")

assert API_KEY is not None, "API key must be set! Use export ELSEVIER_AUTH_KEY='your_key'!"

head = {"X-ELS-APIKey": API_KEY}

def update(old, new):
    old.update(new)
    return old

affil_req = rq.get(
    'https://api.elsevier.com/content/search/affiliation',
    params = {"query": "Turin"},
    headers = head
)

print(affil_req)
turin_affil = json.loads(affil_req.content)

print(turin_affil)
