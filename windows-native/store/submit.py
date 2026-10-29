"""Soumet un paquet .msix au Microsoft Store (API de soumission de Partner Center), sans outil à installer.

    python windows-native/store/submit.py <paquet.msix> [--notes fichier.txt] [--attendre]

Identifiants : windows-native/store/store.env (local, non versionné ; modèle : store.env.example).
Étapes : jeton Azure AD → soumission brouillon (copie de la dernière publiée, l'ancienne en attente est
supprimée) → ancien paquet remplacé, « Nouveautés » mises à jour dans chaque langue → envoi du paquet
→ validation (« Envoyer au Store »). Ensuite, Microsoft certifie (quelques heures à quelques jours).
"""
import argparse
import io
import json
import os
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
import zipfile

API = "https://manage.devcenter.microsoft.com/v1.0/my"
HERE = os.path.dirname(os.path.abspath(__file__))


def settings():
    values = {}
    path = os.path.join(HERE, "store.env")
    if os.path.exists(path):
        for line in open(path, encoding="utf-8"):
            line = line.strip()
            if line and not line.startswith("#") and "=" in line:
                key, value = line.split("=", 1)
                values[key.strip()] = value.strip().strip('"')
    names = ["STORE_TENANT_ID", "STORE_CLIENT_ID", "STORE_CLIENT_SECRET", "STORE_APP_ID"]
    missing = [n for n in names if not (os.environ.get(n) or values.get(n))]
    if missing:
        sys.exit(f"Identifiants manquants dans windows-native/store/store.env : {', '.join(missing)} (voir store.env.example)")
    return {n: os.environ.get(n) or values[n] for n in names}


def request(method, url, token=None, body=None, raw=None, headers=None):
    data = raw if raw is not None else (json.dumps(body).encode() if body is not None else None)
    req = urllib.request.Request(url, data=data, method=method)
    if token:
        req.add_header("Authorization", f"Bearer {token}")
    if body is not None:
        req.add_header("Content-Type", "application/json")
    for k, v in (headers or {}).items():
        req.add_header(k, v)
    try:
        with urllib.request.urlopen(req, timeout=600) as r:
            text = r.read().decode() or "null"
            return json.loads(text) if r.headers.get("Content-Type", "").startswith("application/json") else text
    except urllib.error.HTTPError as e:
        sys.exit(f"{method} {url.split('?')[0]} : {e.code} {e.read().decode(errors='replace')[:800]}")


def token(s):
    form = urllib.parse.urlencode({
        "grant_type": "client_credentials", "client_id": s["STORE_CLIENT_ID"],
        "client_secret": s["STORE_CLIENT_SECRET"], "resource": "https://manage.devcenter.microsoft.com",
    }).encode()
    url = f"https://login.microsoftonline.com/{s['STORE_TENANT_ID']}/oauth2/token"
    return request("POST", url, raw=form, headers={"Content-Type": "application/x-www-form-urlencoded"})["access_token"]


def main():
    args = argparse.ArgumentParser()
    args.add_argument("msix")
    args.add_argument("--notes", help="texte des « Nouveautés de cette version »")
    args.add_argument("--attendre", action="store_true", help="attendre la fin des vérifications automatiques")
    a = args.parse_args()
    if not os.path.exists(a.msix):
        sys.exit(f"Paquet introuvable : {a.msix}")
    notes = open(a.notes, encoding="utf-8").read().strip() if a.notes else None

    s = settings()
    t = token(s)
    app = f"{API}/applications/{s['STORE_APP_ID']}"
    info = request("GET", app, t)
    print(f"Appli : {info.get('primaryName', s['STORE_APP_ID'])}")
    pending = info.get("pendingApplicationSubmission")
    if pending:
        # L'API ne peut supprimer que ses propres brouillons : un brouillon ouvert dans Partner Center
        # doit y être supprimé à la main (« Supprimer la soumission »).
        request("DELETE", f"{app}/submissions/{pending['id']}", t)
        print(f"Soumission en attente {pending['id']} supprimée (remplacée par celle-ci).")

    sub = request("POST", f"{app}/submissions", t)
    print(f"Soumission {sub['id']} créée.")
    name = os.path.basename(a.msix)
    for p in sub.get("applicationPackages", []):
        p["fileStatus"] = "PendingDelete"
    sub["applicationPackages"].append({
        "fileName": name, "fileStatus": "PendingUpload",
        "minimumDirectXVersion": "None", "minimumSystemRam": "None",
    })
    if notes:
        for lang, listing in sub.get("listings", {}).items():
            listing.setdefault("baseListing", {})["releaseNotes"] = notes[:1500]
    upload_url = sub["fileUploadUrl"]
    request("PUT", f"{app}/submissions/{sub['id']}", t, body=sub)

    buf = io.BytesIO()
    with zipfile.ZipFile(buf, "w", zipfile.ZIP_STORED) as z:
        z.write(a.msix, name)
    size = buf.tell()
    print(f"Envoi du paquet ({size // 1_000_000} Mo)…")
    request("PUT", upload_url, raw=buf.getvalue(), headers={"x-ms-blob-type": "BlockBlob"})

    request("POST", f"{app}/submissions/{sub['id']}/commit", t)
    print("Soumission envoyée au Store.")
    status = None
    deadline = time.time() + (3600 if a.attendre else 300)
    while time.time() < deadline:
        time.sleep(15)
        state = request("GET", f"{app}/submissions/{sub['id']}/status", t)
        status = state.get("status")
        if status == "CommitFailed":
            errors = state.get("statusDetails", {}).get("errors", [])
            sys.exit("Refusée à la validation : " + "; ".join(f"{e.get('code')} {e.get('details')}" for e in errors))
        if status != "CommitStarted" and not (a.attendre and status == "PreProcessing"):
            break
    print(f"État : {status} (suivi : https://partner.microsoft.com/dashboard/products/{s['STORE_APP_ID']}/submissions/{sub['id']})")


if __name__ == "__main__":
    main()
