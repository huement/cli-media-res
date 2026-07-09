import os
import sys
import shlex
import subprocess
import yaml
from pathlib import Path
from textual.app import App, ComposeResult
from textual.containers import Horizontal, Vertical, ScrollableContainer
from textual.widgets import Header, Footer, OptionList, ContentSwitcher, Input, Checkbox, Button, RichLog, Label, Select
from textual.widget import Widget
from textual import work

class DynamicToolForm(Widget):
    """Dynamically generates form inputs based on a tool's YAML definition."""
    def __init__(self, tool_config: dict, **kwargs):
        super().__init__(**kwargs)
        self.config = tool_config

    def compose(self) -> ComposeResult:
        yield Label(f"[bold cyan]{self.config['name']}[/bold cyan]")
        yield Label(f"[italic]{self.config.get('description', '')}[/italic]\n")
        
        with ScrollableContainer():
            for arg in self.config.get("arguments", []):
                yield Label(f"{arg['name']}:")
                
                clean_flag = arg['flag'].lstrip("-").replace("-", "_")
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
                    # Maps string arrays into structural tuples: (display_name, value)
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
    .sidebar { width: 30%; border-right: solid $accent; background: $surface-darken-1; }
    .main-content { width: 70%; padding: 1; }
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

    def load_tool_configs(self) -> list[dict]:
        tools_dir = Path(__file__).parent / "tools"
        configs = []
        if tools_dir.exists():
            for file in tools_dir.glob("*.yaml"):
                with open(file, "r") as f:
                    configs.append(yaml.safe_load(f))
        return configs

    def compose(self) -> ComposeResult:
        yield Header(show_clock=True)
        with Horizontal():
            with Vertical(classes="sidebar"):
                yield Label(" Available Tools", id="sidebar_title")
                yield OptionList(*[t["name"] for t in self.tools], id="tool_selector")
            
            with Vertical(classes="main-content"):
                with ContentSwitcher(initial=self.tools[0]["id"] if self.tools else None, classes="form-pane", id="form_switcher"):
                    for tool in self.tools:
                        yield DynamicToolForm(tool, id=tool["id"])
                
                with Vertical(classes="log-pane"):
                    yield Label("Console Output")
                    yield RichLog(highlight=True, markup=True, id="console_logs")
        yield Footer()

    def on_option_list_option_selected(self, event: OptionList.OptionSelected) -> None:
            """Switches the visible form when a different tool is selected in the sidebar."""
            # CHANGED: event.index -> event.option_index
            tool_id = self.tools[event.option_index]["id"]
            self.query_one("#form_switcher", ContentSwitcher).current = tool_id

    def on_button_pressed(self, event: Button.Pressed) -> None:
        if event.button.id and event.button.id.startswith("btn__"):
            tool_id = event.button.id.replace("btn__", "")
            tool = next(t for t in self.tools if t["id"] == tool_id)
            self.execute_tool(tool)

    def resolve_execution_command(self, script_relative_path: str) -> list[str]:
        repo_root = Path(__file__).parent.parent
        script_path = (repo_root / script_relative_path).resolve()
        
        if not script_path.exists():
            raise FileNotFoundError(f"Script not found at: {script_path}")

        if script_path.suffix == ".sh":
            return ["bash", str(script_path)]

        if script_path.suffix == ".py":
            script_dir = script_path.parent
            for venv_name in (".venv", "venv"):
                python_binary = script_dir / venv_name / "bin" / "python"
                if python_binary.exists():
                    return [str(python_binary), str(script_path)]
            return [sys.executable, str(script_path)]

        raise ValueError(f"Unsupported script type: {script_path.suffix}")

    @work(thread=True)
    def execute_tool(self, tool: dict) -> None:
        log_widget = self.query_one("#console_logs", RichLog)
        log_widget.clear()
        cmd_args = []
        
        for arg in tool.get("arguments", []):
            clean_flag = arg['flag'].lstrip("-").replace("-", "_")
            widget_id = f"#cfg__{tool['id']}__{clean_flag}__{arg['type']}"
            
            if arg['type'] in ("text", "file", "integer"):
                val = self.query_one(widget_id, Input).value.strip()
                if val:
                    cmd_args.extend([arg['flag'], val])
                elif arg.get("required"):
                    log_widget.write(f"[bold red]Validation Error: {arg['name']} is required![/bold red]")
                    return
            elif arg['type'] == "choice":
                val = self.query_one(widget_id, Select).value
                if val and val != Select.BLANK:
                    cmd_args.extend([arg['flag'], str(val)])
            elif arg['type'] == "boolean":
                if self.query_one(widget_id, Checkbox).value:
                    cmd_args.append(arg['flag'])

        try:
            base_cmd = self.resolve_execution_command(tool["script_path"])
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

if __name__ == "__main__":
    app = OrchestratorApp()
    app.run()