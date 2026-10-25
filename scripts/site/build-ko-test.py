#!/usr/bin/env python3
"""`build-ko.py`의 변환 규칙을 작은 HTML로 검사한다(파일·네트워크 없음). CI release-scripts가 부른다."""

import importlib.util
import pathlib
import sys

sys.dont_write_bytecode = True  # 불러오는 스크립트의 __pycache__를 레포에 남기지 않는다
HERE = pathlib.Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location("build_ko", HERE / "build-ko.py")
build_ko = importlib.util.module_from_spec(spec)
spec.loader.exec_module(build_ko)
failures = 0


def report(ok: bool, label: str, detail: str = "") -> None:
    global failures
    print(f"{'ok  ' if ok else 'FAIL'} {label}{'' if ok else ' — ' + detail}")
    failures += 0 if ok else 1


def page(body: str, html_tag: str = '<html lang="en" data-ko-lang="ko">') -> str:
    return f"<!DOCTYPE html>\n{html_tag}\n<head></head>\n<body>\n{body}\n</body>\n</html>\n"


def has(label: str, body: str, expected: str) -> None:
    out = build_ko.translate(page(body), "t.html")
    report(expected in out, label, out)


def rejects(label: str, body: str) -> None:
    try:
        build_ko.translate(page(body), "t.html")
    except SystemExit as stop:
        report(isinstance(stop.code, str), label, f"exit {stop.code!r}")
        return
    report(False, label, "did not fail")


# 이것을 실패시키는 것: data-ko 값을 내용에 넣지 않거나 이스케이프하지 않는 것
has("text content becomes data-ko, escaped", '<p data-en="Hi" data-ko="&lt;b&gt; &amp; 안녕">Hi</p>',
    '<p data-en="Hi" data-ko="&lt;b&gt; &amp; 안녕">&lt;b&gt; &amp; 안녕</p>')
# 이것을 실패시키는 것: .install-note도 이스케이프하는 것(링크·굵은 글씨가 글자로 보인다)
has("install-note takes data-ko as HTML",
    '<p class="install-note" data-en="x" data-ko="&lt;strong&gt;굵게&lt;/strong&gt;">x</p>',
    "><strong>굵게</strong></p>")
# 이것을 실패시키는 것: data-ko-<속성>을 무시하는 것
has("data-ko-href replaces href", '<a href="./" data-ko-href="../">EN</a>', '<a href="../" data-ko-href="../">EN</a>')
# 이것을 실패시키는 것: 없는 속성을 더하지 않는 것(한국어 링크에 aria-current가 안 붙는다)
has("data-ko-<attr> adds a missing attribute", '<a href="ko/" data-ko-aria-current="page">KO</a>',
    'data-ko-aria-current="page" aria-current="page">KO</a>')
# 이것을 실패시키는 것: <html lang>을 바꾸지 않는 것
has("html lang becomes ko", "", '<html lang="ko" data-ko-lang="ko">')
# 이것을 실패시키는 것: 생성 표시 주석을 빼거나 doctype 앞에 두는 것
has("generated header follows the doctype", "", "<!DOCTYPE html>\n<!-- Generated from docs/t.html")
# 이것을 실패시키는 것: assets/ 경로를 그대로 두는 것(한국어 페이지에서 그림·아이콘이 깨진다)
has("assets/ src moves up a folder", '<img src="assets/a.png" alt="a">', '<img src="../assets/a.png" alt="a">')
has("assets/ href moves up a folder", '<link rel="icon" href="assets/f.png" />', 'href="../assets/f.png"')
# 이것을 실패시키는 것: assets/가 아닌 상대 경로까지 바꾸는 것(같은 폴더의 ko/manual.html로 가야 한다)
has("other relative links stay", '<a href="manual.html">M</a>', '<a href="manual.html">M</a>')
# 이것을 실패시키는 것: 통째로 바뀐 내용 안쪽 태그를 다시 고치는 것(위치가 어긋나 HTML이 깨진다)
has("tags inside replaced content are not edited",
    '<p class="install-note" data-en="x" data-ko="새 내용"><img src="assets/a.png"></p>\n<i>끝</i>',
    'data-ko="새 내용">새 내용</p>\n<i>끝</i>')
# 이것을 실패시키는 것: 바뀐 내용 안쪽의 data-ko 요소를 또 바꾸는 것(두 편집이 겹쳐 HTML이 깨진다)
has("data-ko inside replaced content is not applied twice",
    '<p class="install-note" data-en="x" data-ko="새"><span data-en="a" data-ko="가나다라마">a</span></p>\n<i>끝</i>',
    'data-ko="새">새</p>\n<i>끝</i>')
# 이것을 실패시키는 것: data-ko가 빠진 문자열을 통과시키는 것(한국어 페이지에 영어가 남는다)
rejects("data-en without data-ko fails", '<p data-en="Hi">Hi</p>')
# 이것을 실패시키는 것: 자식 요소를 품은 요소의 내용을 바꾸는 것(#215의 아이콘이 지워진 버그)
rejects("data-ko on an element with child elements fails", '<a data-en="Go" data-ko="가기"><svg></svg>Go</a>')

print(f"{'PASS' if failures == 0 else 'FAILED'} — build-ko")
sys.exit(1 if failures else 0)
