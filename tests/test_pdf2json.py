import importlib.util
import json
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "groups" / "biblio" / "pdf2json.sh"
SPEC = importlib.util.spec_from_file_location("pdf2json", ROOT / "groups" / "biblio" / "lib" / "pdf2json.py")
assert SPEC and SPEC.loader
pdf2json = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(pdf2json)

XMP = """<?xpacket begin="" id="W5M0MpCehiHzreSzNTczkc9d"?>
<x:xmpmeta xmlns:x="adobe:ns:meta/">
 <rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#">
  <rdf:Description rdf:about="" xmlns:dc="http://purl.org/dc/elements/1.1/"
      xmlns:xmp="http://ns.adobe.com/xap/1.0/" xmp:CreatorTool="Writer">
   <dc:title><rdf:Alt><rdf:li xml:lang="x-default">Titre XMP</rdf:li></rdf:Alt></dc:title>
   <dc:creator><rdf:Seq><rdf:li>Ada</rdf:li><rdf:li>Bob</rdf:li></rdf:Seq></dc:creator>
   <dc:publisher>Éditions Test</dc:publisher>
   <dc:language><rdf:Bag><rdf:li>fr</rdf:li></rdf:Bag></dc:language>
  </rdf:Description>
 </rdf:RDF>
</x:xmpmeta>
<?xpacket end="w"?>"""


def minimal_pdf(path, info):
    """Write a one-page PDF whose text is 'Bonjour PDF' and whose Info is `info`."""
    objects = [
        "<< /Type /Catalog /Pages 2 0 R >>",
        "<< /Type /Pages /Kids [3 0 R] /Count 1 >>",
        "<< /Type /Page /Parent 2 0 R /MediaBox [0 0 200 100] /Contents 4 0 R "
        "/Resources << /Font << /F1 5 0 R >> >> >>",
        None,
        "<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>",
        "<< " + " ".join(f"/{key} ({value})" for key, value in info.items()) + " >>",
    ]
    stream = "BT /F1 12 Tf 20 50 Td (Bonjour PDF) Tj ET"
    objects[3] = f"<< /Length {len(stream)} >>\nstream\n{stream}\nendstream"
    body = b"%PDF-1.4\n"
    offsets = []
    for number, content in enumerate(objects, start=1):
        offsets.append(len(body))
        body += f"{number} 0 obj\n{content}\nendobj\n".encode("latin-1")
    xref = len(body)
    body += f"xref\n0 {len(objects) + 1}\n0000000000 65535 f \n".encode()
    for offset in offsets:
        body += f"{offset:010d} 00000 n \n".encode()
    body += (
        f"trailer\n<< /Size {len(objects) + 1} /Root 1 0 R /Info 6 0 R >>\n"
        f"startxref\n{xref}\n%%EOF\n"
    ).encode()
    path.write_bytes(body)


class XmpTests(unittest.TestCase):
    def test_xmp_fields_are_flattened(self):
        with patch.object(pdf2json, "run", return_value=XMP):
            fields = pdf2json.xmp_fields(Path("x.pdf"))
        self.assertEqual(fields["title"], "Titre XMP")
        self.assertEqual(fields["creator"], ["Ada", "Bob"])
        self.assertEqual(fields["publisher"], "Éditions Test")
        self.assertEqual(fields["language"], ["fr"])
        self.assertEqual(fields["creatortool"], "Writer")

    def test_missing_xmp_gives_no_fields(self):
        with patch.object(pdf2json, "run", return_value=""):
            self.assertEqual(pdf2json.xmp_fields(Path("x.pdf")), {})


@unittest.skipUnless(shutil.which("pdfinfo") and shutil.which("pdftotext"), "poppler is required")
class ConversionTests(unittest.TestCase):
    def convert(self, directory, *arguments):
        return subprocess.run(
            [SCRIPT, *arguments], capture_output=True, text=True, cwd=directory
        )

    def test_key_frontmatter_and_text(self):
        with tempfile.TemporaryDirectory() as directory:
            directory = Path(directory)
            minimal_pdf(directory / "mon article.pdf", {"Title": "Un titre", "Author": "Ada", "Place": "Paris"})
            result = self.convert(directory, "mon article.pdf")
            self.assertEqual(result.returncode, 0, result.stderr)
            data = json.loads((directory / "mon article.json").read_text(encoding="utf-8"))
            self.assertEqual(list(data), ["key", "frontmatter", "text"])
            self.assertEqual(data["key"], "mon article")
            self.assertEqual(data["text"], "Bonjour PDF")
            self.assertEqual(data["frontmatter"]["title"], "Un titre")
            self.assertEqual(data["frontmatter"]["author"], "Ada")
            self.assertEqual(data["frontmatter"]["pages"], 1)
            if shutil.which("qpdf"):
                self.assertEqual(data["frontmatter"]["place"], "Paris")

    def test_outdir_stdout_and_failures(self):
        with tempfile.TemporaryDirectory() as directory:
            directory = Path(directory)
            minimal_pdf(directory / "a.pdf", {"Title": "A"})
            minimal_pdf(directory / "b.pdf", {"Title": "B"})
            result = self.convert(directory, "-d", "out", "a.pdf", "missing.pdf", "b.pdf")
            self.assertEqual(result.returncode, 1)
            self.assertIn("missing.pdf", result.stderr)
            self.assertTrue((directory / "out" / "a.json").is_file())
            self.assertTrue((directory / "out" / "b.json").is_file())

            result = self.convert(directory, "-o", "-", "a.pdf")
            self.assertEqual(json.loads(result.stdout)["key"], "a")
            self.assertFalse((directory / "a.json").exists())
            self.assertNotEqual(self.convert(directory, "-o", "x.json", "a.pdf", "b.pdf").returncode, 0)


if __name__ == "__main__":
    unittest.main()
