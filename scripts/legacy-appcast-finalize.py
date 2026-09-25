#!/usr/bin/env python3
"""레거시 appcast 마무리: generate_appcast가 만든 피드의 모든 <item>에 OS 범위와 릴리스 노트 링크를 넣고 단언한다.

    legacy-appcast-finalize.py <appcast.xml> <owner/repo> <tag>

- minimumSystemVersion 10.13.0 / maximumSystemVersion 12.99.99: 앱의 피드 전환이 어떤 이유로 실패해도 13+에서는
  레거시 항목이 제안되지 않게 하는 두 번째 방어선이다(Sparkle은 범위 밖 항목을 거른다). 형식은 Sparkle 권장 세 자리.
- releaseNotesLink: 업데이트 창에 이 릴리스의 GitHub 페이지를 보여 준다(본판 release.yml과 같은 방식).
generate_appcast가 이미 넣은 범위·링크 요소는 줄째 지우고 다시 쓴다(값이 둘이 되지 않게, 두 번 돌려도 같은
바이트). 피드 자체는 서명하지 않으므로(SURequireSignedFeed 없음) 사후 편집이 서명을 깨지 않는다. DMG의 EdDSA
서명은 enclosure에 그대로 남는다.
"""

import re
import sys
import xml.etree.ElementTree as ET
from xml.sax.saxutils import escape

MINIMUM = "10.13.0"
MAXIMUM = "12.99.99"
SPARKLE = "{http://www.andymatuschak.org/xml-namespaces/sparkle}"
OWN_LINES = re.compile(
    r"^[ \t]*<sparkle:(minimumSystemVersion|maximumSystemVersion|releaseNotesLink)>[^<]*</sparkle:\1>[ \t]*\n",
    re.MULTILINE,
)


def finalize(text: str, notes_link: str) -> str:
    text = OWN_LINES.sub("", text)
    inserted = (
        f"<sparkle:minimumSystemVersion>{MINIMUM}</sparkle:minimumSystemVersion>\n"
        f"            <sparkle:maximumSystemVersion>{MAXIMUM}</sparkle:maximumSystemVersion>\n"
        f"            <sparkle:releaseNotesLink>{escape(notes_link)}</sparkle:releaseNotesLink>\n"
        "            <enclosure "
    )
    return text.replace("<enclosure ", inserted)


def verify(text: str, notes_link: str) -> int:
    items = list(ET.fromstring(text).iter("item"))
    if not items:
        sys.exit("appcast has no <item>")
    expectations = (
        ("minimumSystemVersion", MINIMUM),
        ("maximumSystemVersion", MAXIMUM),
        ("releaseNotesLink", notes_link),
    )
    for item in items:
        for tag, expected in expectations:
            values = [element.text for element in item.findall(SPARKLE + tag)]
            if values != [expected]:
                sys.exit(f"item {item.findtext('title')!r}: {tag} is {values}, expected [{expected!r}]")
        if item.find("enclosure") is None:
            sys.exit(f"item {item.findtext('title')!r} has no enclosure")
    return len(items)


def main() -> None:
    if len(sys.argv) != 4:
        sys.exit("usage: legacy-appcast-finalize.py <appcast.xml> <owner/repo> <tag>")
    path, repo, tag = sys.argv[1:]
    notes_link = f"https://github.com/{repo}/releases/tag/{tag}"
    with open(path, encoding="utf-8") as handle:
        text = finalize(handle.read(), notes_link)
    count = verify(text, notes_link)
    with open(path, "w", encoding="utf-8") as handle:
        handle.write(text)
    print(f"appcast finalized: {count} item(s), macOS {MINIMUM}–{MAXIMUM}")


if __name__ == "__main__":
    main()
