"""Server finto di game-services per la prova automatica: python Tools/mock_api.py 8099, poi -- --smoke-test --api=http://127.0.0.1:8099"""
import json, sys, uuid, datetime
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

STATE = {"players": {}, "runs": [], "balance": {}, "claimed": set(), "owned": {}}
CATALOG = [("pigeon", "bird", 0, "common"), ("crow", "bird", 2500, "special"), ("classic", "feathers", 0, "common"),
           ("dove", "feathers", 250, "common"), ("cap", "head", 150, "common"), ("sunglasses", "face", 180, "common"),
           ("cowbell", "neck", 200, "common"), ("owl", "bird", 1500, "rare"), ("unicorn", "bird", 5000, "legendary"),
           ("contrail", "trail", 300, "common"), ("rainbow_trail", "trail", 2500, "special"),
           ("bubblegum", "splat", 250, "common"), ("rainbow_splat", "splat", 2000, "special"),
           ("dragon_wings", "bird", 100, "common")]  # l'ultimo: sconosciuto al gioco


def shop(token):
    owned = STATE["owned"].get(token, set())
    items = [{"id": i, "category": c, "price": p, "tier": t, "owned": p == 0 or i in owned, "availableUntil": None}
             for i, c, p, t in CATALOG]
    return {"balance": STATE["balance"].get(token, 0), "items": items}
REQUIRED_STATS = {"hits", "nearMisses", "bestCombo", "continuesUsed", "busHits", "truckHits", "nightDistance", "goldenCrumbs"}


def missions(token):
    runs = [r for r in STATE["runs"] if r["token"] == token and r["ranked"]]
    dist = sum(r["distanceM"] for r in runs)
    hits = sum(r["stats"]["hits"] for r in runs)
    defs = [("fly", "Fly {0} m in total", 100, dist, 30), ("splats", "Splat {0} vehicles", 1000, hits, 50),
            ("daily", "Fly today's challenge", 1, sum(1 for r in runs if r["mode"] == "daily"), 50)]
    out = []
    for mid, title, target, progress, reward in defs:
        out.append({"id": mid, "title": title.format(target), "target": target, "progress": int(progress),
                    "reward": reward, "complete": progress >= target, "claimed": (token, mid) in STATE["claimed"]})
    return {"date": datetime.date.today().isoformat(), "resetsAt": "2099-01-01T00:00:00Z", "missions": out,
            "balance": STATE["balance"].get(token, 0)}


class Handler(BaseHTTPRequestHandler):
    def log_message(self, *args):
        pass

    def _send(self, status, body=None):
        data = json.dumps(body).encode() if body is not None else b""
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def _token(self):
        auth = self.headers.get("Authorization", "")
        token = auth.removeprefix("Bearer ")
        return token if token in STATE["players"] else None

    def _body(self):
        length = int(self.headers.get("Content-Length", 0) or 0)
        return json.loads(self.rfile.read(length) or b"{}") if length else {}

    def do_GET(self):
        token = self._token()
        if "/leaderboards/" in self.path:
            return self._send(200, {"entries": [], "total": 0, "me": None})
        if token is None:
            return self._send(401, {"error": "unauthorized"})
        if self.path.endswith("/wallet"):
            return self._send(200, {"balance": STATE["balance"].get(token, 0), "earnedToday": 0, "dailyCap": 1500})
        if self.path.endswith("/missions"):
            return self._send(200, missions(token))
        if "/shop" in self.path:
            return self._send(200, shop(token))
        self._send(404, {"error": "not_found"})

    def do_PATCH(self):
        self._send(200, {"playerId": "p", "displayName": "SmokePigeon", "nameSuffix": 1})

    def do_DELETE(self):
        self._send(204)

    def do_POST(self):
        body = self._body()
        if self.path == "/v1/players":
            token = uuid.uuid4().hex
            STATE["players"][token] = True
            STATE["balance"][token] = 300  # saldo di partenza, per provare il negozio
            return self._send(201, {"playerId": str(uuid.uuid4()), "token": token, "displayName": "SmokePigeon", "nameSuffix": 42})
        token = self._token()
        if token is None:
            return self._send(401, {"error": "unauthorized"})
        if self.path.endswith("/runs/start"):
            return self._send(201, {"runId": str(uuid.uuid4())})
        if self.path.endswith("/runs"):
            missing = REQUIRED_STATS - set(body.get("stats", {}))
            if missing:
                print("mock: statistiche mancanti", sorted(missing), file=sys.stderr)
                return self._send(400, {"error": "missing_stats"})
            ranked = body.get("runId") is not None
            body["token"], body["ranked"] = token, ranked
            STATE["runs"].append(body)
            earned = min(200, int(body["distanceM"] / 100) + 5 * int(body["stats"]["goldenCrumbs"])) if ranked else 0
            STATE["balance"][token] = STATE["balance"].get(token, 0) + earned
            return self._send(200, {"accepted": True, "ranked": ranked, "personalBest": True, "rank": 3, "weekRank": 2,
                                    "crumbsEarned": earned, "balance": STATE["balance"][token]})
        if self.path.endswith("/shop/buy"):
            item = next((c for c in CATALOG if c[0] == body.get("itemId")), None)
            if item is None:
                return self._send(404, {"error": "unknown_item"})
            owned = STATE["owned"].setdefault(token, set())
            if item[0] not in owned and item[2] > 0:
                if STATE["balance"].get(token, 0) < item[2]:
                    return self._send(409, {"error": "insufficient_funds"})
                STATE["balance"][token] = STATE["balance"].get(token, 0) - item[2]
                owned.add(item[0])
            return self._send(200, shop(token))
        if "/missions/" in self.path and self.path.endswith("/claim"):
            mid = self.path.split("/")[-2]
            m = next((m for m in missions(token)["missions"] if m["id"] == mid), None)
            if m is None:
                return self._send(404, {"error": "unknown_mission"})
            if not m["complete"]:
                return self._send(422, {"error": "not_complete"})
            if (token, mid) not in STATE["claimed"]:
                STATE["claimed"].add((token, mid))
                STATE["balance"][token] = STATE["balance"].get(token, 0) + m["reward"]
            return self._send(200, missions(token))
        self._send(404, {"error": "not_found"})


if __name__ == "__main__":
    ThreadingHTTPServer(("127.0.0.1", int(sys.argv[1]) if len(sys.argv) > 1 else 8099), Handler).serve_forever()
