"""HTTP + Jac CLI black-box tests against a running disposable/local server.
Only removes the test's own UUIDs. Run: python3 tests/integration.py
"""
import concurrent.futures
import json
import os
import subprocess
import urllib.error
import urllib.request
import uuid

URL = os.environ.get("COMPASS_URL", "http://127.0.0.1:8000")
PREFIX = "integration-" + uuid.uuid4().hex[:8]
ids = []
checks = 0


def api(name, **payload):
    req = urllib.request.Request(URL + "/function/" + name, json.dumps(payload).encode(),
                                 {"Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=20) as response:
        value = json.load(response)
    assert value["ok"], value
    return value["data"]["result"]


def cli(*args, code=0):
    proc = subprocess.run(["jac", "run", "cli", "--", "--server", URL, *args],
                          capture_output=True, text=True, timeout=60)
    assert proc.returncode == code, (args, proc.returncode, proc.stdout, proc.stderr)
    return proc.stdout


def check(condition, name):
    global checks
    assert condition, name
    checks += 1
    print("PASS", name)


def read():
    return api("dashboard", day="2026-10-05", budget=65, refresh=uuid.uuid4().hex)


try:
    added = json.loads(cli("--json", "add", PREFIX, "--course", "QA", "--due", "2026-10-05", "--priority", "1", "--minutes", "90"))
    ids.append(added["id"])
    check(any(t["id"] == ids[0] for t in read()["tasks"]), "CLI add visible through HTTP")
    check(PREFIX in cli("list", "--all", "--course", "QA"), "human-readable CLI list")
    check("FOCUS PLAN" in cli("today", "--budget", "65"), "CLI focus plan")
    check(api("set_done", task_id=ids[0], done=True)["ok"], "HTTP complete")
    listed = json.loads(cli("--json", "list", "--all"))
    check(next(t for t in listed["tasks"] if t["id"] == ids[0])["done"] == 1, "HTTP mutation visible in CLI")
    cli("reopen", ids[0])
    check(next(t for t in read()["tasks"] if t["id"] == ids[0])["done"] == 0, "CLI reopen visible in HTTP")
    check(not api("save_task", title=" ", course="QA", due="2026-10-05", priority=2, minutes=30, task_id="")["ok"], "blank title rejected")
    check(not api("save_task", title="bad", course="QA", due="2026-02-30", priority=2, minutes=30, task_id="")["ok"], "invalid date rejected")
    check(not api("dashboard", day="", budget=0, refresh="invalid")["ok"], "invalid budget rejected")
    check(not api("set_done", task_id="missing", done=True)["ok"], "missing task rejected")
    cli("delete", ids[0], code=2)
    check(any(t["id"] == ids[0] for t in read()["tasks"]), "unconfirmed deletion preserves task")
    cli("done", ids[0])
    cli("done", ids[0])
    check(next(t for t in read()["tasks"] if t["id"] == ids[0])["done"] == 1, "completion retry is idempotent")
    cli("add", "invalid", "--due", "not-a-date", code=1)
    def add_parallel(index):
        result = api("save_task", title=f"{PREFIX}-{index}", course="QA", due="2026-10-06", priority=2, minutes=15, task_id="")
        assert result["ok"]
        return result["id"]
    with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:
        ids.extend(pool.map(add_parallel, range(8)))
    check(len([t for t in read()["tasks"] if t["id"] in ids]) == 9, "eight concurrent writes persist without lost tasks")
    cli("delete", ids[0], "--yes")
    check(not any(t["id"] == ids[0] for t in read()["tasks"]), "confirmed CLI delete visible in HTTP")
    print(f"\n{checks} integration checks passed")
finally:
    for task_id in ids:
        api("delete_task", task_id=task_id)
