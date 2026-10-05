import os;
import tempfile;
import from core.planner { dashboard, save_task, set_done, delete_task }

def _read(day: str = "", budget: int = 120) -> dict { return dashboard(day, budget, "test"); }
def _save(title: str, course: str, due: str, priority: int = 2, minutes: int = 30, task_id: str = "") -> dict {
    return save_task(title, course, due, priority, minutes, task_id);
}

test "sqlite lifecycle validation and independent connections" {
    with tempfile.TemporaryDirectory() as directory {
        old = os.environ.get("COMPASS_DB");
        os.environ["COMPASS_DB"] = directory + "/planner.sqlite3";
        try {
            assert _read()["tasks"] == [];
            assert not _save(" ", "EECS", "2026-10-05")["ok"];
            assert not _read(budget=0)["ok"];
            assert not _read(day="2026-02-30")["ok"];
            a = _save("  Read 'graphs'; DROP TABLE tasks; --  ", " EECS 449 ", "2026-10-05", 1, 50);
            assert a["ok"];
            id = a["id"];
            # Every endpoint opens/closes a distinct connection: this read must be durable.
            tasks = _read()["tasks"];
            assert len(tasks) == 1 and tasks[0]["course"] == "EECS 449";
            assert tasks[0]["title"].startswith("Read 'graphs'");
            assert set_done(id, True)["ok"] and set_done(id, True)["ok"];
            assert _read()["stats"]["done"] == 1;
            assert set_done(id, False)["ok"];
            assert _save("Revised", "MATH", "2026-10-06", 2, 20, id)["ok"];
            assert _read()["tasks"][0]["title"] == "Revised";
            assert not _save("Valid", "MATH", "2026-10-06", 2, 20, "missing")["ok"];
            assert not set_done("missing", True)["ok"];
            assert delete_task(id)["ok"];
            assert not delete_task(id)["ok"];
            assert _read()["tasks"] == [];
        } finally {
            if old is None { os.environ.pop("COMPASS_DB", None); }
            else { os.environ["COMPASS_DB"] = old; }
        }
    }
}
