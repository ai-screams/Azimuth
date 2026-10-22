#!/usr/bin/env python3
"""`appcast-finalize.py`를 고정 피드로 검사한다(네트워크·서명키 없음). CI release-scripts가 부른다.

fixture는 Sparkle 2.10.0 generate_appcast가 실제로 만든 피드다(시드 = v1.7.7 피드, 새 아카이브 = 최소 OS 14인
가짜 2.0.0, 서명은 버린 임시 키). seed-1.7.7.xml은 v1.7.7 릴리스에 붙은 피드 그대로다.
"""

import importlib.util
import pathlib
import sys

sys.dont_write_bytecode = True  # 불러오는 스크립트의 __pycache__를 레포에 남기지 않는다
HERE = pathlib.Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location("appcast_finalize", HERE / "appcast-finalize.py")
appcast = importlib.util.module_from_spec(spec)
spec.loader.exec_module(appcast)

REPO = "ai-screams/Azimuth"
GENERATED = (HERE / "appcast-fixtures/generated-2.0.0.xml").read_text(encoding="utf-8")
SEED = (HERE / "appcast-fixtures/seed-1.7.7.xml").read_text(encoding="utf-8")
LINK_200 = (
    "<sparkle:releaseNotesLink>https://github.com/ai-screams/Azimuth/releases/tag/v2.0.0</sparkle:releaseNotesLink>"
)
failures = 0


def report(ok: bool, label: str, detail: str = "") -> None:
    global failures
    print(f"{'ok  ' if ok else 'FAIL'} {label}{'' if ok else ' — ' + detail}")
    failures += 0 if ok else 1


def fails(label: str, action) -> None:
    """action이 SystemExit(메시지)로 멈추면 통과."""
    try:
        action()
    except SystemExit as stop:
        report(isinstance(stop.code, str), label, f"exit {stop.code!r}")
        return
    report(False, label, "did not fail")


def item_block(text: str, title: str) -> str:
    return next(match.group(0) for match in appcast.ITEM.finditer(text) if f"<title>{title}</title>" in match.group(0))


# 정상 경로: 이번 태그 항목에만 링크, 보존 항목은 바이트 그대로, 두 번 돌려도 같음.
final = appcast.finalize(GENERATED, REPO, "v2.0.0")
report(LINK_200 in item_block(final, "2.0.0"), "link lands on the v2.0.0 item")
report(item_block(final, "1.7.7") == item_block(GENERATED, "1.7.7"), "kept 1.7.7 item is byte-identical")
report(appcast.finalize(final, REPO, "v2.0.0") == final, "finalize twice gives the same bytes")
summary = appcast.verify(final, REPO, "v2.0.0")
both = "2.0.0 (build 300, macOS 14.0+)" in summary and "1.7.7 (build 235, macOS 13.0+)" in summary
report(both, "verify lists both items")
appcast.check_items(appcast.items_of(SEED))
report(True, "v1.7.7 feed is a valid seed")

# 시드와 피드 단언: 하나라도 어기면 멈춘다.
fails("seed without a macOS 13 item", lambda: appcast.check_items(appcast.items_of(GENERATED.replace(
    item_block(GENERATED, "1.7.7"), ""))))
fails("item without an EdDSA signature", lambda: appcast.verify(
    appcast.finalize(GENERATED.replace(' sparkle:edSignature="buI8', ' data-x="buI8'), REPO, "v2.0.0"), REPO, "v2.0.0"))
fails("item without a length", lambda: appcast.check_items(appcast.items_of(
    GENERATED.replace(' length="7500000"', ""))))
fails("item without sparkle:version", lambda: appcast.check_items(appcast.items_of(
    GENERATED.replace("<sparkle:version>300</sparkle:version>", ""))))
fails("item without minimumSystemVersion", lambda: appcast.check_items(appcast.items_of(
    GENERATED.replace("<sparkle:minimumSystemVersion>14.0</sparkle:minimumSystemVersion>", ""))))
# 같은 갈래(14.0)에 두 항목. 빌드는 오름차순이라 빌드 순서 검사로는 걸리지 않는다.
# 이것을 실패시키는 것: 최소 OS 갈래마다 하나라는 검사를 빼는 것.
SECOND_200 = item_block(GENERATED, "2.0.0").replace("<sparkle:version>300<", "<sparkle:version>301<")
fails("two items share a minimum OS", lambda: appcast.check_items(appcast.items_of(GENERATED.replace(
    item_block(GENERATED, "2.0.0"), item_block(GENERATED, "2.0.0") + "\n        " + SECOND_200))))
fails("older OS branch has the higher build", lambda: appcast.check_items(appcast.items_of(
    GENERATED.replace("<sparkle:version>235</sparkle:version>", "<sparkle:version>400</sparkle:version>"))))
fails("no item for the tag", lambda: appcast.finalize(GENERATED, REPO, "v2.0.1"))
fails("tag and shortVersionString disagree", lambda: appcast.verify(appcast.finalize(
    GENERATED.replace("<sparkle:shortVersionString>2.0.0<", "<sparkle:shortVersionString>2.0.1<"), REPO, "v2.0.0"),
    REPO, "v2.0.0"))
fails("not XML", lambda: appcast.items_of("<rss><channel>"))
fails("item without an enclosure", lambda: appcast.check_items(appcast.items_of(
    GENERATED.replace(next(line for line in GENERATED.splitlines() if "v2.0.0/Azimuth" in line), ""))))
fails("no items at all", lambda: appcast.check_items(appcast.items_of(
    '<rss xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle"><channel></channel></rss>')))
# verify만 따로 부를 때도 이번 항목의 링크·개수를 본다(finalize를 거치지 않은 피드).
fails("verify without the release-notes link", lambda: appcast.verify(GENERATED, REPO, "v2.0.0"))
fails("verify with no item for the tag", lambda: appcast.verify(final, REPO, "v2.0.1"))

if failures:
    sys.exit(f"{failures} check(s) failed")
print("appcast-finalize: all checks passed")
