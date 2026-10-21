#!/usr/bin/env python3
"""Create QR codes (image file + terminal art) and read them back. Usage: qrcode_cmd.py encode|decode ..."""

import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "..", "lib"))
from clibase import Parser, _, fail  # noqa: E402


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
        code = segno.make(text, error=args.error.lower())
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


def main_decode() -> int:
    parser = Parser("utils", "qrdecode", description=_("Read the QR codes found in image files and print their text."))
    parser.add_argument("files", nargs="+", metavar="FILE", help=_("image file to read"))
    args = parser.parse_args()
    try:
        import cv2
    except ImportError:
        return fail("qrdecode", _("the Python module cv2 is required (pip install opencv-python-headless)"))
    detector = cv2.QRCodeDetector()
    status = 0
    for path in args.files:
        image = cv2.imread(path)
        if image is None:
            status = fail("qrdecode", _("cannot read image: {}").format(path))
            continue
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
