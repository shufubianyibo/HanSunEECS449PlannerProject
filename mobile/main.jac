import from "@jac/mobui" { View, Text, Pressable, TextInput, ScrollView, StyleSheet }
import from core.planner { dashboard, save_task, set_done }

glob styles = StyleSheet.create({
    screen: {flex: 1, backgroundColor: "#f5f6ee"},
    body: {padding: 24, paddingTop: 40, paddingBottom: 60, gap: 16, maxWidth: 600, width: "100%", alignSelf: "center"},
    eyebrow: {fontSize: 10, fontWeight: "bold", color: "#7c8c68", letterSpacing: 2},
    heading: {fontSize: 34, color: "#173e35", fontWeight: "bold"},
    muted: {fontSize: 13, color: "#788872", lineHeight: 21},
    card: {backgroundColor: "#ffffff", borderRadius: 16, padding: 20, gap: 12},
    dark: {backgroundColor: "#173e35", borderRadius: 16, padding: 22, gap: 14},
    light: {color: "#e8f0db", fontSize: 17, fontWeight: "bold"},
    lightMuted: {color: "#bbceb0", fontSize: 12, lineHeight: 20},
    title: {fontSize: 17, color: "#294731", fontWeight: "bold"},
    input: {borderWidth: 1, borderColor: "#dce3d1", borderRadius: 8, padding: 13, color: "#173e35", fontSize: 15, backgroundColor: "#ffffff"},
    button: {backgroundColor: "#173e35", padding: 14, borderRadius: 9, alignItems: "center"},
    buttonText: {color: "#ffffff", fontWeight: "bold", fontSize: 14},
    secondary: {backgroundColor: "#e4ebda", padding: 13, borderRadius: 9, alignItems: "center"},
    secondaryText: {color: "#315a3d", fontSize: 14},
    row: {flexDirection: "row", gap: 12, justifyContent: "space-between", alignItems: "center"},
    error: {backgroundColor: "#f6e4d7", padding: 14, borderRadius: 8},
    errorText: {color: "#984929", fontSize: 13},
    divider: {height: 1, backgroundColor: "#3e6250"}
});

def:pub app -> JsxElement {
    has tasks: list[dict] = [], blocks: list[dict] = [], day: str = "", budget: str = "120",
        title: str = "", course: str = "Personal", due: str = "", minutes: str = "30",
        server: str = "", error: str = "", message: str = "", busy: bool = False, completed: int = 0;
    async def refresh {
        busy = True; error = "";
        try {
            result = await dashboard("", int(budget), str(Date.now()));
            if result["ok"] {
                tasks = [t for t in result["tasks"] if not t["done"]];
                blocks = result["plan"]["blocks"]; day = result["day"];
                completed = result["stats"]["done"];
                if not due { due = day; }
            } else { error = result["error"]; }
        } except Exception { error = "Cannot reach your planner. Check the backend address and tap Refresh."; }
        busy = False;
    }
    async can with entry { await refresh(); }
    async def connect {
        if server and not (server.startswith("http://") or server.startswith("https://")) {
            error = "Server address must begin with http:// or https://.";
            return;
        }
        globalThis.__JAC_API_BASE_URL__ = server.strip().rstrip("/");
        await refresh();
    }
    async def finish(t: dict) {
        busy = True; error = "";
        try {
            result = await set_done(t["id"], True);
            if result["ok"] { await refresh(); message = "Completed: " + t["title"]; }
            else { error = result["error"]; }
        } except Exception { error = "Could not save your progress. Please retry."; }
        busy = False;
    }
    async def add {
        busy = True; error = "";
        try {
            result = await save_task(title, course, due, 2, int(minutes), "");
            if result["ok"] { title = ""; await refresh(); message = "Assignment added."; }
            else { error = result["error"]; }
        } except Exception { error = "Could not add task. Check the fields and your connection."; }
        busy = False;
    }
    return <View style={styles.screen}><ScrollView contentContainerStyle={styles.body} keyboardShouldPersistTaps="handled">
        <Text style={styles.eyebrow}>COURSE COMPASS ↗</Text><Text style={styles.heading}>One thing at a time.</Text>
        <View style={styles.row}><Text style={styles.muted}>{day} · {str(completed)} completed</Text><Pressable accessibilityRole="button" disabled={busy} onPress={refresh} style={styles.secondary}><Text style={styles.secondaryText}>{"Syncing…" if busy else "↻ Refresh"}</Text></Pressable></View>
        {<View style={styles.error}><Text accessibilityRole="alert" style={styles.errorText}>{error}</Text></View> if error else <View/>}
        {<Text style={styles.muted}>{message}</Text> if message else <View/>}
        <View style={styles.dark}><Text style={styles.light}>Today's focus plan</Text><Text style={styles.lightMuted}>Deadline first, then priority. Partial sessions fit your available time.</Text><TextInput style={styles.input} accessibilityLabel="Daily budget in minutes" value={budget} keyboardType="numeric" onChangeText={lambda (s: str) { budget = s; }}/><Pressable accessibilityRole="button" disabled={busy} style={styles.secondary} onPress={refresh}><Text style={styles.secondaryText}>Plan my minutes</Text></Pressable>
            {[<View key={b["task"]["id"]}><View style={styles.divider}/><Text style={styles.lightMuted}>{b["task"]["course"]} · {str(b["minutes"])} min{" · partial" if b["partial"] else ""}</Text><Text style={styles.light}>{b["task"]["title"]}</Text></View> for b in blocks]}
            {<Text style={styles.lightMuted}>Room to breathe. Add a task below to get started.</Text> if len(blocks) == 0 else <View/>}
        </View>
        <Text style={styles.title}>On your radar · {str(len(tasks))}</Text>
        {[<View key={t["id"]} style={styles.card}><Text style={styles.eyebrow}>{t["course"]} · P{str(t["priority"])}</Text><Text style={styles.title}>{t["title"]}</Text><Text style={styles.muted}>Due {t["due"]}{" · overdue" if t["due"] < day else ""} · {str(t["minutes"])} min</Text><Pressable accessibilityRole="button" accessibilityLabel={"Complete " + t["title"]} disabled={busy} style={styles.secondary} onPress={lambda { finish(t); }}><Text style={styles.secondaryText}>✓ Mark complete</Text></Pressable></View> for t in tasks]}
        <View style={styles.card}><Text style={styles.title}>Capture a task</Text><Text style={styles.muted}>Quick additions use medium priority. Fine-tune them on the web.</Text>
            <Text style={styles.muted}>Assignment</Text><TextInput accessibilityLabel="Assignment" style={styles.input} maxLength={160} placeholder="What's next?" value={title} onChangeText={lambda (s: str) { title = s; }}/>
            <Text style={styles.muted}>Course</Text><TextInput accessibilityLabel="Course" style={styles.input} maxLength={40} value={course} onChangeText={lambda (s: str) { course = s; }}/>
            <Text style={styles.muted}>Due date · YYYY-MM-DD</Text><TextInput accessibilityLabel="Due date" style={styles.input} value={due} onChangeText={lambda (s: str) { due = s; }}/>
            <Text style={styles.muted}>Estimated minutes · 5–600</Text><TextInput accessibilityLabel="Estimated minutes" style={styles.input} keyboardType="numeric" value={minutes} onChangeText={lambda (s: str) { minutes = s; }}/>
            <Pressable accessibilityRole="button" disabled={busy} style={styles.button} onPress={add}><Text style={styles.buttonText}>+ Add to my plan</Text></Pressable>
        </View><View style={styles.card}><Text style={styles.title}>Your backend</Text><Text style={styles.muted}>For a phone, enter the computer's address (e.g. http://192.168.1.10:8000). Leave blank for automatic setup.</Text><TextInput style={styles.input} accessibilityLabel="Backend URL" value={server} autoCapitalize="none" autoCorrect={False} placeholder="http://YOUR_COMPUTER:8000" onChangeText={lambda (s: str) { server = s; }}/><Pressable accessibilityRole="button" disabled={busy} style={styles.secondary} onPress={connect}><Text style={styles.secondaryText}>Connect to backend</Text></Pressable></View><Text style={styles.muted}>Shared with your web and terminal workspace. Tap Refresh for the latest changes.</Text>
    </ScrollView></View>;
}
