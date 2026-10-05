import from core.planner { dashboard, save_task, set_done, delete_task }

def:pub Dashboard -> JsxElement {
    has data: dict = {}, title: str = "", course: str = "EECS 449", due: str = "",
        priority: str = "2", minutes: str = "30", budget: str = "120",
        query: str = "", view: str = "open", selected_course: str = "all",
        editing: str = "", error: str = "", message: str = "", busy: bool = False,
        loaded: bool = False;

    async def load {
        error = "";
        try {
            result = await dashboard("", int(budget), str(Date.now()));
            if result["ok"] {
                data = result;
                loaded = True;
                if not due { due = result["day"]; }
            } else { error = result["error"]; }
        } except Exception { error = "Could not reach your planner. Check the server and retry."; }
    }
    async can with entry { await load(); }
    def reset_form {
        title = ""; editing = ""; minutes = "30"; priority = "2";
    }
    async def submit(e: FormEvent) {
        e.preventDefault();
        busy = True; error = ""; message = "";
        try {
            result = await save_task(title, course, due, int(priority), int(minutes), editing);
            if result["ok"] { reset_form(); await load(); message = "Task saved. You have a plan."; }
            else { error = result["error"]; }
        } except Exception { error = "Unable to save. Check your connection and retry."; }
        busy = False;
    }
    async def complete(t: dict) {
        busy = True; message = "";
        try {
            result = await set_done(t["id"], not bool(t["done"]));
            if result["ok"] { await load(); message = "Progress saved."; }
            else { error = result["error"]; }
        } except Exception { error = "Unable to update. Please retry."; }
        busy = False;
    }
    def edit(t: dict) {
        editing = t["id"]; title = t["title"]; course = t["course"];
        due = t["due"]; priority = str(t["priority"]); minutes = str(t["minutes"]);
    }
    async def remove(t: dict) {
        if not window.confirm("Delete “" + t["title"] + "”? This cannot be undone.") { return; }
        busy = True;
        try {
            result = await delete_task(t["id"]);
            if result["ok"] {
                if editing == t["id"] { reset_form(); }
                await load(); message = "Task deleted.";
            } else { error = result["error"]; }
        } except Exception { error = "Unable to delete. Please retry."; }
        busy = False;
    }
    tasks = data["tasks"] if loaded else [];
    visible = [t for t in tasks if (view == "all" or (bool(t["done"]) if view == "done" else not bool(t["done"]))) and (selected_course == "all" or t["course"] == selected_course) and (query.lower() in (t["title"] + " " + t["course"]).lower())];
    stats = data["stats"] if loaded else {"open": 0, "done": 0, "overdue": 0, "minutes": 0, "courses": []};
    blocks = data["plan"]["blocks"] if loaded else [];

    return <div className="shell">
        <aside className="sidebar">
            <a className="brand" href="/" aria-label="Course Compass home"><span className="brand-icon">↗</span><span>course<br/>compass<span className="brand-dot">.</span></span></a>
            <div className="nav-label">YOUR WORKSPACE</div>
            <a className="nav-item active" href="#overview">◈ <span>Overview</span></a>
            <a className="nav-item" href="#tasks">☷ <span>Assignments</span></a>
            <a className="nav-item" href="#focus">◷ <span>Focus plan</span></a>
            <div className="nav-label course-heading">COURSE WORKLOAD</div>
            { [<button className="course-link" key={c["name"]} onClick={lambda { selected_course = c["name"]; }}><span className="course-mark">•</span><span>{c["name"]}</span><span className="count">{c["open"]}</span></button> for c in stats["courses"]] }
            <div className="sidebar-note"><span>SMALL STEPS. REAL PROGRESS.</span><p>You don't have to do everything.<br/>Just the next right thing.</p><div className="note-line"/></div>
            <div className="local-badge"><span/> Personal workspace · stored locally</div>
        </aside>
        <main id="overview">
            <header className="topbar"><span>MY PLANNER <span className="crumb">/ Overview</span></span><button className="quiet" disabled={busy} onClick={load}>↻ Refresh</button></header>
            <section className="intro"><div><div className="eyebrow">A LITTLE CLARITY GOES A LONG WAY</div><h1>Make room for<br/><em>what matters.</em></h1><p>Your coursework, your pace. Let's make today manageable.</p></div><div className="date-card"><span>TODAY'S CHECK-IN</span><strong>{data["day"] if loaded else "Connecting…"}</strong><div className="date-decoration">↗</div></div></section>
            {<div className="alert" role="alert">{error}<button onClick={load}>Retry</button></div> if error else None}
            {<p className="success" role="status">{message}</p> if message else None}
            <section className="stats" aria-label="Workload summary">
                <div><span>ON YOUR RADAR</span><strong>{stats["open"]}<small>open tasks</small></strong></div>
                <div><span>MAKING PROGRESS</span><strong>{stats["done"]}<small>completed</small></strong></div>
                <div className="urgent"><span>NEEDS A LITTLE LOVE</span><strong>{stats["overdue"]}<small>overdue</small></strong></div>
                <div><span>TIME TO INVEST</span><strong>{stats["minutes"]}<small>minutes left</small></strong></div>
            </section>
            <div className="workspace-grid"><section className="task-section" id="tasks">
                <div className="section-heading"><div className="eyebrow">THE BIG PICTURE</div><h2>Your assignments<span className="total">{len(tasks)}</span></h2></div>
                <div className="filters"><div className="tabs">{[<button key={v} className={"selected" if view == v else ""} onClick={lambda { view = v; }}>{v.capitalize()}</button> for v in ["open", "done", "all"]]}</div><select aria-label="Filter course" value={selected_course} onChange={lambda (e: ChangeEvent) { selected_course = e.target.value; }}><option value="all">All courses</option>{[<option key={c["name"]} value={c["name"]}>{c["name"]}</option> for c in stats["courses"]]}</select></div>
                <input className="search" aria-label="Search assignments" placeholder="Search your assignments…" value={query} onChange={lambda (e: ChangeEvent) { query = e.target.value; }}/>
                <div className="task-list">{[<article key={t["id"]} className={"task-card completed" if t["done"] else "task-card"}>
                    <button className="check" disabled={busy} aria-label={"Reopen " + t["title"] if t["done"] else "Complete " + t["title"]} onClick={lambda { complete(t); }}>{"✓" if t["done"] else ""}</button>
                    <div className="task-body"><div className="task-top"><span className="course-tag">{t["course"]}</span><span className={"priority p" + str(t["priority"])}>{["High", "Medium", "Low"][t["priority"] - 1]} priority</span></div><h3>{t["title"]}</h3><div className="task-meta"><span className={"overdue" if not t["done"] and t["due"] < data["day"] else ""}>◷ {t["due"]}{" · overdue" if not t["done"] and t["due"] < data["day"] else ""}</span><span>·</span><span>{t["minutes"]} min</span><button disabled={busy} onClick={lambda { edit(t); }}>Edit</button><button disabled={busy} aria-label={"Delete " + t["title"]} onClick={lambda { remove(t); }}>Delete</button></div></div>
                </article> for t in visible]}</div>
                {<div className="empty"><span>✧</span><h3>{"A fresh start." if len(tasks) == 0 else "A little breathing room."}</h3><p>{"Add your first assignment to turn your to-dos into a plan." if len(tasks) == 0 else "No assignments match this view. Try another filter."}</p></div> if loaded and len(visible) == 0 else None}
                {<p role="status">Loading your workspace…</p> if not loaded else None}
                <section className="add-card"><h2>{"Edit assignment" if editing else "Something on your mind?"}</h2><p>{"Update the details below." if editing else "Give it a place in your plan."}</p><form onSubmit={submit}>
                    <label>Assignment<input required={True} maxLength={160} placeholder="e.g. Finish the Jac planning project" value={title} onChange={lambda (e: ChangeEvent) { title = e.target.value; }}/></label>
                    <div className="form-row"><label>Course<input required={True} maxLength={40} value={course} onChange={lambda (e: ChangeEvent) { course = e.target.value; }}/></label><label>Due date<input required={True} type="date" value={due} onChange={lambda (e: ChangeEvent) { due = e.target.value; }}/></label></div>
                    <div className="form-row"><label>Priority<select value={priority} onChange={lambda (e: ChangeEvent) { priority = e.target.value; }}><option value="1">High — important</option><option value="2">Medium — steady</option><option value="3">Low — when there's room</option></select></label><label>Estimated minutes<input required={True} type="number" min="5" max="600" value={minutes} onChange={lambda (e: ChangeEvent) { minutes = e.target.value; }}/></label></div>
                    <div className="form-actions"><button className="primary" disabled={busy} type="submit">{"Saving…" if busy else ("Save changes" if editing else "+ Add to my plan")}</button>{<button type="button" className="quiet" onClick={reset_form}>Cancel edit</button> if editing else None}</div>
                </form></section>
            </section><aside className="focus-column" id="focus"><section className="focus-card"><div className="eyebrow">ONE THING AT A TIME</div><h2>Your focus plan<span>↗</span></h2><p>A realistic slice of your workload, ordered by deadline, then priority.</p><form className="budget" onSubmit={lambda (e: FormEvent) { e.preventDefault(); load(); }}><label htmlFor="budget">I have</label><input id="budget" type="number" min="5" max="720" required={True} value={budget} onChange={lambda (e: ChangeEvent) { budget = e.target.value; }}/><span>minutes today</span><button aria-label="Update focus budget">→</button></form>
                <div className="focus-blocks">{[<div className="focus-block" key={b["task"]["id"]}><span className="focus-dot"/><div><span className="focus-course">{b["task"]["course"]}</span><h3>{b["task"]["title"]}</h3><span>{b["minutes"]} min{" · partial session" if b["partial"] else " · full task"}</span></div></div> for b in blocks]}</div>
                {<p className="focus-empty">Your next focus session starts with an assignment.</p> if len(blocks) == 0 else None}
                <div className="focus-footer"><span>{data["plan"]["used"] if loaded else 0} min planned</span><span>{data["plan"]["remaining"] if loaded else 0} min breathing room</span></div>
            </section><div className="tip-card"><span className="tip-icon">✳</span><h3>Progress over pressure.</h3><p>Short on time? Your plan splits a large task into a smaller session. Mark it complete only when the whole assignment is done.</p></div><p className="sync-note">One workspace. Web, mobile, and terminal.<br/>Refresh to see changes from your other devices.</p></aside></div>
            <footer>COURSE COMPASS <span>A calmer way to get there.</span></footer>
        </main>
    </div>;
}
