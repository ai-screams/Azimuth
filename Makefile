lint:
	./scripts/lint.sh

format:
	./scripts/format.sh

build:
	./scripts/build.sh

# 권한이 필요한 실행/테스트는 반드시 `make run`을 쓴다.
# `make build`는 CODE_SIGNING_ALLOWED=NO(ad-hoc) → cdhash 불안정 → TCC 권한 꼬임.
# `make run`은 Apple Development로 정상 서명해 권한이 유지된다(정공법).
run:
	./scripts/run.sh

test:
	./scripts/test.sh

# 배포본(DMG) 생성: Developer ID 서명 + 공증 + DMG. 자격/사용법은 RELEASING.md 참조.
release:
	./scripts/release.sh

secrets:
	./scripts/secret-scan.sh

install-hooks:
	./scripts/install-hooks.sh
