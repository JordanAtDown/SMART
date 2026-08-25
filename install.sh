#!/usr/bin/env bash
#
# Installe SMART (avec PyTorch + CUDA) dans un environnement WSL2 / Ubuntu.
# Idempotent : peut être relancé sans casser une installation existante.
#
# Variables surchargeables :
#   TORCH_INDEX_URL  index pip pour PyTorch CUDA (defaut: cu128, supporte
#                     les GPU Blackwell type RTX 50xx). Voir
#                     https://pytorch.org/get-started/locally/ si besoin
#                     d'une autre version.
#   SAM2_MODEL        checkpoint SAM2 a telecharger/utiliser
#                     (defaut: sam2.1_hiera_base_plus.pt, comme config.py)
#   SKIP_APT          si "1", saute l'installation des paquets systeme
#                     (utile si vous n'avez pas les droits sudo)

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VENV_DIR="$ROOT_DIR/.venv"
TORCH_INDEX_URL="${TORCH_INDEX_URL:-https://download.pytorch.org/whl/cu128}"
SAM2_MODEL="${SAM2_MODEL:-sam2.1_hiera_base_plus.pt}"
SKIP_APT="${SKIP_APT:-0}"

CHECKPOINT_BASE_URL="https://dl.fbaipublicfiles.com/segment_anything_2/092824"

log()  { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m!!\033[0m %s\n' "$*"; }
die()  { printf '\033[1;31mERREUR:\033[0m %s\n' "$*" >&2; exit 1; }

# ---------------------------------------------------------------------------
log "Verification de l'environnement"
# ---------------------------------------------------------------------------

if grep -qi microsoft /proc/version 2>/dev/null; then
    log "WSL detecte."
else
    warn "Ce script est prevu pour WSL2, mais devrait fonctionner sur Ubuntu natif."
fi

HAS_GPU=0
if command -v nvidia-smi >/dev/null 2>&1 && nvidia-smi >/dev/null 2>&1; then
    GPU_NAME="$(nvidia-smi --query-gpu=name --format=csv,noheader | head -1)"
    log "GPU detecte : $GPU_NAME"
    HAS_GPU=1
else
    warn "Aucun GPU CUDA detecte via nvidia-smi."
    warn "Verifiez que le driver NVIDIA (avec support WSL) est installe cote Windows."
    warn "Poursuite de l'installation en mode CPU (device sera mis a \"cpu\")."
fi

# ---------------------------------------------------------------------------
log "Paquets systeme (apt)"
# ---------------------------------------------------------------------------

if [ "$SKIP_APT" = "1" ]; then
    warn "SKIP_APT=1 : etape sautee, verifiez vous-meme python3-venv, python3-wxgtk4.0, libimage-exiftool-perl."
else
    sudo apt-get update
    sudo apt-get install -y \
        python3-venv \
        python3-pip \
        python3-wxgtk4.0 \
        libimage-exiftool-perl \
        curl
fi

# ---------------------------------------------------------------------------
log "Environnement virtuel Python ($VENV_DIR)"
# ---------------------------------------------------------------------------

# --system-site-packages : permet d'utiliser le wxPython installe par apt
# (le compiler via pip est long et requiert beaucoup de dependances de build).
if [ ! -d "$VENV_DIR" ]; then
    python3 -m venv --system-site-packages "$VENV_DIR"
    log "Venv cree."
else
    log "Venv existant reutilise."
fi

# shellcheck disable=SC1091
source "$VENV_DIR/bin/activate"
pip install --upgrade pip wheel setuptools

# ---------------------------------------------------------------------------
log "PyTorch"
# ---------------------------------------------------------------------------

if [ "$HAS_GPU" = "1" ]; then
    log "Installation de PyTorch (CUDA, index: $TORCH_INDEX_URL)"
    pip install --upgrade torch torchvision --index-url "$TORCH_INDEX_URL"
else
    log "Installation de PyTorch (CPU uniquement)"
    pip install --upgrade torch torchvision
fi

# ---------------------------------------------------------------------------
log "Dependances du projet (SAM2, wxPython via apt, Pillow, platformdirs)"
# ---------------------------------------------------------------------------

pip install --upgrade "pillow>=11.3.0" platformdirs
pip install --upgrade "git+https://github.com/facebookresearch/sam2.git"

python -c "import wx" 2>/dev/null \
    || die "wxPython non importable dans le venv. Verifiez l'installation de python3-wxgtk4.0 et que le venv a bien --system-site-packages."

# ---------------------------------------------------------------------------
log "Telechargement du checkpoint SAM2 ($SAM2_MODEL)"
# ---------------------------------------------------------------------------

MODEL_PATH="$ROOT_DIR/models/$SAM2_MODEL"
if [ -f "$MODEL_PATH" ]; then
    log "Checkpoint deja present : $MODEL_PATH"
else
    mkdir -p "$ROOT_DIR/models"
    curl -L --fail --progress-bar -o "$MODEL_PATH" \
        "$CHECKPOINT_BASE_URL/$SAM2_MODEL" \
        || die "Echec du telechargement. Telechargez-le manuellement depuis https://github.com/facebookresearch/sam2 et placez-le dans models/."
    log "Checkpoint telecharge : $MODEL_PATH"
fi

# ---------------------------------------------------------------------------
log "Configuration"
# ---------------------------------------------------------------------------

DEVICE="cpu"
[ "$HAS_GPU" = "1" ] && DEVICE="cuda"

python - "$DEVICE" "$SAM2_MODEL" <<'PYEOF'
import sys
sys.path.insert(0, "src")
import config

device, model = sys.argv[1], sys.argv[2]
conf = config.Config.load()
conf.device = device
conf.model = model
conf.save()
print(f"Configuration ecrite dans : {config.Config.get_config_file()}")
print(f"  device = {device}")
print(f"  model  = {model}")
PYEOF

# ---------------------------------------------------------------------------
log "Verification finale"
# ---------------------------------------------------------------------------

python - <<'PYEOF'
import torch
print(f"torch          : {torch.__version__}")
print(f"cuda disponible: {torch.cuda.is_available()}")
if torch.cuda.is_available():
    print(f"GPU utilise    : {torch.cuda.get_device_name(0)}")
import wx
print(f"wxPython       : {wx.version()}")
import sam2  # noqa: F401
print("sam2           : import OK")
PYEOF

echo
log "Installation terminee."
echo "Pour lancer SMART :"
echo "  source $VENV_DIR/bin/activate"
echo "  cd $ROOT_DIR/src && python main.py"
