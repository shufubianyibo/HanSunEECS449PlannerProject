import from core.planner { dashboard, save_task, set_done, delete_task }
import from .Dashboard { Dashboard }
import "./styles.css";

def:pub app -> JsxElement { return <Dashboard/>; }
