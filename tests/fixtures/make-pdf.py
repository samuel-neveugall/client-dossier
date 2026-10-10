#!/usr/bin/env python3
"""Generate a throwaway PDF for the extract-text.sh tests.

    make-pdf.py OUT.pdf PAGE...

Writes exactly one file, OUT.pdf, with one page per PAGE argument, and nothing
else: no other file, no temporary file, no network. A PAGE is one of:

    <text>    one line of text drawn on the page; it must be representable in
              Latin-1 (accents included), the font uses WinAnsiEncoding
    @empty    a page whose content stream is empty (no text, no graphics)
    @scan     a page holding a filled rectangle and no text, like the image-only
              pages of a scanned document (pdftotext finds no text layer)

The PDF is a minimal PDF 1.4 document with a correct cross-reference table.
Every generated file is readable by pdftotext. Nothing generated is committed:
tests build their PDFs into a mktemp folder.

Python 3 standard library only, targeting Python >= 3.8.
"""
import sys

EMPTY = "@empty"
SCAN = "@scan"


def escape(data):
    """Escape the three bytes that are special inside a PDF literal string."""
    return data.replace(b"\\", b"\\\\").replace(b"(", b"\\(").replace(b")", b"\\)")


def content_for(page):
    """The content-stream bytes of one page."""
    if page == EMPTY:
        return b""
    if page == SCAN:
        return b"0 0 200 200 re f"
    text = escape(page.encode("latin-1"))
    return b"BT /F1 12 Tf 72 720 Td (" + text + b") Tj ET"


def build(pages):
    """The bytes of a PDF holding one page per element of `pages`."""
    count = len(pages)
    # Object numbers: 1 catalog, 2 page tree, 3 font, then (page, content) pairs.
    kids = " ".join("{} 0 R".format(4 + 2 * i) for i in range(count))
    bodies = [
        b"<< /Type /Catalog /Pages 2 0 R >>",
        "<< /Type /Pages /Kids [{}] /Count {} >>".format(kids, count).encode("ascii"),
        b"<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica"
        b" /Encoding /WinAnsiEncoding >>",
    ]
    for i, page in enumerate(pages):
        content_obj = 5 + 2 * i
        bodies.append(
            (
                "<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792]"
                " /Resources << /Font << /F1 3 0 R >> >> /Contents {} 0 R >>"
            ).format(content_obj).encode("ascii")
        )
        stream = content_for(page)
        bodies.append(
            "<< /Length {} >>\nstream\n".format(len(stream)).encode("ascii")
            + stream
            + b"\nendstream"
        )

    out = bytearray(b"%PDF-1.4\n")
    offsets = []
    for number, body in enumerate(bodies, start=1):
        offsets.append(len(out))
        out += "{} 0 obj\n".format(number).encode("ascii") + body + b"\nendobj\n"
    xref_at = len(out)
    out += "xref\n0 {}\n".format(len(bodies) + 1).encode("ascii")
    out += b"0000000000 65535 f \n"
    for offset in offsets:
        out += "{:010d} 00000 n \n".format(offset).encode("ascii")
    out += "trailer\n<< /Size {} /Root 1 0 R >>\nstartxref\n{}\n%%EOF\n".format(
        len(bodies) + 1, xref_at
    ).encode("ascii")
    return bytes(out)


def main(argv):
    if len(argv) < 3:
        print("usage: make-pdf.py OUT.pdf PAGE...", file=sys.stderr)
        return 2
    out_path, pages = argv[1], argv[2:]
    for page in pages:
        if page in (EMPTY, SCAN):
            continue
        try:
            page.encode("latin-1")
        except UnicodeEncodeError:
            print("make-pdf.py: not representable in Latin-1: {!r}".format(page), file=sys.stderr)
            return 2
    with open(out_path, "wb") as handle:
        handle.write(build(pages))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
