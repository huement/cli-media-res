import os
import sys
import shlex
import subprocess
import yaml
from pathlib import Path
from textual.app import App, ComposeResult
from textual.containers import Horizontal, Vertical, ScrollableContainer
from textual.widgets import Header, Footer, OptionList, ContentSwitcher, Input, Checkbox, Button, RichLog, Label, Select
from textual.widgets.option_list import Option
from textual.widget import Widget
from textual import work


class DynamicToolForm(Widget):
    """Dynamically generates form inputs OR a launcher button for interactive TUIs."""
    def __init__(self, tool_config: dict, **kwargs):
        super().__init__(**kwargs)
        self.config = tool_config

    def compose(self) -> ComposeResult:
        yield Label(f"[bold cyan]{self.config['name']}[/bold cyan]")
        yield Label(f"[italic]{self.config.get('description', '')}[/italic]\n")
        
        if self.config.get("interactive", False):
            yield Label("This tool runs as a full interactive terminal application.")
            yield Button(f"🚀 Launch {self.config['name']}", variant="primary", id=f"btn_launch__{self.config['id']}")
        else:
            with ScrollableContainer():
                for arg in self.config.get("arguments", []):
                    yield Label(f"{arg['name']}:")
                    
                    clean_flag = arg.get('flag', '').lstrip("-").replace("-", "_")
                    widget_id = f"cfg__{self.config['id']}__{clean_flag}__{arg['type']}"
                    
                    if arg['type'] in ("text", "file", "integer"):
                        yield Input(
                            value=str(arg.get("default", "")), 
                            placeholder=arg.get("placeholder", ""), 
                            id=widget_id
                        )
                    elif arg['type'] == "boolean":
                        yield Checkbox(
                            arg.get("description", "Enable flag"), 
                            value=bool(arg.get("default", False)), 
                            id=widget_id
                        )
                    elif arg['type'] == "choice":
                        select_options = [(str(c), str(c)) for c in arg.get("choices", [])]
                        yield Select(
                            options=select_options,
                            value=str(arg.get("default", select_options[0][0] if select_options else Select.BLANK)),
                            id=widget_id
                        )
            
            yield Button(f"Run {self.config['name']}", variant="success", id=f"btn__{self.config['id']}")


class OrchestratorApp(App):
    CSS = """
    Screen { background: $surface; }
    
    /* Sidebar Styling */
    .sidebar { 
        width: 32%; 
        border-right: heavy $accent; 
        background: $surface-darken-2; 
    }
    #sidebar_title {
        width: 100%;
        margin: 0;
        padding: 1 0;
        text-align: center;
        background: $accent-darken-3;
        color: $accent;
        text-style: bold;
    }
    #sidebar_subtitle {
        width: 100%;
        margin: 0;
        padding: 1 0;
        text-align: center;
        background: $accent-darken-2;
        color: $accent;
    }
    OptionList {
        background: transparent;
        border: none;
        padding: 1 0;
    }
    OptionList:focus {
        border: none;
    }
    OptionList > .option-list--option-disabled {
        color: #00E5FF;            /* Bright Electric Cyan */
        text-style: bold;
        background: $surface-lighten-1; /* Subtle section header bar */
        opacity: 100%;
    }

    /* Main Area Styling */
    .main-content { width: 68%; padding: 1; }
    .form-pane { height: 60%; border-bottom: solid $accent; padding-bottom: 1; }
    .log-pane { height: 40%; padding-top: 1; }
    
    Label { margin-top: 1; text-style: bold; }
    Input, Select { margin-bottom: 1; }
    Checkbox { margin-top: 0; margin-bottom: 1; }
    Button { margin-top: 1; width: 100%; }
    """
    
    BINDINGS = [("q", "quit", "Quit Blueprint")]

    def __init__(self):
        super().__init__()
        self.tools = self.load_tool_configs()

    def detect_category_and_icon(self, tool: dict) -> tuple[str, str]:
        """Auto-detects category and icon if not specified in the YAML."""
        if "category" in tool and "icon" in tool:
            return tool["category"], tool["icon"]

        tid = tool.get("id", "").lower()
        name = tool.get("name", "").lower()

        if any(k in tid or k in name for k in ["png", "webp", "img", "thumb", "image", "pixel"]):
            return "Image Processing", tool.get("icon", "🔘")
        elif any(k in tid or k in name for k in ["vid", "gif", "loop", "media_optimize", "cartoon"]):
            return "Video & Animation", tool.get("icon", "🎬")
        elif any(k in tid or k in name for k in ["tts", "blendr", "voice", "audio"]):
            return "Audio & Speech", tool.get("icon", "🎙️")
        elif any(k in tid or k in name for k in ["code", "s3", "clean", "rename", "snapshot"]):
            return "Utilities & Code", tool.get("icon", "🛠️")
            
        return "General Tools", tool.get("icon", "🔧")

    def load_tool_configs(self) -> list[dict]:
        tools_dir = Path(__file__).parent / "tools"
        configs = []
        if tools_dir.exists():
            for file in tools_dir.glob("*.yaml"):
                with open(file, "r") as f:
                    tool = yaml.safe_load(f)
                    cat, icon = self.detect_category_and_icon(tool)
                    tool["category"] = cat
                    tool["icon"] = icon
                    configs.append(tool)
        return configs

    def build_sidebar_options(self) -> list[Option]:
        """Groups tools by category, alphabetizes them, and builds section headers."""
        grouped = {}
        for tool in self.tools:
            grouped.setdefault(tool["category"], []).append(tool)

        options = []
        # Sort category sections
        for cat_name in sorted(grouped.keys()):
            options.append(Option(f"[bold cyan3]── {cat_name.upper()} ──[/bold cyan3]", disabled=True))
            
            # Alphabetize tools inside each category
            sorted_tools = sorted(grouped[cat_name], key=lambda x: x["name"])
            for tool in sorted_tools:
                prompt = f" {tool['icon']}  {tool['name']}"
                options.append(Option(prompt, id=tool["id"]))
            
            # Add subtle line spacing between sections
            options.append(Option("", disabled=True))

        return options

    def compose(self) -> ComposeResult:
        yield Header(show_clock=True)
        with Horizontal():
            with Vertical(classes="sidebar"):
                yield Label("⚡ pyWOCKY AV Suite", id="sidebar_title")
                yield Label("All Available Tools", id="sidebar_subtitle")
                yield OptionList(*self.build_sidebar_options(), id="tool_selector")
            
            with Vertical(classes="main-content"):
                initial_id = self.tools[0]["id"] if self.tools else None
                with ContentSwitcher(initial=initial_id, classes="form-pane", id="form_switcher"):
                    for tool in self.tools:
                        yield DynamicToolForm(tool, id=tool["id"])
                
                with Vertical(classes="log-pane"):
                    yield Label("Console Output")
                    yield RichLog(highlight=True, markup=True, id="console_logs")
        yield Footer()

    def on_option_list_option_selected(self, event: OptionList.OptionSelected) -> None:
        """Switches form based on Option ID instead of index."""
        if event.option_id:
            self.query_one("#form_switcher", ContentSwitcher).current = event.option_id

    def on_button_pressed(self, event: Button.Pressed) -> None:
        if not event.button.id:
            return

        if event.button.id.startswith("btn_launch__"):
            tool_id = event.button.id.replace("btn_launch__", "")
            tool = next(t for t in self.tools if t["id"] == tool_id)
            self.launch_interactive_app(tool)

        elif event.button.id.startswith("btn__"):
            tool_id = event.button.id.replace("btn__", "")
            tool = next(t for t in self.tools if t["id"] == tool_id)
            self.execute_tool(tool)

    def resolve_execution_command(self, tool_config: dict) -> list[str]:
        repo_root = Path(__file__).parent.parent.absolute()
        script_path = repo_root / tool_config["script_path"]
        
        if not script_path.exists():
            raise FileNotFoundError(f"Script not found at: {script_path}")

        if script_path.suffix == ".py":
            if "venv_path" in tool_config:
                venv_dir = repo_root / tool_config["venv_path"]
                for binary_name in ("python", "python3"):
                    explicit_venv = venv_dir / "bin" / binary_name
                    if explicit_venv.exists():
                        return [str(explicit_venv), str(script_path)]
            
            script_dir = script_path.parent
            for venv_name in (".venv", "venv"):
                for binary_name in ("python", "python3"):
                    python_binary = script_dir / venv_name / "bin" / binary_name
                    if python_binary.exists():
                        return [str(python_binary), str(script_path)]
                    
            return [sys.executable, str(script_path)]

        if script_path.suffix == ".sh":
            return ["bash", str(script_path)]

        raise ValueError(f"Unsupported script type: {script_path.suffix}")

    def launch_interactive_app(self, tool: dict) -> None:
        try:
            cmd = self.resolve_execution_command(tool)
            with self.suspend():
                subprocess.run(cmd, cwd=str(Path(__file__).parent.parent / Path(tool["script_path"]).parent))
        except Exception as e:
            log_widget = self.query_one("#console_logs", RichLog)
            log_widget.write(f"[bold red]Failed to launch interactive app: {str(e)}[/bold red]")

    @work(thread=True)
    def execute_tool(self, tool: dict) -> None:
        log_widget = self.query_one("#console_logs", RichLog)
        log_widget.clear()
        cmd_args = []
        
        for arg in tool.get("arguments", []):
            clean_flag = arg.get('flag', '').lstrip("-").replace("-", "_")
            widget_id = f"#cfg__{tool['id']}__{clean_flag}__{arg['type']}"
            
            if arg['type'] in ("text", "file", "integer"):
                val = self.query_one(widget_id, Input).value.strip()
                if val:
                    flag = arg.get('flag', '').strip()
                    if flag:
                        cmd_args.extend([flag, val])
                    else:
                        cmd_args.append(val)
                elif arg.get("required"):
                    log_widget.write(f"[bold red]Validation Error: {arg['name']} is required![/bold red]")
                    return
            elif arg['type'] == "choice":
                val = self.query_one(widget_id, Select).value
                if val and val != Select.BLANK:
                    flag = arg.get('flag', '').strip()
                    if flag:
                        cmd_args.extend([flag, str(val)])
                    else:
                        cmd_args.append(str(val))
            elif arg['type'] == "boolean":
                if self.query_one(widget_id, Checkbox).value:
                    cmd_args.append(arg['flag'])

        try:
            base_cmd = self.resolve_execution_command(tool)
            full_cmd = base_cmd + cmd_args
            
            log_widget.write(f"[bold cyan]Running Pipeline:[/bold cyan] {shlex.join(full_cmd)}\n")
            
            repo_root = Path(__file__).parent.parent
            process = subprocess.Popen(
                full_cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                text=True, bufsize=1, cwd=str(repo_root)
            )
            
            if process.stdout:
                for line in process.stdout:
                    log_widget.write(line.strip())
            
            process.wait()
            if process.returncode == 0:
                log_widget.write("\n[bold green]✓ Execution Completed Successfully.[/bold green]")
            else:
                log_widget.write(f"\n[bold red]✗ Pipeline Failed (Exit Code: {process.returncode})[/bold red]")
                
        except Exception as e:
            log_widget.write(f"[bold red]Runtime Failure: {str(e)}[/bold red]")


def main():
    app = OrchestratorApp()
    app.run()


if __name__ == "__main__":
    main()