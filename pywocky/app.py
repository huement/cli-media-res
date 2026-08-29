import os
import re
import shlex
import subprocess
import sys
import yaml
from pathlib import Path
from textual import events, work
from textual.app import App, ComposeResult
from textual.containers import Horizontal, ScrollableContainer, Vertical
from textual.widget import Widget
from textual.widgets import (
    Button,
    Checkbox,
    ContentSwitcher,
    Footer,
    Header,
    Input,
    Label,
    OptionList,
    RichLog,
    Select,
    Static,
)
from textual.widgets.option_list import Option

# Import TomJGooding/textual-slider with fallback check
try:
    from textual_slider import Slider
except ImportError:
    Slider = None

# --- ASCII ART BANNERS WITH RICH COLOR MARKUP ---
BANNER_BOXED = """[bold cyan]█▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀█[/bold cyan]
[bold cyan]█[/bold cyan]  [bold bright_white]▛▌ ▌▌ ▌▖▌ ▛▌ ▛▘ ▙▘ ▌▌[/bold bright_white]  [bold cyan]█[/bold cyan]
[bold cyan]█[/bold cyan]  [bold bright_white]▙▌ ▙▌ ▚▚▘ ▙▌ ▙▖ ▛▖ ▙▌[/bold bright_white]  [bold cyan]█[/bold cyan]
[bold cyan]█[/bold cyan]  [bold bright_white]▌  ▄▌              ▄▌[/bold bright_white]  [bold cyan]█[/bold cyan]
[bold cyan]▉▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▉[/bold cyan]"""

BANNER_TV = """    [bold yellow]\╲   ╱/[/bold yellow]
[bold cyan] ┏━━━━━━━━━━━━━━━┓[/bold cyan]
[bold cyan] ┃[/bold cyan] [bold bright_cyan]█▓░▒▒░▒▒░░█[/bold bright_cyan] [bold red]●[/bold red] [bold cyan]┃[/bold cyan]  [bold bright_white]▛▌ ▌▌ ▌▖▌ ▛▌ ▛▘ ▙▘ ▌▌[/bold bright_white]
[bold cyan] ┃[/bold cyan] [bold bright_cyan]█▓░▒▒░▒▒░░█[/bold bright_cyan] [bold blue]●[/bold blue] [bold cyan]┃[/bold cyan]  [bold bright_white]▙▌ ▙▌ ▚▚▘ ▙▌ ▙▖ ▛▖ ▙▌[/bold bright_white]  
[bold cyan] ┃[/bold cyan] [bold bright_cyan]█▓░▒▒░▒▒░░█[/bold bright_cyan] [bold yellow]=[/bold yellow] [bold cyan]┃[/bold cyan]  [bold bright_white]▌  ▄▌              ▄▌[/bold bright_white]
[bold cyan] ┗━━━━━━━━━━━━━━━┛[/bold cyan]"""


class ResponsiveBanner(Static):
    """Dynamically swaps ASCII banners based on sidebar column width."""

    def on_resize(self, event: events.Resize) -> None:
        """Fires whenever the widget or terminal layout resizes."""
        if event.size.width >= 42:
            self.update(BANNER_TV)
        else:
            self.update(BANNER_BOXED)


def resolve_choice_options(choices_def) -> list[tuple[str, str]]:
    """Resolves choice inputs whether static lists, dict option pairs, or glob patterns."""
    if isinstance(choices_def, list):
        options = []
        for c in choices_def:
            if isinstance(c, dict):
                label = str(c.get("label", c.get("value", "")))
                value = str(c.get("value", ""))
                options.append((label, value))
            elif isinstance(c, (list, tuple)) and len(c) == 2:
                options.append((str(c[0]), str(c[1])))
            else:
                options.append((str(c), str(c)))
        return options

    if isinstance(choices_def, str):
        repo_root = Path(__file__).parent.parent.absolute()
        pattern_str = choices_def.strip()

        match = re.search(r"[<{](.*?)[>}]", pattern_str)
        extensions = []
        if match:
            ext_group = match.group(1)
            extensions = [e.strip().lower() for e in ext_group.split(",")]
            base_pattern = (
                pattern_str[: match.start()] + "*" + pattern_str[match.end() :]
            )
        else:
            base_pattern = pattern_str

        clean_path = Path(base_pattern)
        full_pattern_path = (
            repo_root / clean_path if not clean_path.is_absolute() else clean_path
        )

        dir_path = full_pattern_path.parent
        file_glob = full_pattern_path.name

        options = []
        if dir_path.exists() and dir_path.is_dir():
            matched_files = list(dir_path.glob(file_glob))

            if extensions:
                valid_exts = {f".{e.lstrip('.')}" for e in extensions}
                matched_files = [
                    f for f in matched_files if f.suffix.lower() in valid_exts
                ]

            for f in sorted(matched_files, key=lambda x: x.name.lower()):
                options.append((f.name, str(f.absolute())))

        return options

    return []


class DynamicToolForm(Widget):
    """Dynamically generates inputs, sliders, and controls for PyWocky tools."""

    def __init__(self, tool_config: dict, **kwargs):
        super().__init__(**kwargs)
        self.config = tool_config

    def compose(self) -> ComposeResult:
        yield Label(f"[bold cyan]{self.config['name']}[/bold cyan]")
        yield Label(f"[italic]{self.config.get('description', '')}[/italic]\n")

        if self.config.get("interactive", False):
            yield Label("This tool runs as a full interactive terminal application.")
            yield Button(
                f"🚀 Launch {self.config['name']}",
                variant="primary",
                id=f"btn_launch__{self.config['id']}",
            )
        else:
            with ScrollableContainer():
                for arg in self.config.get("arguments", []):
                    yield Label(f"[bold]{arg['name']}:[/bold]")
                    if "description" in arg and arg["type"] != "boolean":
                        yield Label(f"[dim]{arg['description']}[/dim]")

                    clean_flag = arg.get("flag", "").lstrip("-").replace("-", "_")
                    widget_id = f"cfg__{self.config['id']}__{clean_flag}__{arg['type']}"

                    if arg["type"] in ("text", "file", "integer"):
                        yield Input(
                            value=str(arg.get("default", "")),
                            placeholder=arg.get("placeholder", ""),
                            id=widget_id,
                        )
                    elif arg["type"] == "slider":
                        min_val = int(arg.get("min", 1))
                        max_val = int(arg.get("max", 100))
                        default_val = int(arg.get("default", min_val))

                        if Slider is not None:
                            try:
                                yield Slider(
                                    min=min_val,
                                    max=max_val,
                                    value=default_val,
                                    id=widget_id,
                                )
                            except Exception:
                                yield Input(
                                    value=str(default_val),
                                    placeholder=f"Range {min_val}-{max_val}",
                                    id=widget_id,
                                )
                        else:
                            yield Input(
                                value=str(default_val),
                                placeholder=f"Range {min_val}-{max_val}",
                                id=widget_id,
                            )
                    elif arg["type"] == "boolean":
                        yield Checkbox(
                            arg.get("description", "Enable flag"),
                            value=bool(arg.get("default", False)),
                            id=widget_id,
                        )
                    elif arg["type"] == "choice":
                        select_options = resolve_choice_options(arg.get("choices", []))

                        if not arg.get("required", False) and not any(
                            v == "" for _, v in select_options
                        ):
                            select_options.insert(0, ("-- None (Disabled) --", ""))

                        default_val = str(arg.get("default", ""))
                        valid_values = [v for _, v in select_options]

                        if default_val in valid_values:
                            init_val = default_val
                        elif select_options:
                            init_val = select_options[0][1]
                        else:
                            init_val = Select.BLANK

                        yield Select(
                            options=[(label, val) for label, val in select_options],
                            value=init_val,
                            id=widget_id,
                        )

            yield Button(
                f"Run {self.config['name']}",
                variant="success",
                id=f"btn__{self.config['id']}",
            )


class OrchestratorApp(App):
    CSS = """
    Screen { background: $surface; }

    .sidebar {
        width: 32%;
        border-right: heavy $accent;
        background: $surface-darken-2;
    }

    #sidebar_banner {
        width: 100%;
        padding: 1 0 0 0;
        content-align: center middle;
        background: transparent;
    }

    #sidebar_subtitle {
        width: 100%;
        margin-top: 1;
        padding-bottom: 1;
        text-align: center;
        color: $accent-lighten-2;
        text-style: dim;
        border-bottom: dashed $accent-darken-2;
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
        color: #00E5FF;
        text-style: bold;
        background: $surface-lighten-1;
        opacity: 100%;
    }

    .main-content { width: 68%; padding: 1; }
    .form-pane { height: 60%; border-bottom: solid $accent; padding-bottom: 1; }
    .log-pane { height: 40%; padding-top: 1; }

    Label { margin-top: 1; text-style: bold; }
    Input, Select { margin-bottom: 1; }
    Slider { width: 1fr; margin-bottom: 1; }
    Checkbox { margin-top: 0; margin-bottom: 1; }
    Button { margin-top: 1; width: 100%; }
    """

    BINDINGS = [("q", "quit", "Quit PyWocky")]

    def __init__(self):
        super().__init__()
        self.tools = self.load_tool_configs()

    def detect_category_and_icon(self, tool: dict) -> tuple[str, str]:
        if "category" in tool and "icon" in tool:
            return tool["category"], tool["icon"]

        tid = tool.get("id", "").lower()
        name = tool.get("name", "").lower()

        if any(
            k in tid or k in name
            for k in ["png", "webp", "img", "thumb", "image", "pixel"]
        ):
            return "🖼️  Image Processing", tool.get("icon", "🔘")
        elif any(
            k in tid or k in name
            for k in [
                "vid",
                "gif",
                "loop",
                "media_optimize",
                "retro_toolkit",
                "cartoon",
            ]
        ):
            return "🎬 Video & Animation", tool.get("icon", "🔘")
        elif any(k in tid or k in name for k in ["tts", "blendr", "voice", "audio"]):
            return "🎙️  Audio & Speech", tool.get("icon", "🔘")
        elif any(
            k in tid or k in name for k in ["code", "s3", "clean", "rename", "snapshot"]
        ):
            return "🛠️  Utilities & Code", tool.get("icon", "🔘")

        return "🔧  General Tools", tool.get("icon", "🔘")

    def load_tool_configs(self) -> list[dict]:
        tools_dir = Path(__file__).parent / "tools"
        configs = []
        seen_ids = set()

        if tools_dir.exists():
            for file in sorted(tools_dir.glob("*.yaml")):
                with open(file, "r") as f:
                    tool = yaml.safe_load(f)
                    if not tool or "id" not in tool:
                        continue

                    tool_id = tool["id"]
                    if tool_id in seen_ids:
                        continue
                    seen_ids.add(tool_id)

                    cat, icon = self.detect_category_and_icon(tool)
                    tool["category"] = cat
                    tool["icon"] = icon
                    configs.append(tool)
        return configs

    def build_sidebar_options(self) -> list[Option]:
        grouped = {}
        for tool in self.tools:
            grouped.setdefault(tool["category"], []).append(tool)

        options = []
        for cat_name in sorted(grouped.keys()):
            options.append(
                Option(
                    f"[bold cyan3]── {cat_name.upper()} ──[/bold cyan3]", disabled=True
                )
            )

            sorted_tools = sorted(grouped[cat_name], key=lambda x: x["name"])
            for tool in sorted_tools:
                prompt = f" {tool['icon']}  {tool['name']}"
                options.append(Option(prompt, id=tool["id"]))

            options.append(Option("", disabled=True))

        return options

    def compose(self) -> ComposeResult:
        yield Header(show_clock=True)
        with Horizontal():
            with Vertical(classes="sidebar"):
                yield ResponsiveBanner(BANNER_BOXED, id="sidebar_banner")
                yield Label("── AV ORCHESTRATOR SUITE ──", id="sidebar_subtitle")
                yield OptionList(*self.build_sidebar_options(), id="tool_selector")

            with Vertical(classes="main-content"):
                initial_id = self.tools[0]["id"] if self.tools else None
                with ContentSwitcher(
                    initial=initial_id, classes="form-pane", id="form_switcher"
                ):
                    for tool in self.tools:
                        yield DynamicToolForm(tool, id=tool["id"])

                with Vertical(classes="log-pane"):
                    yield Label("Console Output")
                    yield RichLog(highlight=True, markup=True, id="console_logs")
        yield Footer()

    def on_option_list_option_selected(self, event: OptionList.OptionSelected) -> None:
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

            for venv_name in (".venv", "venv"):
                for binary_name in ("python", "python3"):
                    python_binary = repo_root / venv_name / "bin" / binary_name
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
                subprocess.run(
                    cmd,
                    cwd=str(
                        Path(__file__).parent.parent / Path(tool["script_path"]).parent
                    ),
                )
        except Exception as e:
            log_widget = self.query_one("#console_logs", RichLog)
            log_widget.write(
                f"[bold red]Failed to launch interactive app: {str(e)}[/bold red]"
            )

    @work(thread=True)
    def execute_tool(self, tool: dict) -> None:
        log_widget = self.query_one("#console_logs", RichLog)
        log_widget.clear()
        cmd_args = []

        for arg in tool.get("arguments", []):
            clean_flag = arg.get("flag", "").lstrip("-").replace("-", "_")
            widget_id = f"#cfg__{tool['id']}__{clean_flag}__{arg['type']}"

            if arg["type"] in ("text", "file", "integer"):
                val = self.query_one(widget_id, Input).value.strip()
                if val:
                    flag = arg.get("flag", "").strip()
                    if flag:
                        cmd_args.extend([flag, val])
                    else:
                        cmd_args.append(val)
                elif arg.get("required"):
                    log_widget.write(
                        f"[bold red]Validation Error: {arg['name']} is required![/bold red]"
                    )
                    return
            elif arg["type"] == "slider":
                slider_widget = self.query_one(widget_id)
                if hasattr(slider_widget, "value"):
                    val = str(slider_widget.value)
                elif isinstance(slider_widget, Input):
                    val = slider_widget.value.strip()
                else:
                    val = str(arg.get("default", 1))

                flag = arg.get("flag", "").strip()
                if flag:
                    cmd_args.extend([flag, val])
                else:
                    cmd_args.append(val)
            elif arg["type"] == "choice":
                val = self.query_one(widget_id, Select).value
                if val and val != Select.BLANK and str(val).strip() != "":
                    flag = arg.get("flag", "").strip()
                    if flag:
                        cmd_args.extend([flag, str(val)])
                    else:
                        cmd_args.append(str(val))
            elif arg["type"] == "boolean":
                if self.query_one(widget_id, Checkbox).value:
                    cmd_args.append(arg["flag"])

        try:
            base_cmd = self.resolve_execution_command(tool)
            full_cmd = base_cmd + cmd_args

            log_widget.write(
                f"[bold cyan]Running Pipeline:[/bold cyan] {shlex.join(full_cmd)}\n"
            )

            repo_root = Path(__file__).parent.parent
            process = subprocess.Popen(
                full_cmd,
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                text=True,
                bufsize=1,
                cwd=str(repo_root),
            )

            if process.stdout:
                for line in process.stdout:
                    log_widget.write(line.strip())

            process.wait()
            if process.returncode == 0:
                log_widget.write(
                    "\n[bold green]✓ Execution Completed Successfully.[/bold green]"
                )
            else:
                log_widget.write(
                    f"\n[bold red]✗ Pipeline Failed (Exit Code: {process.returncode})[/bold red]"
                )

        except Exception as e:
            log_widget.write(f"[bold red]Runtime Failure: {str(e)}[/bold red]")


def main():
    app = OrchestratorApp()
    app.run()


if __name__ == "__main__":
    main()