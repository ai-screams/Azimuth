# CI/CD

Azimuth의 지속적 통합·배포 구성 전체 개요. 워크플로 정의는 `.github/workflows/`, 릴리스 절차 상세는
[`RELEASING.md`](../RELEASING.md), 커버리지 정책은 [`Tests/AGENTS.md`](../Tests/AGENTS.md) 참조.

## 원칙
- **로컬 = CI 동치**: 모든 CI 검사는 `make` 타깃·git 훅으로 로컬에서도 동일하게 돌릴 수 있다. 머지 전 로컬 green이면 CI도 green.
- **검증된 것만 main/사용자에게**: 포맷·린트·빌드·테스트·커버리지·시크릿·SAST를 통과해야 머지, 서명·공증·검증을 통과해야 릴리스.
- **공급망 최소 신뢰**: 모든 GitHub Action은 commit SHA로 핀, 권한은 잡별 최소, 릴리스 secret은 승인 환경에 격리.

## 워크플로

### 1. `ci.yml` — 통합 검사 (push: main, 모든 PR)
러너 `macos-15`. concurrency로 PR의 stale 실행은 취소(main은 유지).

| 잡 | 단계 |
|---|---|
| **secret-scan** | gitleaks 전체 히스토리 스캔(`gitleaks git`, fetch-depth 0) → SARIF를 Code Scanning에 업로드 → 누출 시 실패 |
| **lint-and-build** | Select Xcode(latest-stable) → SwiftFormat `--lint` → SwiftLint `--strict` → `xcodebuild ... CODE_SIGNING_ALLOWED=NO build` → **`make coverage`**(테스트 실행 + 순수 로직 라인 ≥ 90% 게이트) |

> CI 빌드는 ad-hoc(`CODE_SIGNING_ALLOWED=NO`) — 컴파일 검증용. 권한(AX) 동작은 CI에서 검증 불가(로컬 `make run` 서명 빌드).

### 2. `codeql.yml` — 정적 분석 SAST (push: main, 주간 cron)
러너 `macos-15`. CodeQL **Swift** 분석: init → `xcodebuild build`(컴파일 언어라 빌드 관찰 필요) → analyze. 결과는 **Security → Code scanning** 탭. 권한 `security-events: write`(최소).

### 3. `release.yml` — 릴리스 (태그 `v*` 푸시)
러너 `macos-15`, **`environment: release`(승인 게이트)**, concurrency(진행 중 릴리스 비취소).

흐름: Developer ID 인증서 임포트 → `scripts/release.sh`(빌드·서명·공증·DMG) → **DMG 자가검증**(`codesign --verify`, `spctl -a -t open`, `stapler validate`) → **SHA-256 체크섬 생성** → **Sparkle appcast 서명·생성**(EdDSA 개인키로 DMG 서명 + `appcast.xml`) → GitHub Release 생성(DMG + `.sha256` + `appcast.xml` 첨부, 노트 자동 생성).

> 자동 업데이트: 앱은 Sparkle로 `releases/latest/download/appcast.xml`(고정 URL)을 확인해 새 버전을 설치한다. Apple 공증 + Sparkle EdDSA 서명 2중 검증. 키/설정 상세는 [`RELEASING.md`](../RELEASING.md#auto-update-sparkle).

활성화·secret·환경 설정은 [`RELEASING.md`](../RELEASING.md) 참조.

## 품질·보안 방어 레이어

| 차원 | 커밋 전(로컬 훅) | PR/푸시(CI) | 릴리스 | 상시 |
|---|---|---|---|---|
| 시크릿 | gitleaks(staged) | gitleaks(전체 히스토리)+SARIF | — | Gitleaks GitHub App, (선택)GitHub native secret scanning |
| 포맷/린트 | SwiftFormat+SwiftLint | SwiftFormat+SwiftLint(strict) | — | — |
| 빌드 | — | xcodebuild | release.sh archive | — |
| 테스트 | — | `make coverage`(테스트 실행) | — | — |
| 커버리지 | (`make coverage` 수동) | **≥ 90% 게이트** | — | — |
| 코드 취약점 | — | — | — | **CodeQL(주간+PR)** |
| 서명/공증 | — | — | **자가검증+staple** | — |
| 무결성 | — | — | **SHA-256 체크섬** | — |

## 로컬 대응(make / git hook)
- `make lint` · `make build` · `make test` · `make coverage` — CI와 동일 검사.
- `make secrets`(= `scripts/secret-scan.sh`) — gitleaks 디렉터리 스캔.
- pre-commit 훅(`.githooks/pre-commit`, `make install-hooks`로 활성): **gitleaks(staged) → SwiftFormat → SwiftLint**.

## 공급망·유지보수
- **모든 액션 SHA 핀**(태그 변조 방지). 버전 주석(`# v7` 등)은 **Dependabot**(`.github/dependabot.yml`, github-actions, 주간)이 SHA와 함께 갱신.
- 러너 `macos-15` 고정(재현성). Xcode는 `setup-xcode`로 latest-stable.

## 활성화에 필요한 저장소 설정 (코드 아님 — 관리자 수행)
1. **브랜치 보호**(Settings → Branches → `main`): 직접 푸시 금지, PR 필수, 필수 상태 체크(`lint-and-build`, `secret-scan`) 통과 강제, (선택)리뷰 1+·linear history. (CodeQL은 PR이 아닌 main 머지 후·주간 실행이라 PR 필수 체크에 넣지 않는다.)
2. **`release` 환경**(Settings → Environments): required reviewer + 환경 scoped secret 6개(`DEVELOPER_ID_CERT_P12`, `DEVELOPER_ID_CERT_PASSWORD`, `APPLE_TEAM_ID`, `APPLE_ID`, `APPLE_APP_PASSWORD`, `SPARKLE_ED_PRIVATE_KEY`).
3. (선택) **Tags 보호**(`v*`), **GitHub native Secret scanning + Push protection** 토글.

## 릴리스 방법
```
git tag vX.Y.Z && git push origin vX.Y.Z
```
→ `release` 환경 승인 후 빌드·서명·공증·검증·체크섬·Release 발행. 앱 버전은 태그에서 주입(`release.sh`).
완전 자동 시맨틱 버저닝(release-please 등)은 현재 미도입(수동 태그). 자세한 정책 결정은 내부 백로그 참조.
