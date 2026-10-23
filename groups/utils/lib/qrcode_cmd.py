#!/usr/bin/env python3
"""Create QR codes (image file + terminal art) and read them back. Usage: qrcode_cmd.py encode|decode ..."""

import os
import shutil
import subprocess
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "..", "lib"))
from clibase import Parser, _, fail, group_configdata  # noqa: E402
import extras  # noqa: E402


def render_ascii(matrix, border: int = 2, invert: bool = False) -> str:
    """Render a boolean module matrix (True = dark) with half-block characters.

    Light modules are drawn as filled blocks, so the code scans on a dark
    terminal; invert=True swaps that for light terminals.
    """
    width = len(matrix[0])
    blank = [False] * (width + 2 * border)
    rows = [blank] * border + [[False] * border + list(r) + [False] * border for r in matrix] + [blank] * border
    if len(rows) % 2:
        rows.append(blank)
    glyph = {(True, True): " ", (True, False): "▄", (False, True): "▀", (False, False): "█"}
    if invert:
        glyph = {k: glyph[(not k[0], not k[1])] for k in glyph}
    lines = []
    for top, bottom in zip(rows[0::2], rows[1::2]):
        lines.append("".join(glyph[(t, b)] for t, b in zip(top, bottom)))
    return "\n".join(lines)


def main_encode() -> int:
    parser = Parser("utils", "qrencode", description=_(
        "Encode text as a QR code: write an image file and print the code as terminal art."))
    parser.add_argument("-o", "--output", default="qr.png", metavar="FILE",
                        help=_("image file to write; the format follows the extension: png, svg, pdf, eps (default: qr.png)"))
    parser.add_argument("-e", "--error", choices=("L", "M", "Q", "H"), default="M", metavar="LEVEL",
                        help=_("error correction level L, M, Q or H (default: M)"))
    parser.add_argument("-s", "--scale", type=int, default=10, metavar="N",
                        help=_("pixels per module in the image (default: 10)"))
    parser.add_argument("--border", type=int, default=4, metavar="N",
                        help=_("quiet zone around the code, in modules (default: 4)"))
    parser.add_argument("--no-image", action="store_true", help=_("print the terminal art only, write no file"))
    parser.add_argument("--no-ascii", action="store_true", help=_("write the image only, print no terminal art"))
    parser.add_argument("--invert", action="store_true", help=_("terminal art for a light terminal background"))
    parser.add_argument("--force", action="store_true", help=_("overwrite an existing image file"))
    parser.add_argument("text", nargs="*", metavar="TEXT",
                        help=_("text to encode (default: read standard input)"))
    args = parser.parse_args()
    if args.scale < 1 or args.border < 0:
        parser.error(_("--scale must be at least 1 and --border at least 0"))
    if args.no_image and args.no_ascii:
        parser.error(_("--no-image and --no-ascii cannot be combined"))
    if args.text:
        text = " ".join(args.text)
    elif sys.stdin.isatty():
        parser.error(_("no text: give TEXT or provide stdin"))
    else:
        text = sys.stdin.read().rstrip("\n")
    if not text:
        parser.error(_("nothing to encode"))
    try:
        import segno
    except ImportError:
        return fail("qrencode", _("the Python module segno is required (pip install segno)"))
    try:
        code = segno.make_qr(text, error=args.error.lower())
    except Exception as exc:  # segno raises DataOverflowError, ValueError, ...
        return fail("qrencode", _("cannot encode the text: {}").format(exc))
    if not args.no_image:
        if os.path.exists(args.output) and not args.force:
            return fail("qrencode", _("refusing to overwrite {} (use --force)").format(args.output))
        try:
            code.save(args.output, scale=args.scale, border=args.border)
        except (OSError, ValueError) as exc:
            return fail("qrencode", _("cannot write {}: {}").format(args.output, exc))
        print(_("wrote {}").format(args.output), file=sys.stderr)
    if not args.no_ascii:
        print(render_ascii([[bool(m) for m in row] for row in code.matrix],
                           border=min(args.border, 4), invert=args.invert))
    return 0


# ------------------------------------------------------------------ qrdecode backends
# Each backend returns the texts of the QR codes of an image, or raises BackendError.
# "zbar" calls the zbarimg command (package zbar-tools): small, no Python packages.
# "opencv" uses the Python module cv2 (extra qr-opencv: about 150 MB to download).
class BackendError(Exception):
    pass


def decode_zbar(path):
    command = shutil.which("zbarimg")
    if not command:
        raise BackendError(_("zbarimg is not installed (package zbar-tools)"))
    result = subprocess.run([command, "--quiet", "--raw", "-Sdisable", "-Sqrcode.enable", path],
                            capture_output=True, text=True, check=False)
    if result.returncode not in (0, 4):                       # 4: no code found
        raise BackendError(result.stderr.strip() or _("zbarimg failed"))
    return [line for line in result.stdout.splitlines() if line]


def decode_opencv(path):
    import cv2
    image = cv2.imread(path)
    if image is None:
        raise BackendError(_("cannot read image: {}").format(path))
    detector = cv2.QRCodeDetector()
    found = []
    try:
        ok, texts, _points, _straight = detector.detectAndDecodeMulti(image)
        if ok:
            found = [t for t in texts if t]
    except cv2.error:
        pass
    if not found:
        text, _points, _straight = detector.detectAndDecode(image)
        found = [text] if text else []
    return found


def opencv_present():
    try:
        import cv2  # noqa: F401
        return True
    except ImportError:
        return False


BACKENDS = {
    "zbar": (decode_zbar, lambda: shutil.which("zbarimg") is not None),
    "opencv": (decode_opencv, opencv_present),
}
EXTRA_FOR = {"opencv": ("cv2", "qr-opencv")}                  # backend -> (module, extra to install)


def configured_backends():
    """Backends in order of preference, from groups.utils.configdata.qrdecode.backends."""
    value = (group_configdata("utils").get("qrdecode") or {}).get("backends")
    if isinstance(value, str):
        value = [value]
    names = [n for n in value or [] if n in BACKENDS]
    return names or ["zbar", "opencv"]


def pick_backend(requested, prog):
    """Name of the backend to use, installing an extra on request; None if there is none."""
    if requested:
        if not BACKENDS[requested][1]() and requested in EXTRA_FOR:
            module, extra = EXTRA_FOR[requested]
            if not extras.ensure(module, extra, _("The {} backend of qrdecode").format(requested), prog):
                return None
        return requested
    order = configured_backends()
    for name in order:
        if BACKENDS[name][1]():
            return name
    for name in order:                                          # nothing present: offer a Python one
        if name in EXTRA_FOR:
            module, extra = EXTRA_FOR[name]
            if extras.ensure(module, extra, _("The {} backend of qrdecode").format(name), prog):
                return name
            return None
    return None


def main_decode() -> int:
    parser = Parser("utils", "qrdecode", description=_("Read the QR codes found in image files and print their text."))
    parser.add_argument("-b", "--backend", choices=sorted(BACKENDS), metavar="NAME",
                        help=_("decoder to use: zbar (the zbarimg command) or opencv (Python); default: "
                               "the first available of groups.utils.configdata.qrdecode.backends"))
    parser.add_argument("files", nargs="+", metavar="FILE", help=_("image file to read"))
    args = parser.parse_args()
    backend = pick_backend(args.backend, "qrdecode")
    if backend is None:
        return fail("qrdecode", _("no QR decoder is available: install zbar-tools or run {}").format(
            extras.command_for("qr-opencv")))
    decode = BACKENDS[backend][0]
    status = 0
    for path in args.files:
        try:
            found = decode(path)
        except BackendError as exc:
            status = fail("qrdecode", str(exc))
            continue
        if not found:
            status = fail("qrdecode", _("no QR code found in {}").format(path))
            continue
        for text in found:
            print(text)
    return status


if __name__ == "__main__":
    if len(sys.argv) < 2 or sys.argv[1] not in ("encode", "decode"):
        sys.exit("usage: qrcode_cmd.py encode|decode ...")
    mode = sys.argv.pop(1)
    sys.exit(main_encode() if mode == "encode" else main_decode())
