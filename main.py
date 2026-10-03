#!/usr/bin/env python3
"""Ponto de entrada — Estúdio de Áudio Bluetooth."""

from __future__ import annotations

import os
import sys
from pathlib import Path

# Wayland + PySide6 costuma crashar com "free(): invalid size".
# Força X11/XWayland antes de criar QApplication.
if os.environ.get("XDG_SESSION_TYPE", "").lower() == "wayland" or os.environ.get(
    "WAYLAND_DISPLAY"
):
    os.environ.setdefault("QT_QPA_PLATFORM", "xcb")
os.environ.setdefault("QT_WAYLAND_DISABLE_WINDOWDECORATION", "1")

ROOT = Path(__file__).resolve().parent
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from PySide6.QtCore import Qt, QTimer
from PySide6.QtWidgets import QApplication

from bluetooth_audio_studio import __app_name__, __version__
from bluetooth_audio_studio.config.settings import AppSettings
from bluetooth_audio_studio.logs.logger import logger
from bluetooth_audio_studio.main_window import MainWindow


def main() -> int:
    QApplication.setHighDpiScaleFactorRoundingPolicy(
        Qt.HighDpiScaleFactorRoundingPolicy.PassThrough
    )
    app = QApplication(sys.argv)
    app.setApplicationName(__app_name__)
    app.setApplicationVersion(__version__)
    app.setOrganizationName("EstudioAudioBluetooth")
    app.setStyle("Fusion")

    settings = AppSettings().load()
    logger.info(
        f"Iniciando {__app_name__} v{__version__} "
        f"(platform={app.platformName()})"
    )

    # Sem splash frameless no Wayland — evita free(): invalid size
    window = MainWindow(settings)
    window.show()
    # Mantém referência viva
    app._bas_window = window  # type: ignore[attr-defined]

    # Pequeno delay para o compositor estabilizar
    QTimer.singleShot(0, window.raise_)
    return app.exec()


if __name__ == "__main__":
    raise SystemExit(main())
