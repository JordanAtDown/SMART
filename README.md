![logo](icons/app-icon.png)

# SMART AI mask builder

SMART (Segmentation Model for ART) is a simple AI mask generator for
images using Segment Anything 2, tailored to masks that can be used
with the ART raw image processor.

## Prerequisites

Make sure you have the following installed:

1. **Python 3**
2. **SAM2**: https://github.com/facebookresearch/sam2
3. **wxPython**: https://wxpython.org
4. **Pillow**: https://pillow.readthedocs.io/
5. **platformdirs**: http://pypi.org/project/platformdirs/

All the dependencies can be installed with PIP, with the command
`pip install -r requirements.txt`.

## License

[GNU GPL](https://www.gnu.org/licenses/gpl-3.0.en.html)

## Automated install (WSL2 + NVIDIA GPU)

On Windows with WSL2 and an NVIDIA GPU (CUDA), `install.sh` sets up
everything end to end: system packages (wxPython, exiftool), a Python
virtual environment, a CUDA-enabled PyTorch build, SAM2, and a default
model checkpoint, then writes a working configuration file.

```bash
./install.sh
```

The NVIDIA driver with WSL support must already be installed on the
Windows side (check with `nvidia-smi` from WSL). The script installs
system packages with `apt`, so it will prompt for your `sudo` password;
if you don't have sudo rights, install `python3-venv`, `python3-pip`,
`python3-wxgtk4.0` and `libimage-exiftool-perl` yourself and re-run with
`SKIP_APT=1 ./install.sh`.

Useful environment variables:

- `SAM2_MODEL` — checkpoint to download/use (default:
  `sam2.1_hiera_base_plus.pt`; other options: `sam2.1_hiera_tiny.pt`,
  `sam2.1_hiera_small.pt`, `sam2.1_hiera_large.pt`).
- `TORCH_INDEX_URL` — PyTorch pip index (default: the `cu128` CUDA
  build, which supports current NVIDIA GPUs including Blackwell/RTX
  50-series).
- `SKIP_APT=1` — skip the `apt` step (see above).

Without a GPU, the script still works and falls back to a CPU-only
PyTorch build (masking will be much slower).

## Setup (manual)

Download one of the SAM 2 model checkpoints from
https://github.com/facebookresearch/sam2?tab=readme-ov-file#download-checkpoints,
and put it in the `models/` directory.

Run `python src/main.py --init-config` from a terminal to create an
initial configuration file.  The path to the file will be printed in
output.  Edit the file with a text editor, and adapt the `model` and
`device` parameters to your setup, where `model` should be the name of
the SAM2 checkpoint to use, and `device` the device to use for
computations: `"cuda"` for a CUDA-capable GPU, `"mps"` for the GPU on
an ARM Apple machine, or `"cpu"` otherwise (this might be slow though).

## Running

From WSL/Linux, once installed (either via `install.sh` or manually):

```bash
./run.sh
```

This activates the virtual environment and starts the app; under
WSL2 with WSLg (Windows 11), the window appears directly on the
Windows desktop with no extra configuration.

On Windows, `windows/SMART.bat` launches the app from WSL without
opening a terminal manually — copy it to your Desktop (or make a
shortcut to it) and double-click it.

## Usage

Build a mask for the image by adding positive and negative points, by
using *shift+left click* and *shift+right click* respectively. The
mask is built on the fly. When you are happy, save the mask.
