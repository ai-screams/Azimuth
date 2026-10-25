#!/usr/bin/env python3
"""영어 원본(`docs/index.html`, `docs/manual.html`)에서 한국어 정적 페이지(`docs/ko/…`)를 만든다(#212).

검색엔진은 서버가 보낸 HTML을 색인하므로, JS로 바꿔 끼우던 한국어를 별도 주소의 HTML로 낸다. 규칙은 셋뿐이다.

1. `data-ko`가 있는 요소는 내용을 그 값으로 바꾼다. 글자로 넣고(이스케이프), `.install-note`만 HTML로 넣는다.
2. `data-ko-<속성>`이 있으면 그 속성을 그 값으로 바꾸거나 더한다(`data-ko-href`, `data-ko-aria-label`, `data-ko-lang`…).
3. `assets/`로 시작하는 `href`·`src`는 `../assets/`로 바꾼다(한국어 페이지는 한 단계 아래 폴더에 있다).

원본을 다시 직렬화하지 않고 위치로 잘라 붙여, 생성 결과의 diff가 원본 diff와 같은 모양이 되게 한다.
날짜·git 정보를 넣지 않으므로 `--check`는 같은 원본에서 늘 같은 결과를 기대한다.

    python3 scripts/site/build-ko.py           # docs/ko/를 다시 쓴다
    python3 scripts/site/build-ko.py --check   # 다시 만든 결과가 커밋된 파일과 다르면 실패(CI)
"""

import html
import html.parser
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parents[2]
PAGES = ["index.html", "manual.html"]
VOID = {"area", "base", "br", "col", "embed", "hr", "img", "input", "link", "meta", "source", "track", "wbr"}
RAW_HTML_CLASS = "install-note"
HEADER = "<!-- Generated from docs/{name} by scripts/site/build-ko.py. Edit the English source and rerun. -->\n"


class Element:
    def __init__(self, tag, attrs, start, raw):
        self.tag, self.attrs, self.start, self.raw = tag, dict(attrs), start, raw
        self.content_start = start + len(raw)
        self.content_end = None  # 닫는 태그가 시작하는 위치
        self.has_child_element = False


class Scanner(html.parser.HTMLParser):
    """요소마다 원본 안의 위치(여는 태그, 내용 범위)를 모은다."""

    def __init__(self, text):
        super().__init__(convert_charrefs=True)
        self.text = text
        self.line_offsets = [0]
        for line in text.splitlines(keepends=True):
            self.line_offsets.append(self.line_offsets[-1] + len(line))
        self.stack, self.elements = [], []

    def position(self):
        line, col = self.getpos()
        return self.line_offsets[line - 1] + col

    def handle_starttag(self, tag, attrs):
        if self.stack:
            self.stack[-1].has_child_element = True
        element = Element(tag, attrs, self.position(), self.get_starttag_text())
        self.elements.append(element)
        if tag not in VOID:
            self.stack.append(element)

    def handle_startendtag(self, tag, attrs):
        if self.stack:
            self.stack[-1].has_child_element = True
        self.elements.append(Element(tag, attrs, self.position(), self.get_starttag_text()))

    def handle_endtag(self, tag):
        if tag in VOID:
            return
        for i in range(len(self.stack) - 1, -1, -1):
            if self.stack[i].tag == tag:
                self.stack[i].content_end = self.position()
                del self.stack[i:]
                return


def set_attribute(raw, name, value):
    """여는 태그 원문에서 속성 하나를 바꾸거나, 없으면 닫는 `>` 앞에 더한다."""
    quoted = '"' + html.escape(value, quote=True) + '"'
    pattern = re.compile(r"(\s)" + re.escape(name) + r"""=("[^"]*"|'[^']*'|[^\s>]+)""")
    if pattern.search(raw):
        return pattern.sub(lambda m: m.group(1) + name + "=" + quoted, raw, count=1)
    tail = re.search(r"\s*/?>$", raw)
    return raw[: tail.start()] + " " + name + "=" + quoted + raw[tail.start() :]


def start_tag(element):
    raw = element.raw
    for name, value in element.attrs.items():
        if name.startswith("data-ko-") and value is not None:
            raw = set_attribute(raw, name[len("data-ko-") :], value)
    for name in ("href", "src"):
        value = element.attrs.get("data-ko-" + name, element.attrs.get(name))
        if value and value.startswith("assets/"):
            raw = set_attribute(raw, name, "../" + value)
    return raw


def translate(text, name):
    scanner = Scanner(text)
    scanner.feed(text)
    scanner.close()
    edits, contents, problems = [], [], []
    for element in scanner.elements:
        new_raw = start_tag(element)
        if new_raw != element.raw:
            edits.append((element.start, element.start + len(element.raw), new_raw))
        if "data-en" in element.attrs and "data-ko" not in element.attrs:
            problems.append(f"{name}: <{element.tag}> has data-en but no data-ko")
        if "data-ko" not in element.attrs:
            continue
        if element.content_end is None:
            problems.append(f"{name}: <{element.tag} data-ko> has no closing tag")
            continue
        raw_html = RAW_HTML_CLASS in (element.attrs.get("class") or "").split()
        # textContent로 바꾸던 시절 아이콘이 지워진 버그(#215)를 다시 들이지 않는다. 글자만 담는 요소에 단다.
        if element.has_child_element and not raw_html:
            problems.append(f"{name}: <{element.tag} data-ko> holds child elements; put data-ko on an inner span")
        value = element.attrs["data-ko"] or ""
        contents.append((element.content_start, element.content_end, value if raw_html else html.escape(value, quote=False)))
    if problems:
        raise SystemExit("\n".join(problems))
    # 내용을 통째로 바꾸는 요소 안쪽의 여는 태그 편집은 버린다. 위치가 큰 것부터 붙인다.
    def inside(ed):
        return any(s <= ed[0] and ed[1] <= e and (s, e) != (ed[0], ed[1]) for s, e, _ in contents)

    kept = [ed for ed in edits if not any(s <= ed[0] and ed[1] <= e for s, e, _ in contents)]
    kept += [ed for ed in contents if not inside(ed)]
    out = text
    for s, e, new in sorted(kept, key=lambda ed: ed[0], reverse=True):
        out = out[:s] + new + out[e:]
    doctype = re.match(r"<!DOCTYPE html>\n", out, re.IGNORECASE)
    at = doctype.end() if doctype else 0
    return out[:at] + HEADER.format(name=name) + out[at:]


def main(argv):
    check = argv[1:] == ["--check"]
    if argv[1:] not in ([], ["--check"]):
        raise SystemExit("usage: build-ko.py [--check]")
    stale = []
    for name in PAGES:
        source = (ROOT / "docs" / name).read_text(encoding="utf-8")
        target = ROOT / "docs" / "ko" / name
        result = translate(source, name)
        if check:
            if not target.exists() or target.read_text(encoding="utf-8") != result:
                stale.append(str(target.relative_to(ROOT)))
        else:
            target.parent.mkdir(exist_ok=True)
            target.write_text(result, encoding="utf-8")
    if stale:
        raise SystemExit("out of date, run python3 scripts/site/build-ko.py: " + ", ".join(stale))


if __name__ == "__main__":
    main(sys.argv)
