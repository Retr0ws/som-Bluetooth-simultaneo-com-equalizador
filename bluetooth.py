#!/usr/bin/env python3
"""Compilador do dia a dia — Estúdio de Áudio Bluetooth.

Uso normal:  python3 bluetooth.py
Compila, valida e abre o app. A janela fica aberta até você fechar.
--check-only  só valida
--smoke       teste curto que fecha sozinho
"""

from __future__ import annotations

import argparse
import compileall
import os
import py_compile
import subprocess
import sys
import traceback
from pathlib import Path

# Evita crash Wayland (free(): invalid size / double free)
if os.environ.get("XDG_SESSION_TYPE", "").lower() == "wayland" or os.environ.get(
    "WAYLAND_DISPLAY"
):
    os.environ.setdefault("QT_QPA_PLATFORM", "xcb")

ROOT = Path(__file__).resolve().parent
PACKAGE = ROOT / "bluetooth_audio_studio"
MAIN = ROOT / "main.py"
VENV_PYTHON = ROOT / ".venv" / "bin" / "python"

# Terminal futurista (ANSI). Sem cor se a saída não for um TTY.
_TTY = sys.stdout.isatty()
_R = "\033[0m" if _TTY else ""
_DIM = "\033[2m" if _TTY else ""
_CYAN = "\033[38;5;51m" if _TTY else ""
_TEAL = "\033[38;5;48m" if _TTY else ""
_AMBER = "\033[38;5;214m" if _TTY else ""
_RED = "\033[38;5;203m" if _TTY else ""
_MAG = "\033[38;5;141m" if _TTY else ""


def _c(color: str, text: str) -> str:
    return f"{color}{text}{_R}" if _TTY else text


def python_bin() -> str:
    if VENV_PYTHON.exists():
        return str(VENV_PYTHON)
    return sys.executable


def step(title: str) -> None:
    bar = "━" * 54
    print(f"\n{_c(_CYAN, '┌' + bar + '┐')}")
    print(f"{_c(_CYAN, '│')}  {_c(_TEAL, title)}")
    print(f"{_c(_CYAN, '└' + bar + '┘')}")


def compile_all() -> list[str]:
    step("01  COMPILE")
    errors: list[str] = []
    files = sorted(PACKAGE.rglob("*.py")) + [MAIN]
    for path in files:
        rel = path.relative_to(ROOT)
        try:
            py_compile.compile(str(path), doraise=True)
            print(f"  {_c(_TEAL, 'PRONTO')}  {_DIM}{rel}{_R}")
        except py_compile.PyCompileError as exc:
            msg = f"ERRO em {rel}: {exc}"
            print(f"  {_c(_RED, 'ERRO')}  {msg}")
            errors.append(msg)
    compileall.compile_dir(str(PACKAGE), quiet=1, force=True)
    print(
        f"\n  {_c(_MAG, str(len(files)))} arquivos"
        f"  ·  erros {_c(_RED if errors else _TEAL, str(len(errors)))}"
    )
    return errors


def check_imports() -> list[str]:
    step("02  IMPORTS")
    modules = [
        "bluetooth_audio_studio",
        "bluetooth_audio_studio.config.settings",
        "bluetooth_audio_studio.config.i18n",
        "bluetooth_audio_studio.logs.logger",
        "bluetooth_audio_studio.utils.safe_exec",
        "bluetooth_audio_studio.utils.system_info",
        "bluetooth_audio_studio.pipewire.manager",
        "bluetooth_audio_studio.bluez.manager",
        "bluetooth_audio_studio.services.profiles",
        "bluetooth_audio_studio.services.automation",
        "bluetooth_audio_studio.services.notifications",
        "bluetooth_audio_studio.styles.theme",
        "bluetooth_audio_studio.widgets.cards",
        "bluetooth_audio_studio.widgets.splash",
        "bluetooth_audio_studio.pages.home",
        "bluetooth_audio_studio.pages.devices",
        "bluetooth_audio_studio.pages.audio",
        "bluetooth_audio_studio.pages.studio",
        "bluetooth_audio_studio.pipewire.studio_eq",
        "bluetooth_audio_studio.pages.profiles",
        "bluetooth_audio_studio.pages.logs",
        "bluetooth_audio_studio.pages.settings",
        "bluetooth_audio_studio.main_window",
    ]
    code = """
import sys
from pathlib import Path
ROOT = Path(%r)
sys.path.insert(0, str(ROOT))
errors = []
modules = %r
for m in modules:
    try:
        __import__(m)
        print(f"  PRONTO  {m}")
    except Exception as e:
        print(f"  ✗  {m}: {e}")
        errors.append(f"{m}: {e}")
for m in ("PySide6", "qtawesome"):
    try:
        __import__(m)
        print(f"  PRONTO  {m}")
    except Exception as e:
        print(f"  ✗  {m}: {e}")
        errors.append(f"{m}: {e}")
sys.exit(1 if errors else 0)
""" % (str(ROOT), modules)

    result = subprocess.run(
        [python_bin(), "-c", code],
        cwd=str(ROOT),
        capture_output=True,
        text=True,
    )
    for line in result.stdout.splitlines():
        if line.strip().startswith("PRONTO"):
            print(
                f"  {_c(_TEAL, 'PRONTO')}  {_DIM}{line.strip()[6:].strip()}{_R}"
            )
        elif "✗" in line:
            print(f"  {_c(_RED, 'ERRO')}  {line.split('✗', 1)[-1].strip()}")
        elif line.strip():
            print(line)
    if result.stderr:
        for line in result.stderr.splitlines():
            if line.strip():
                print(f"  {_c(_AMBER, 'REG')}  {_DIM}{line}{_R}")
    errors: list[str] = []
    if result.returncode != 0:
        errors.append("Falha na verificação de imports")
        for line in (result.stdout + result.stderr).splitlines():
            if line.strip().startswith("✗"):
                errors.append(line.strip())
    return errors


def smoke_ui(seconds: float = 2.5) -> list[str]:
    """Smoke opcional — NÃO usar no uso diário (fecha a janela de propósito)."""
    step("Smoke test (fecha sozinho — só validação)")
    code = f"""
import os, sys
from pathlib import Path
os.environ.setdefault("QT_QPA_PLATFORM", "xcb")
ROOT = Path({str(ROOT)!r})
sys.path.insert(0, str(ROOT))
from PySide6.QtCore import QTimer
from PySide6.QtWidgets import QApplication
from bluetooth_audio_studio.config.settings import AppSettings
from bluetooth_audio_studio.main_window import MainWindow
from bluetooth_audio_studio.utils.safe_exec import wait_async_jobs

app = QApplication(sys.argv)
app.setStyle("Fusion")
settings = AppSettings().load()
settings.auto_scan = False
settings.auto_reconnect = False
win = MainWindow(settings)
win.automation.stop()
win.show()
print("  UI aberta — fechando em {seconds}s…")
print(f"  platform={{app.platformName()}}")

def _quit():
    win.close()
    wait_async_jobs(2000)
    app.quit()

QTimer.singleShot(int({seconds} * 1000), _quit)
rc = app.exec()
print(f"  UI encerrou com código {{rc}}")
sys.exit(0 if rc == 0 else rc)
"""
    env = os.environ.copy()
    env.setdefault("QT_QPA_PLATFORM", "xcb")
    result = subprocess.run(
        [python_bin(), "-c", code],
        cwd=str(ROOT),
        capture_output=True,
        text=True,
        timeout=60,
        env=env,
    )
    print(result.stdout)
    if result.stderr:
        for line in result.stderr.splitlines():
            if line.strip():
                print(f"  stderr: {line}")
    if result.returncode != 0:
        return [f"Smoke UI falhou (exit {result.returncode})"]
    return []


def run_app() -> int:
    step("03  SISTEMA ONLINE")
    print(f"  {_c(_CYAN, 'python')}  {_DIM}{python_bin()}{_R}")
    print(f"  {_c(_CYAN, 'app')}     {MAIN.name}")
    print(f"  {_c(_TEAL, 'janela')}  fica aberta até você fechar\n")
    env = os.environ.copy()
    env.setdefault("QT_QPA_PLATFORM", "xcb")
    env.setdefault("BAS_COLOR_LOG", "1")
    return subprocess.call([python_bin(), str(MAIN)], cwd=str(ROOT), env=env)


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Compila, valida e roda o Estúdio de Áudio Bluetooth"
    )
    parser.add_argument(
        "--check-only",
        action="store_true",
        help="Só compila e valida (não abre o programa)",
    )
    parser.add_argument(
        "--smoke",
        action="store_true",
        help="Roda smoke test curto (fecha a UI de propósito) — NÃO use no dia a dia",
    )
    args = parser.parse_args()

    print(_c(_CYAN, "  BAS  ·  ESTÚDIO DE ÁUDIO BLUETOOTH"))
    print(f"  {_DIM}compilador do dia a dia{_R}  ·  {ROOT.name}")
    print(f"  {_c(_MAG, python_bin())}")

    all_errors: list[str] = []
    all_errors.extend(compile_all())
    all_errors.extend(check_imports())

    # Smoke NÃO roda por padrão — era isso que “fechava sozinho”
    if args.smoke and not all_errors:
        try:
            all_errors.extend(smoke_ui(2.5))
        except subprocess.TimeoutExpired:
            all_errors.append("Smoke UI: timeout")
        except Exception as exc:  # noqa: BLE001
            all_errors.append(f"Smoke UI: {exc}\n{traceback.format_exc()}")

    step("RESULTADO")
    if all_errors:
        print(f"  {_c(_RED, 'FALHOU')}\n")
        for e in all_errors:
            print(f"  {_c(_RED, '·')} {e}")
        return 1

    print(f"  {_c(_TEAL, 'PRONTO')}  compilação e imports ok")
    # --smoke é validação e deve encerrar após fechar a janela de teste.
    if args.check_only or args.smoke:
        return 0
    return run_app()


if __name__ == "__main__":
    raise SystemExit(main())
