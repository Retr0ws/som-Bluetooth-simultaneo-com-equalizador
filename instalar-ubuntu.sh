#!/usr/bin/env bash
# =============================================================================
# Estúdio de Áudio Bluetooth — Instalador COMPLETO para Ubuntu / Debian
# =============================================================================
# Lista TODAS as pendências, instala o que falta, cria venv, deps Python,
# atalho no menu, comando no PATH e valida se o app sobe.
#
# Uso:
#   bash instalar-ubuntu.sh          # pergunta antes
#   bash instalar-ubuntu.sh -y       # sem perguntar
#   bash instalar-ubuntu.sh --check  # só lista o que falta (não instala)
#
# Ou dois cliques em: Instalar-no-Ubuntu.desktop
# =============================================================================
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"

RED=$'\033[31m'
GRN=$'\033[32m'
YLW=$'\033[33m'
CYN=$'\033[36m'
BLD=$'\033[1m'
DIM=$'\033[2m'
RST=$'\033[0m'

YES=0
CHECK_ONLY=0
for arg in "$@"; do
  case "$arg" in
    -y|--yes) YES=1 ;;
    --check|--dry-run) CHECK_ONLY=1 ;;
    -h|--help)
      sed -n '2,16p' "$0" | sed 's/^# \?//'
      exit 0
      ;;
  esac
done

banner() {
  echo ""
  echo "${CYN}${BLD}╔════════════════════════════════════════════════════════════╗${RST}"
  echo "${CYN}${BLD}║   Estúdio de Áudio Bluetooth — Instalador Ubuntu          ║${RST}"
  echo "${CYN}${BLD}╚════════════════════════════════════════════════════════════╝${RST}"
  echo ""
  echo "Pasta do app: ${YLW}$ROOT${RST}"
  echo "Data: $(date '+%Y-%m-%d %H:%M:%S')"
  echo ""
}

need_cmd() { command -v "$1" >/dev/null 2>&1; }

pkg_installed() {
  # Ubuntu recente usa sufixo t64 em várias libs
  dpkg -s "$1" >/dev/null 2>&1 || dpkg -s "${1}t64" >/dev/null 2>&1
}

pkg_exists() {
  apt-cache show "$1" >/dev/null 2>&1 || apt-cache show "${1}t64" >/dev/null 2>&1
}

resolve_pkg() {
  # Devolve o nome instalável (com t64 se for o caso)
  local pkg="$1"
  if apt-cache show "$pkg" >/dev/null 2>&1; then
    echo "$pkg"
  elif apt-cache show "${pkg}t64" >/dev/null 2>&1; then
    echo "${pkg}t64"
  else
    echo ""
  fi
}

# --- Pacotes do sistema (obrigatórios + recomendados) -------------------
# Formato: nome_pacote|obrigatório(1/0)|para_quê
PKG_SPEC=(
  "python3|1|Interpretador Python"
  "python3-venv|1|Ambiente virtual (.venv)"
  "python3-pip|1|Instalador de pacotes Python"
  "python3-dev|1|Headers para compilar extensões"
  "python3-dbus|0|Bindings D-Bus (útil com BlueZ)"
  "python3-gi|0|GObject / introspecção"
  "build-essential|0|Compilador C (fallback pip)"
  "pkg-config|0|Detecção de libs nativas"
  "pipewire|1|Servidor de áudio moderno"
  "pipewire-pulse|1|Compatibilidade PulseAudio (pactl)"
  "pipewire-audio|0|Metapacote PipeWire áudio"
  "pipewire-bin|0|Ferramentas pw-cli / pw-link"
  "wireplumber|1|Gerenciador de sessão PipeWire"
  "libspa-0.2-bluetooth|1|Bluetooth A2DP no PipeWire"
  "libspa-0.2-jack|0|Integração JACK (opcional)"
  "bluez|1|Pilha Bluetooth do Linux"
  "bluez-tools|0|Utilitários Bluetooth extras"
  "rfkill|0|Desbloquear rádio Bluetooth/Wi‑Fi"
  "pulseaudio-utils|1|Comando pactl (volumes/rotas)"
  "libpipewire-0.3-modules|0|Módulos PipeWire (filter-chain)"
  "libxcb-cursor0|1|Cursor Qt/PySide6"
  "libxkbcommon0|1|Teclado Qt"
  "libxkbcommon-x11-0|0|Teclado X11 Qt"
  "libgl1|1|OpenGL / Qt"
  "libegl1|0|EGL / Qt"
  "libdbus-1-3|1|D-Bus runtime"
  "libglib2.0-0|1|GLib (base desktop)"
  "libxcb-xinerama0|0|Multi-monitor Qt"
  "libxcb-icccm4|0|Janelas Qt/X11"
  "libxcb-image0|0|Imagens Qt/X11"
  "libxcb-keysyms1|0|Teclas Qt/X11"
  "libxcb-render-util0|0|Render Qt/X11"
  "libxcb-shape0|0|Shape Qt/X11"
  "libfontconfig1|0|Fontes"
  "fonts-noto-core|0|Fontes legíveis na UI"
)

# Pacotes Python (pip / requirements.txt)
PIP_PKGS=(
  "PySide6|Interface gráfica Qt"
  "qtawesome|Ícones no menu"
  "dbus-next|Bluetooth via D-Bus"
  "numpy|Cálculos / sync de áudio"
)

banner

if ! need_cmd apt-get; then
  echo "${RED}Este instalador é para Ubuntu/Debian (apt).${RST}"
  echo "Outras distros: bluetooth_audio_studio/scripts/install.sh"
  exit 1
fi

# --- 1) Inventário ------------------------------------------------------
echo "${CYN}${BLD}==> 1/6  Inventário — o que o sistema tem / falta${RST}"
echo ""

MISSING_REQ=()
MISSING_OPT=()
PRESENT=()
SKIPPED=()

for spec in "${PKG_SPEC[@]}"; do
  IFS='|' read -r pkg required why <<<"$spec"
  if pkg_installed "$pkg"; then
    PRESENT+=("$pkg")
    echo "  ${GRN}✔${RST} $pkg  ${DIM}— $why${RST}"
  elif pkg_exists "$pkg"; then
    if [[ "$required" == "1" ]]; then
      MISSING_REQ+=("$pkg")
      echo "  ${RED}✗${RST} $pkg  ${YLW}(OBRIGATÓRIO)${RST} — $why"
    else
      MISSING_OPT+=("$pkg")
      echo "  ${YLW}○${RST} $pkg  (recomendado) — $why"
    fi
  else
    SKIPPED+=("$pkg")
    echo "  ${DIM}~ $pkg  (não existe neste Ubuntu — ok)${RST}"
  fi
done

echo ""
echo "  Sistema: ${GRN}${#PRESENT[@]} ok${RST} | ${RED}${#MISSING_REQ[@]} obrigatórios faltando${RST} | ${YLW}${#MISSING_OPT[@]} recomendados faltando${RST}"
echo ""

echo "${CYN}Ferramentas em PATH:${RST}"
for cmd in python3 pip3 pactl pw-cli pw-link bluetoothctl pipewire wireplumber; do
  if need_cmd "$cmd"; then
    ver=""
    case "$cmd" in
      python3) ver=" ($(python3 --version 2>&1))" ;;
      pactl) ver=" ($(pactl --version 2>&1 | head -1))" ;;
    esac
    echo "  ${GRN}✔${RST} $cmd$ver"
  else
    echo "  ${YLW}○${RST} $cmd  (ainda não no PATH)"
  fi
done

echo ""
echo "${CYN}Pacotes Python (pip no .venv):${RST}"
for spec in "${PIP_PKGS[@]}"; do
  IFS='|' read -r name why <<<"$spec"
  echo "  • $name — $why"
done
if [[ -f "$ROOT/requirements.txt" ]]; then
  echo "  ${DIM}Arquivo: requirements.txt${RST}"
else
  echo "  ${RED}✗ requirements.txt não encontrado!${RST}"
fi

echo ""
echo "${CYN}Arquivos do app:${RST}"
for f in main.py abrir.sh requirements.txt bluetooth_audio_studio/main_window.py; do
  if [[ -e "$ROOT/$f" ]]; then
    echo "  ${GRN}✔${RST} $f"
  else
    echo "  ${RED}✗${RST} $f  (faltando — pasta incompleta?)"
  fi
done

if [[ "$CHECK_ONLY" -eq 1 ]]; then
  echo ""
  echo "${YLW}Modo --check: nada foi instalado.${RST}"
  echo "Para instalar tudo:  bash instalar-ubuntu.sh -y"
  exit 0
fi

echo ""
if [[ "$YES" -ne 1 ]]; then
  read -r -p "Instalar obrigatórios + recomendados + Python + atalhos? [S/n] " ans
  ans=${ans:-S}
  if [[ ! "$ans" =~ ^[SsYy]$ ]]; then
    echo "Cancelado."
    exit 0
  fi
fi

# --- 2) apt update + system pkgs ---------------------------------------
echo ""
echo "${CYN}${BLD}==> 2/6  Atualizando índices e instalando pacotes (pede senha)${RST}"

if ! need_cmd sudo; then
  echo "${RED}sudo não encontrado. Instale como root ou adicione sudo.${RST}"
  exit 1
fi

sudo apt-get update

TO_INSTALL=("${MISSING_REQ[@]}" "${MISSING_OPT[@]}")
# Sempre reforça núcleo mínimo (idempotente)
CORE=(
  python3 python3-venv python3-pip python3-dev
  pipewire pipewire-pulse wireplumber bluez
  libspa-0.2-bluetooth pulseaudio-utils
  libxcb-cursor0 libxkbcommon0 libgl1 libdbus-1-3
)
TO_INSTALL+=("${CORE[@]}")

# Dedup
mapfile -t TO_INSTALL < <(printf '%s\n' "${TO_INSTALL[@]}" | awk 'NF && !seen[$0]++')

echo "  Instalando ${#TO_INSTALL[@]} pacote(s)…"
# Instala o que existir; ignora nomes inválidos sem abortar o resto
INSTALLABLE=()
for pkg in "${TO_INSTALL[@]}"; do
  resolved="$(resolve_pkg "$pkg")"
  if [[ -n "$resolved" ]]; then
    INSTALLABLE+=("$resolved")
  fi
done

if ((${#INSTALLABLE[@]} > 0)); then
  sudo DEBIAN_FRONTEND=noninteractive apt-get install -y "${INSTALLABLE[@]}"
fi

# Tentativas extras (nomes que mudam entre releases)
EXTRA=(
  pipewire-audio pipewire-bin bluez-tools rfkill
  libpipewire-0.3-modules libxkbcommon-x11-0
  libxcb-xinerama0 libxcb-icccm4 libxcb-image0
  libxcb-keysyms1 libxcb-render-util0 libxcb-shape0
  libegl1 fonts-noto-core build-essential pkg-config
  python3-dbus python3-gi
)
for pkg in "${EXTRA[@]}"; do
  if pkg_exists "$pkg" && ! pkg_installed "$pkg"; then
    sudo DEBIAN_FRONTEND=noninteractive apt-get install -y "$pkg" 2>/dev/null || true
  fi
done

# Garante serviços de usuário (quando disponíveis)
echo ""
echo "${CYN}${BLD}==> 3/6  Serviços de áudio / Bluetooth${RST}"
systemctl --user enable --now pipewire pipewire-pulse wireplumber 2>/dev/null || true
sudo systemctl enable --now bluetooth 2>/dev/null || true
# Desbloqueia rádio se estiver soft-blocked
if need_cmd rfkill; then
  sudo rfkill unblock bluetooth 2>/dev/null || true
fi
echo "  PipeWire / WirePlumber / Bluetooth: tentados enable --now"

# --- 4) Python venv -----------------------------------------------------
echo ""
echo "${CYN}${BLD}==> 4/6  Ambiente Python (.venv) + pip${RST}"

if [[ ! -x "$ROOT/.venv/bin/python" ]]; then
  echo "  Criando venv…"
  python3 -m venv "$ROOT/.venv"
fi
# shellcheck disable=SC1091
source "$ROOT/.venv/bin/activate"
python -m pip install --upgrade pip setuptools wheel
if [[ -f "$ROOT/requirements.txt" ]]; then
  pip install -r "$ROOT/requirements.txt"
else
  pip install "PySide6>=6.6.0" "qtawesome>=1.3.0" "dbus-next>=0.2.3" "numpy>=1.26.0"
fi

echo "  Python do venv: $(python --version 2>&1)"
python - <<'PY'
mods = ("PySide6", "qtawesome", "dbus_next", "numpy")
bad = []
for m in mods:
    try:
        __import__(m if m != "dbus_next" else "dbus_next")
        print(f"  ✔ pip: {m}")
    except Exception as e:
        print(f"  ✗ pip: {m} ({e})")
        bad.append(m)
raise SystemExit(1 if bad else 0)
PY

# --- 5) Atalhos ---------------------------------------------------------
echo ""
echo "${CYN}${BLD}==> 5/6  Atalhos (menu + PATH + permissões)${RST}"

chmod +x "$ROOT/abrir.sh" "$ROOT/instalar-ubuntu.sh" 2>/dev/null || true
chmod +x "$ROOT/bluetooth.py" "$ROOT/main.py" 2>/dev/null || true
chmod +x "$ROOT/scripts/empacotar-zip.sh" 2>/dev/null || true
chmod +x "$ROOT/Instalar-no-Ubuntu.desktop" "$ROOT/Bluetooth-Audio-Studio.desktop" 2>/dev/null || true

mkdir -p "$HOME/.local/share/applications"
DESKTOP="$HOME/.local/share/applications/bluetooth-audio-studio.desktop"
cat > "$DESKTOP" <<EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=Estúdio de Áudio Bluetooth
GenericName=Áudio / Bluetooth
Comment=Bluetooth + saída simultânea PipeWire + equalizador
Exec=$ROOT/.venv/bin/python $ROOT/bluetooth.py
Path=$ROOT
Icon=bluetooth
Terminal=false
Categories=AudioVideo;Audio;Settings;Qt;
StartupNotify=true
Keywords=bluetooth;audio;pipewire;caixa;fone;
EOF
chmod +x "$DESKTOP"

# Também um .desktop na pasta do projeto (fácil de achar)
APP_DESKTOP="$ROOT/Bluetooth-Audio-Studio.desktop"
cat > "$APP_DESKTOP" <<EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=Estúdio de Áudio Bluetooth
Comment=Abrir o aplicativo
Exec=$ROOT/.venv/bin/python $ROOT/bluetooth.py
Path=$ROOT
Icon=bluetooth
Terminal=false
Categories=AudioVideo;Audio;
EOF
chmod +x "$APP_DESKTOP"
gio set "$APP_DESKTOP" metadata::trusted true 2>/dev/null || true
gio set "$DESKTOP" metadata::trusted true 2>/dev/null || true

mkdir -p "$HOME/.local/bin"
cat > "$HOME/.local/bin/bluetooth-audio-studio" <<EOF
#!/usr/bin/env bash
exec "$ROOT/.venv/bin/python" "$ROOT/bluetooth.py" "\$@"
EOF
chmod +x "$HOME/.local/bin/bluetooth-audio-studio"

# Garante ~/.local/bin no PATH do bashrc
if ! grep -q 'HOME/.local/bin' "$HOME/.bashrc" 2>/dev/null; then
  {
    echo ''
    echo '# Bluetooth Audio Studio / apps locais'
    echo 'export PATH="$HOME/.local/bin:$PATH"'
  } >> "$HOME/.bashrc"
  echo "  PATH ~/.local/bin adicionado ao ~/.bashrc"
fi

update-desktop-database "$HOME/.local/share/applications" 2>/dev/null || true

# Atalho limpo no menu (abre main.py — sem VS Code / sem fechar sozinho)
if [[ -x "$ROOT/scripts/instalar-atalho-menu.sh" ]]; then
  bash "$ROOT/scripts/instalar-atalho-menu.sh" || true
fi

# Log da instalação (para mandar se der erro)
LOG="$ROOT/instalar-ubuntu.log"
{
  echo "==== $(date -Is) ===="
  echo "python: $(python3 --version 2>&1 || true)"
  echo "pactl: $(pactl --version 2>&1 | head -1 || true)"
  echo "pipewire: $(pipewire --version 2>&1 | head -1 || true)"
  echo "default sink: $(pactl get-default-sink 2>/dev/null || true)"
} >> "$LOG" 2>/dev/null || true
echo "  Log: $LOG"

# Se o filtro antigo estiver em loop (bas_clarity → bas_clarity), solta o som.
echo ""
echo "${CYN}${BLD}==> 5b  Áudio: desfaz loop do filtro se existir${RST}"
TARGET_FILE="${XDG_RUNTIME_DIR:-/tmp}/bas_audio/clarity.target"
if [[ -f "$TARGET_FILE" ]] && grep -qx 'bas_clarity' "$TARGET_FILE"; then
  echo "  Loop detectado — devolvendo o som para a saída real."
  if [[ -f "${XDG_RUNTIME_DIR:-/tmp}/bas_audio/clarity.pid" ]]; then
    pid="$(cat "${XDG_RUNTIME_DIR:-/tmp}/bas_audio/clarity.pid" 2>/dev/null || true)"
    if [[ -n "${pid:-}" ]]; then
      kill "$pid" 2>/dev/null || true
    fi
  fi
  REAL="$(pactl list short sinks 2>/dev/null | awk -F'\t' '$2 !~ /bas_clarity/ {print $2; exit}')"
  if [[ -n "${REAL:-}" ]]; then
    pactl set-default-sink "$REAL" 2>/dev/null || true
    echo "  Sink padrão: $REAL"
  fi
  rm -f "$TARGET_FILE"
fi

# --- 6) Validação final -------------------------------------------------
echo ""
echo "${CYN}${BLD}==> 6/6  Validação final${RST}"

FAIL=0
for cmd in python3 pactl; do
  if need_cmd "$cmd"; then
    echo "  ${GRN}✔${RST} comando $cmd"
  else
    echo "  ${RED}✗${RST} comando $cmd"
    FAIL=1
  fi
done

if [[ -x "$ROOT/.venv/bin/python" ]]; then
  echo "  ${GRN}✔${RST} .venv/bin/python"
else
  echo "  ${RED}✗${RST} .venv/bin/python"
  FAIL=1
fi

# Smoke import (sem abrir janela)
export QT_QPA_PLATFORM="${QT_QPA_PLATFORM:-offscreen}"
if "$ROOT/.venv/bin/python" - <<PY
import os, sys
os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")
sys.path.insert(0, r"$ROOT")
from PySide6.QtWidgets import QApplication
from bluetooth_audio_studio.config.settings import AppSettings
from bluetooth_audio_studio.main_window import MainWindow
app = QApplication([])
w = MainWindow(AppSettings().load())
assert "studio" in w._pages
w.close()
print("  UI import OK (Estúdio incluso)")
PY
then
  :
else
  echo "  ${YLW}!${RST} Validação da UI falhou (ainda pode abrir com ./abrir.sh)"
  FAIL=1
fi

echo ""
if [[ "$FAIL" -eq 0 ]]; then
  echo "${GRN}${BLD}✔ Instalação completa e validada.${RST}"
else
  echo "${YLW}${BLD}⚠ Instalação terminou com avisos — tente ./abrir.sh mesmo assim.${RST}"
fi

echo ""
echo "  ${BLD}Como abrir:${RST}"
echo "    • Menu de apps:  Estúdio de Áudio Bluetooth"
echo "    • Terminal:      bluetooth-audio-studio"
echo "    • Nesta pasta:   ./abrir.sh   ou   python3 bluetooth.py"
echo "    • Atalho local:  ./Bluetooth-Audio-Studio.desktop"
echo ""
echo "  ${BLD}Uso rápido:${RST}"
echo "    1) Aba Dispositivos → conectar a caixinha/fone"
echo "    2) Aba Áudio → «Cabo + todas as caixinhas»"
echo "    3) Aba Estúdio → preset Grave forte → Aplicar equalizador"
echo ""
echo "  Reinstalar / só checar:"
echo "    bash instalar-ubuntu.sh -y"
echo "    bash instalar-ubuntu.sh --check"
echo ""
echo "  Empacotar ZIP para outra pessoa:"
echo "    bash scripts/empacotar-zip.sh"
echo ""
