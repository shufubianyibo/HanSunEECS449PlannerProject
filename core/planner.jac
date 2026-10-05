"""Single-user local API. All SQL uses bound parameters and short transactions."""
import os;
import sqlite3;
import from pathlib { Path }
import from uuid { uuid4 }
import from datetime { date, datetime, timezone }
import from core.task { validate_task, allocate }
import from core.course { summarize }

def _connect() -> any {
    fallback = str(Path(__file__).resolve().parent.parent / "data" / "planner.sqlite3");
    path = Path(os.environ.get("COMPASS_DB", fallback)).expanduser().resolve();
    path.parent.mkdir(parents=True, exist_ok=True);
    conn = sqlite3.connect(str(path), timeout=10);
    conn.row_factory = sqlite3.Row;
    conn.execute("PRAGMA journal_mode=WAL");
    conn.execute("CREATE TABLE IF NOT EXISTS tasks (id TEXT PRIMARY KEY, title TEXT NOT NULL, course TEXT NOT NULL, due TEXT NOT NULL, priority INTEGER NOT NULL CHECK(priority BETWEEN 1 AND 3), minutes INTEGER NOT NULL CHECK(minutes BETWEEN 5 AND 600), done INTEGER NOT NULL DEFAULT 0 CHECK(done IN (0,1)), created TEXT NOT NULL)");
    conn.commit();
    return conn;
}

def _today(value: str) -> str {
    if not value { return date.today().isoformat(); }
    parsed = date.fromisoformat(value);
    if parsed.isoformat() != value { raise ValueError("Use YYYY-MM-DD."); }
    return value;
}

def:pub dashboard(day: str, budget: int, refresh: str) -> dict {
    # refresh is a client nonce: bypass Jac's reader cache after other clients write.
    if budget < 5 or budget > 720 { return {"ok": False, "error": "Daily budget must be 5–720 minutes."}; }
    try { today = _today(day); }
    except ValueError { return {"ok": False, "error": "Use a real date in YYYY-MM-DD format."}; }
    conn = _connect();
    try { tasks = [dict(row) for row in conn.execute("SELECT * FROM tasks ORDER BY done, due, priority, created, id").fetchall()]; }
    finally { conn.close(); }
    plan = allocate(tasks, budget);
    return {"ok": True, "day": today, "tasks": tasks, "stats": summarize(tasks, today), "plan": plan};
}

def:pub save_task(title: str, course: str, due: str, priority: int, minutes: int, task_id: str) -> dict {
    error = validate_task(title, course, due, priority, minutes);
    if error { return {"ok": False, "error": error}; }
    conn = _connect();
    try {
        with conn {
            if task_id {
                cur = conn.execute("UPDATE tasks SET title=?, course=?, due=?, priority=?, minutes=? WHERE id=?", (title.strip(), course.strip(), due, priority, minutes, task_id));
                if cur.rowcount == 0 { return {"ok": False, "error": "Task not found. Refresh your list."}; }
            } else {
                task_id = str(uuid4());
                conn.execute("INSERT INTO tasks VALUES (?,?,?,?,?,?,0,?)", (task_id, title.strip(), course.strip(), due, priority, minutes, datetime.now(timezone.utc).isoformat()));
            }
        }
    } finally { conn.close(); }
    return {"ok": True, "id": task_id};
}

def:pub set_done(task_id: str, done: bool) -> dict {
    conn = _connect();
    try {
        with conn {
            cur = conn.execute("UPDATE tasks SET done=? WHERE id=?", (int(done), task_id));
            if cur.rowcount == 0 { return {"ok": False, "error": "Task not found. Refresh your list."}; }
        }
    } finally { conn.close(); }
    return {"ok": True, "id": task_id};
}

def:pub delete_task(task_id: str) -> dict {
    conn = _connect();
    try {
        with conn {
            cur = conn.execute("DELETE FROM tasks WHERE id=?", (task_id,));
            if cur.rowcount == 0 { return {"ok": False, "error": "Task not found. Refresh your list."}; }
        }
    } finally { conn.close(); }
    return {"ok": True, "id": task_id};
}
