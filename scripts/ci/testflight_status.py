"""TestFlight durumu: son buildlerin isleme / beta durumu ve beta gruplari (App Store Connect API).
--add: en yeni build'i tum IC (internal) test gruplarina ekler. Gizli bilgiler ortam degiskenlerinden okunur."""
import json, os, sys, time, urllib.request, urllib.error
import jwt  # pyjwt

APP = os.environ["APP_STORE_APPLE_ID"]
API = "https://api.appstoreconnect.apple.com/v1"


def token():
    now = int(time.time())
    return jwt.encode({"iss": os.environ["APP_STORE_CONNECT_ISSUER_ID"], "iat": now, "exp": now + 1000,
                       "aud": "appstoreconnect-v1"}, os.environ["APP_STORE_CONNECT_PRIVATE_KEY"], algorithm="ES256",
                      headers={"kid": os.environ["APP_STORE_CONNECT_KEY_IDENTIFIER"], "typ": "JWT"})


def call(path, method="GET", body=None):
    req = urllib.request.Request(API + path, method=method, data=json.dumps(body).encode() if body else None,
                                 headers={"Authorization": "Bearer " + token(), "Content-Type": "application/json"})
    try:
        with urllib.request.urlopen(req) as r:
            data = r.read()
            return json.loads(data) if data else {}
    except urllib.error.HTTPError as e:
        print(f"HTTP {e.code} {method} {path}: {e.read().decode()[:600]}")
        return None


builds = call(f"/builds?filter[app]={APP}&sort=-uploadedDate&limit=5&include=preReleaseVersion,buildBetaDetail")
versions = {i["id"]: i["attributes"].get("version") for i in builds.get("included", []) if i["type"] == "preReleaseVersions"}
details = {i["id"]: i["attributes"] for i in builds.get("included", []) if i["type"] == "buildBetaDetails"}
print("== Son buildler ==")
for b in builds["data"]:
    a = b["attributes"]
    pv = b["relationships"]["preReleaseVersion"]["data"]
    bd = b["relationships"]["buildBetaDetail"]["data"]
    d = details.get(bd["id"], {}) if bd else {}
    print(f'{versions.get(pv["id"]) if pv else "?"} ({a["version"]}) islem={a["processingState"]} '
          f'sifreleme_beyani={a.get("usesNonExemptEncryption")} suresi_doldu={a.get("expired")} '
          f'ic={d.get("internalBuildState")} dis={d.get("externalBuildState")} yukleme={a["uploadedDate"]}')

groups = call(f"/apps/{APP}/betaGroups?limit=50")
print("== Beta gruplari ==")
for g in groups["data"]:
    a = g["attributes"]
    print(f'{a["name"]} ic={a.get("isInternalGroup")} tum_buildler={a.get("hasAccessToAllBuilds")} id={g["id"]}')

if "--add" in sys.argv and builds["data"]:
    latest = builds["data"][0]["id"]
    for g in groups["data"]:
        if g["attributes"].get("isInternalGroup") and not g["attributes"].get("hasAccessToAllBuilds"):
            r = call(f'/betaGroups/{g["id"]}/relationships/builds', "POST", {"data": [{"type": "builds", "id": latest}]})
            print(f'{g["attributes"]["name"]} grubuna eklendi: {r is not None}')
