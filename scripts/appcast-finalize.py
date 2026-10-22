#!/usr/bin/env python3
"""본판 appcast 점검과 마무리. release.yml이 서명키 없이 부른다(키는 generate_appcast 스텝에만 있다).

    appcast-finalize.py seed <appcast.xml>
    appcast-finalize.py finalize <appcast.xml> <owner/repo> <tag>

피드는 최소 OS 갈래마다 항목 하나를 둔다(`generate_appcast --maximum-versions 1`). 2.0(macOS 14+)이 나간 뒤에도
macOS 13 사용자가 마지막 13 호환판까지는 업데이트를 받게 하려는 것이다. 이 스크립트는 그 피드가 맞는지 확인한다.

- seed: 직전 본판 피드(generate_appcast에 넘길 시드). 13 갈래 항목이 없으면 실패한다. 이 갈래가 빠진 시드로
  만들면 2.0 피드가 조용히 한 항목이 되어, 예전 1.7.x를 쓰는 macOS 13 사용자가 업데이트를 잃는다.
- finalize: 이번 태그의 항목에만 releaseNotesLink를 넣고(다른 항목은 바이트 그대로) 피드 전체를 단언한다.
  예전 방식은 "첫 항목에 링크가 없으면 넣기"라, 링크가 이미 있는 보존 항목이 앞에 오면 새 항목을 건너뛰었다.
"""

import re
import sys
import xml.etree.ElementTree as ET
from xml.sax.saxutils import escape

SPARKLE = "{http://www.andymatuschak.org/xml-namespaces/sparkle}"
# 계속 업데이트를 받아야 하는 최소 OS 갈래. macOS 13은 1.7.x 최종판에 머문다(2.0부터 14+).
REQUIRED_MINIMUMS = ("13.0",)
ITEM = re.compile(r"<item>.*?</item>", re.DOTALL)
NOTES_LINE = re.compile(r"^[ \t]*<sparkle:releaseNotesLink>[^<]*</sparkle:releaseNotesLink>[ \t]*\n", re.MULTILINE)


def version_key(text: str) -> tuple:
    return tuple(int(part) for part in text.split("."))


def items_of(text: str) -> list:
    try:
        return list(ET.fromstring(text).iter("item"))
    except ET.ParseError as error:
        sys.exit(f"appcast is not valid XML: {error}")


def describe(item) -> str:
    return repr(item.findtext("title"))


def check_items(items: list) -> None:
    """모든 항목: enclosure(url·length·서명), 빌드, 최소 OS. 최소 OS 갈래마다 하나, 필수 갈래 있음."""
    seen = {}
    for item in items:
        enclosure = item.find("enclosure")
        if enclosure is None:
            sys.exit(f"item {describe(item)} has no enclosure")
        for attribute in ("url", "length", SPARKLE + "edSignature"):
            if not enclosure.get(attribute):
                sys.exit(f"item {describe(item)} enclosure has no {attribute.replace(SPARKLE, 'sparkle:')}")
        if not item.findtext(SPARKLE + "version"):
            sys.exit(f"item {describe(item)} has no sparkle:version")
        minimum = item.findtext(SPARKLE + "minimumSystemVersion")
        if not minimum:
            sys.exit(f"item {describe(item)} has no sparkle:minimumSystemVersion")
        if minimum in seen:
            sys.exit(f"items {seen[minimum]} and {describe(item)} share minimumSystemVersion {minimum}")
        seen[minimum] = describe(item)
    for minimum in REQUIRED_MINIMUMS:
        if minimum not in seen:
            sys.exit(f"appcast has no item for macOS {minimum}; those users would stop getting updates")
    # Sparkle은 OS로 거른 뒤 가장 큰 빌드를 고른다. 더 낮은 OS 갈래가 더 큰 빌드를 가지면 새 OS 사용자에게도
    # 그 항목이 제시된다. 최소 OS가 높을수록 빌드도 커야 한다.
    ordered = sorted(items, key=lambda item: version_key(item.findtext(SPARKLE + "minimumSystemVersion")))
    builds = [int(item.findtext(SPARKLE + "version")) for item in ordered]
    if builds != sorted(builds) or len(set(builds)) != len(builds):
        sys.exit(f"builds must rise with minimumSystemVersion, got {builds}")


def finalize(text: str, repo: str, tag: str) -> str:
    """이번 태그 항목 하나에만 releaseNotesLink를 넣는다. 다른 항목은 바이트 그대로 둔다."""
    prefix = f"https://github.com/{repo}/releases/download/{tag}/"
    link = escape(f"https://github.com/{repo}/releases/tag/{tag}")
    matches = [match for match in ITEM.finditer(text) if f'url="{prefix}' in match.group(0)]
    if len(matches) != 1:
        sys.exit(f"expected exactly one item under {prefix}, found {len(matches)}")
    match = matches[0]
    block = NOTES_LINE.sub("", match.group(0)).replace(
        "<enclosure ", f"<sparkle:releaseNotesLink>{link}</sparkle:releaseNotesLink>\n            <enclosure ", 1
    )
    return text[: match.start()] + block + text[match.end() :]


def verify(text: str, repo: str, tag: str) -> str:
    items = items_of(text)
    check_items(items)
    prefix = f"https://github.com/{repo}/releases/download/{tag}/"
    current = [item for item in items if item.find("enclosure").get("url", "").startswith(prefix)]
    if len(current) != 1:
        sys.exit(f"expected exactly one item under {prefix}, found {len(current)}")
    current = current[0]
    expected_version = tag[1:] if tag.startswith("v") else tag
    if current.findtext(SPARKLE + "shortVersionString") != expected_version:
        sys.exit(f"item {describe(current)} shortVersionString is not {expected_version!r}")
    link = f"https://github.com/{repo}/releases/tag/{tag}"
    if [element.text for element in current.findall(SPARKLE + "releaseNotesLink")] != [link]:
        sys.exit(f"item {describe(current)} releaseNotesLink is not [{link!r}]")
    return ", ".join(
        f"{item.findtext('title')} (build {item.findtext(SPARKLE + 'version')}, "
        f"macOS {item.findtext(SPARKLE + 'minimumSystemVersion')}+)"
        for item in items
    )


def main() -> None:
    arguments = sys.argv[1:]
    if len(arguments) == 2 and arguments[0] == "seed":
        with open(arguments[1], encoding="utf-8") as handle:
            check_items(items_of(handle.read()))
        print(f"seed appcast ok: keeps macOS {', '.join(REQUIRED_MINIMUMS)}")
        return
    if len(arguments) == 4 and arguments[0] == "finalize":
        path, repo, tag = arguments[1:]
        with open(path, encoding="utf-8") as handle:
            text = finalize(handle.read(), repo, tag)
        summary = verify(text, repo, tag)
        with open(path, "w", encoding="utf-8") as handle:
            handle.write(text)
        print(f"appcast finalized: {summary}")
        return
    sys.exit("usage: appcast-finalize.py seed <appcast.xml> | finalize <appcast.xml> <owner/repo> <tag>")


if __name__ == "__main__":
    main()
