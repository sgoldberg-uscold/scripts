"""Send a JSON body to local BE's /integration endpoint with a Bearer JWT.

The JWT is HS512, claims sub=oci and ver="1", signed with the "simple" secret read
from local BE's ewms-system.properties. Neither the secret nor the token is printed.

Usage: python3 -I swisslog_post.py <path> <json-file>
"""
import base64
import hashlib
import hmac
import json
import sys
import urllib.error
import urllib.request

PROPERTIES = "/Users/sgoldberg/Documents/Projects/ALL_CONFIGS/wlp/usr/servers/BE/conf/ewms-system.properties"
SECRET_KEY = "integratedservices.principals.oci.builders.simple.secret"
BASE_URL = "http://localhost:9080"


def read_secret():
    with open(PROPERTIES, encoding="utf-8") as properties:
        for line in properties:
            stripped = line.strip()
            if stripped.startswith("#") or "=" not in stripped:
                continue
            key, value = stripped.split("=", 1)
            if key.strip() == SECRET_KEY:
                return value.strip()
    sys.exit(f"{SECRET_KEY} not found")


def encode(part):
    return base64.urlsafe_b64encode(part).rstrip(b"=")


def build_token(secret):
    header = encode(json.dumps({"alg": "HS512", "typ": "JWT"}).encode())
    payload = encode(json.dumps({"sub": "oci", "ver": "1"}).encode())
    signing_input = header + b"." + payload
    signature = encode(hmac.new(secret.encode(), signing_input, hashlib.sha512).digest())
    return (signing_input + b"." + signature).decode()


def main():
    path, body_file = sys.argv[1], sys.argv[2]
    with open(body_file, "rb") as body:
        data = body.read()
    request = urllib.request.Request(
        BASE_URL + path,
        data=data,
        method="POST",
        headers={"Content-Type": "application/json", "Authorization": "Bearer " + build_token(read_secret())},
    )
    try:
        with urllib.request.urlopen(request, timeout=60) as response:
            print(f"HTTP {response.status}")
            print(response.read().decode())
    except urllib.error.HTTPError as error:
        print(f"HTTP {error.code}")
        print(error.read().decode())


if __name__ == "__main__":
    main()
