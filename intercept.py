"""
Usage: mitmweb -p 8888 -s intercept.py
"""
from mitmproxy import http
import threading
import json
import os


def done():
	os._exit(0)


def request(flow: http.HTTPFlow) -> None:
	if flow.request.host == "shareous1.dexcom.com" and flow.request.path_components == ("AppCompatibilityWebServices", "Services", "CheckValidity"):
		flow.response = http.HTTPResponse.make(200, json.dumps({
			"MessageCacheId": "1bdff235-93ba-4ff5-bbc4-f0fe4d5b53d4",
			"MessageId": "df7bdfb3-f84e-4d42-bf0a-feb2376547b3",
			"Validity": "ValidEnvironment"
		}), {
			"Content-Type": "application/json",
			"Cache-Control": "private"
		})

		threading.Timer(5, done).start()
