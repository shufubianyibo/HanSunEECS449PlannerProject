import from core.task { validate_task, allocate }
import from core.course { summarize }

def _task(id: str, due: str, priority: int, minutes: int, done: int = 0) -> dict {
    return {"id": id, "title": id, "due": due, "priority": priority, "minutes": minutes,
        "done": done, "created": "2026-10-01", "course": "EECS 449"};
}

test "real dates and numeric boundaries" {
    assert validate_task("Write", "EECS", "2028-02-29", 1, 5) == "";
    assert validate_task("Write", "EECS", "2026-02-29", 1, 5) != "";
    assert validate_task("Write", "EECS", "20261005", 1, 5) != "";
    assert validate_task("Write", "EECS", "2026-10-05", 3, 600) == "";
    assert validate_task("Write", "EECS", "2026-10-05", 0, 30) != "";
    assert validate_task("Write", "EECS", "2026-10-05", 2, 601) != "";
    assert validate_task("Write", "EECS", "2026-10-05", 2, 4) != "";
}
test "empty and oversized fields" {
    assert validate_task("  ", "EECS", "2026-10-05", 2, 30) != "";
    assert validate_task("x" * 161, "EECS", "2026-10-05", 2, 30) != "";
    assert validate_task("Write", "  ", "2026-10-05", 2, 30) != "";
    assert validate_task("Write", "x" * 41, "2026-10-05", 2, 30) != "";
}
test "deadline then priority and partial allocation" {
    tasks = [_task("later", "2026-10-06", 1, 30), _task("low", "2026-10-05", 3, 60),
        _task("high", "2026-10-05", 1, 40), _task("done", "2026-10-01", 1, 20, 1)];
    result = allocate(tasks, 70);
    assert result["used"] == 70 and result["remaining"] == 0;
    assert [b["task"]["id"] for b in result["blocks"]] == ["high", "low"];
    assert result["blocks"][1]["minutes"] == 30;
    assert result["blocks"][1]["partial"];
    assert not tasks[1]["done"];
}
test "empty completed and surplus budgets" {
    assert allocate([], 120)["remaining"] == 120;
    assert allocate([_task("done", "2026-10-05", 1, 30, 1)], 120)["blocks"] == [];
    result = allocate([_task("open", "2026-10-05", 1, 30)], 120);
    assert result["remaining"] == 90 and not result["blocks"][0]["partial"];
}
test "overdue excludes today and completed tasks" {
    tasks = [_task("old", "2026-10-04", 1, 30), _task("today", "2026-10-05", 1, 40),
        _task("done", "2026-10-03", 1, 90, 1)];
    result = summarize(tasks, "2026-10-05");
    assert result["overdue"] == 1 and result["done"] == 1 and result["open"] == 2;
    assert result["minutes"] == 70;
    assert result["courses"][0]["open"] == 2;
}
