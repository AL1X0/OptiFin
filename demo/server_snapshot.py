"""Copie locale du serveur Jellyfin de démonstration public, pour des captures réelles et reproductibles.

    python demo/server_snapshot.py            # récupère ce qui manque (build/demo/server/misses.txt)

L'app (demo/server_snapshot.dart) rejoue les réponses enregistrées dans build/demo/server/ et note
chaque requête ou image absente dans misses.txt : relancer ce script puis la capture jusqu'à ce
qu'il ne manque plus rien. Serveur : https://demo.jellyfin.org/stable, utilisateur « demo » sans
mot de passe (public).
"""
import json
import os
import sys
import urllib.error
import urllib.request

BASE = os.environ.get("OPTIFIN_SNAPSHOT_SERVER", "https://demo.jellyfin.org/stable")
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "build", "demo", "server")
AUTH = 'MediaBrowser Client="OptiFin", Device="Captures", DeviceId="optifin-captures", Version="1.0"'


def call(method, path, token=None, body=None, raw=False):
    headers = {"Authorization": AUTH + (f', Token="{token}"' if token else ""), "Content-Type": "application/json"}
    data = json.dumps(body).encode() if body is not None else (b"{}" if method == "POST" else None)
    req = urllib.request.Request(f"{BASE}/{path.lstrip('/')}", data=data, method=method, headers=headers)
    try:
        with urllib.request.urlopen(req, timeout=60) as r:
            content = r.read()
            return r.status, content if raw else (json.loads(content) if content else None)
    except urllib.error.HTTPError as e:
        return e.code, None


def main():
    os.makedirs(os.path.join(OUT, "images"), exist_ok=True)
    status, auth = call("POST", "Users/AuthenticateByName", body={"Username": "demo", "Pw": ""})
    if status != 200:
        sys.exit(f"Connexion au serveur de démonstration impossible ({status})")
    token, user = auth["AccessToken"], auth["User"]["Id"]
    _, info = call("GET", "System/Info/Public")
    with open(os.path.join(OUT, "meta.json"), "w", encoding="utf-8") as f:
        json.dump({"server": BASE, "userId": user, "userName": auth["User"]["Name"],
                   "serverName": info.get("ServerName"), "version": info.get("Version")}, f, indent=1)

    path = os.path.join(OUT, "responses.json")
    responses = json.load(open(path, encoding="utf-8")) if os.path.exists(path) else {}
    misses_path = os.path.join(OUT, "misses.txt")
    misses = sorted(set(open(misses_path, encoding="utf-8").read().split("\n"))) if os.path.exists(misses_path) else []
    got = 0
    for line in filter(None, misses):
        kind, _, key = line.partition(" ")
        if kind == "IMG" and key.startswith("Frames/"):
            # Vraie image du film pour le lecteur simulé : extraite du flux à 40 % de sa durée.
            item_id = key.split("/")[1]
            file = os.path.join(OUT, "images", key.replace("/", "_") + ".jpg")
            if os.path.exists(file):
                continue
            _, item = call("GET", f"Items/{item_id}?userId={user}", token)
            seconds = ((item or {}).get("RunTimeTicks") or 0) / 1e7 * 0.4
            url = f"{BASE}/Videos/{item_id}/stream?static=true&api_key={token}"
            os.system(f'ffmpeg -loglevel error -y -ss {seconds:.0f} -i "{url}" -frames:v 1 -q:v 2 "{file}"')
            if not os.path.exists(file):
                open(file, "wb").write(b"")
            got += 1
        elif kind == "IMG":
            # key : Items/{id}/Images/{Type}[/{index}] (taille bornée, qualité suffisante pour un écran 3x).
            file = os.path.join(OUT, "images", key.replace("/", "_") + ".jpg")
            if os.path.exists(file):
                continue
            status, content = call("GET", f"{key}?maxWidth=1800&quality=90", token, raw=True)
            if status == 200 and content:
                open(file, "wb").write(content)
            else:
                open(file, "wb").write(b"")  # absente sur le serveur : ne plus la demander
            got += 1
        elif key not in responses:
            status, body = call(kind, key, token, body={} if kind == "POST" else None)
            responses[key if kind == "GET" else f"{kind} {key}"] = {"status": status, "body": body}
            got += 1
    with open(path, "w", encoding="utf-8") as f:
        json.dump(responses, f, ensure_ascii=False)
    if os.path.exists(misses_path):
        os.remove(misses_path)
    print(f"{got} élément(s) récupéré(s) ; {len(responses)} réponses en tout ({OUT})")


if __name__ == "__main__":
    main()
