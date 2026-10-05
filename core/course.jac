"""Course workload summary; courses arise naturally from task labels."""
def summarize(tasks: list[dict], today: str) -> dict {
    courses: dict = {};
    done = 0;
    overdue = 0;
    minutes = 0;
    for task in tasks {
        course = task["course"];
        if course not in courses { courses[course] = {"name": course, "open": 0, "minutes": 0}; }
        if task["done"] { done += 1; }
        else {
            minutes += task["minutes"];
            courses[course]["open"] += 1;
            courses[course]["minutes"] += task["minutes"];
            if task["due"] < today { overdue += 1; }
        }
    }
    return {"total": len(tasks), "done": done, "open": len(tasks) - done,
            "overdue": overdue, "minutes": minutes, "courses": list(courses.values())};
}
