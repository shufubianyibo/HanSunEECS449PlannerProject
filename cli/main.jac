"""Jac CLI client. Uses HTTP only; never opens the server's database."""
import argparse;
import json;
import os;
import sys;
import from urllib.request { Request, urlopen }
import from urllib.error { URLError }

def _call(server: str, name: str, payload: dict) -> dict {
    request = Request(server.rstrip("/") + "/function/" + name,
        data=json.dumps(payload).encode(), headers={"Content-Type": "application/json"}, method="POST");
    with urlopen(request, timeout=15) as response { envelope = json.loads(response.read()); }
    if not envelope.get("ok", False) { raise RuntimeError(str(envelope.get("error", "Server rejected request."))); }
    result = envelope["data"]["result"];
    if not result["ok"] { raise ValueError(result["error"]); }
    return result;
}

def main(argv: list[str]) -> int {
    parser = argparse.ArgumentParser(description="Course Compass — plan coursework from your terminal.");
    parser.add_argument("--server", `default=os.environ.get("COMPASS_URL", "http://127.0.0.1:8000"));
    parser.add_argument("--json", action="store_true", help="Print machine-readable output");
    commands = parser.add_subparsers(dest="command", required=True);
    add = commands.add_parser("add", help="Add an assignment");
    add.add_argument("title"); add.add_argument("--course", `default="Personal");
    add.add_argument("--due", required=True); add.add_argument("--priority", type=int, choices=[1,2,3], `default=2);
    add.add_argument("--minutes", type=int, `default=30);
    ls = commands.add_parser("list", help="List tasks");
    ls.add_argument("--all", action="store_true"); ls.add_argument("--course", `default="");
    today = commands.add_parser("today", help="Build a deadline-first study plan");
    today.add_argument("--budget", type=int, `default=120); today.add_argument("--day", `default="");
    for command in ["done", "reopen"] {
        sub = commands.add_parser(command); sub.add_argument("id", help="Full task UUID from list --all");
    }
    delete = commands.add_parser("delete"); delete.add_argument("id");
    delete.add_argument("--yes", action="store_true", help="Confirm permanent deletion");
    args = parser.parse_args(argv);
    try {
        if args.command == "add" {
            result = _call(args.server, "save_task", {"title": args.title, "course": args.course, "due": args.due, "priority": args.priority, "minutes": args.minutes, "task_id": ""});
        } elif args.command in ["done", "reopen"] {
            result = _call(args.server, "set_done", {"task_id": args.id, "done": args.command == "done"});
        } elif args.command == "delete" {
            if not args.yes { print("Deletion requires --yes.", file=sys.stderr); return 2; }
            result = _call(args.server, "delete_task", {"task_id": args.id});
        } else {
            result = _call(args.server, "dashboard", {"day": args.day, "budget": args.budget, "refresh": "cli"} if args.command == "today" else {"day": "", "budget": 120, "refresh": "cli"});
        }
        if args.json { print(json.dumps(result, ensure_ascii=False)); return 0; }
        if args.command == "list" {
            count = 0;
            for task in result["tasks"] {
                if (args.all or not task["done"]) and (not args.course or task["course"] == args.course) {
                    mark = "x" if task["done"] else " ";
                    print(f"[{mark}] {task['title']} | {task['course']} | due {task['due']} | P{task['priority']} | {task['minutes']} min\n    {task['id']}");
                    count += 1;
                }
            }
            if not count { print("No tasks in this view. Add one with: jac run cli -- add TITLE --due YYYY-MM-DD"); }
        } elif args.command == "today" {
            print(f"FOCUS PLAN · {result['day']}");
            for block in result["plan"]["blocks"] {
                suffix = " (partial session)" if block["partial"] else "";
                print(f"  {block['minutes']} min · {block['task']['title']}{suffix}");
            }
            print(f"Planned: {result['plan']['used']} min · Remaining: {result['plan']['remaining']} min");
        } else { print("Saved: " + result["id"]); }
        return 0;
    } except (URLError, TimeoutError) as exc {
        print("Cannot reach Course Compass. Start `jac run` and check --server. " + str(exc), file=sys.stderr);
        return 3;
    } except (ValueError, RuntimeError, KeyError) as exc { print(str(exc), file=sys.stderr); return 1; }
}

with entry:__main__ {
    argv = sys.argv[1:];
    if argv and argv[0] == "--" { argv = argv[1:]; }
    sys.exit(main(argv));
}
