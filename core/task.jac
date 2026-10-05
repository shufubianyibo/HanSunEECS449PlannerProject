"""Validation shared by the server and isolated domain tests."""
import from datetime { date }

def validate_task(title: str, course: str, due: str, priority: int, minutes: int) -> str {
    if not title.strip() or len(title.strip()) > 160 {
        return "Title must contain 1–160 characters.";
    }
    if not course.strip() or len(course.strip()) > 40 {
        return "Course must contain 1–40 characters.";
    }
    try {
        parsed = date.fromisoformat(due);
        if parsed.isoformat() != due { return "Use a real date in YYYY-MM-DD format."; }
    } except ValueError { return "Use a real date in YYYY-MM-DD format."; }
    if priority < 1 or priority > 3 { return "Priority must be 1 (high), 2 (medium), or 3 (low)."; }
    if minutes < 5 or minutes > 600 { return "Estimate must be between 5 and 600 minutes."; }
    return "";
}

def task_order(task: dict) -> tuple {
    return (task["due"], task["priority"], task["created"], task["id"]);
}

def allocate(tasks: list[dict], budget: int) -> dict {
    remaining = budget;
    blocks: list[dict] = [];
    for task in sorted([t for t in tasks if not t["done"]], key=task_order) {
        if remaining <= 0 { break; }
        minutes = min(remaining, task["minutes"]);
        blocks.append({"task": task, "minutes": minutes, "partial": minutes < task["minutes"]});
        remaining -= minutes;
    }
    return {"blocks": blocks, "used": budget - remaining, "remaining": remaining};
}
