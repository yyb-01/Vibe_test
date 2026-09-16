# 프로젝트 작업 원칙

- 현재 작업 폴더가 분석·수정 대상이다. `.upload-repo/`는 별도 복사본이며 대상에 포함하지 않는다.
- 먼저 `docs/GITNEXUS_PROJECT_MAP.md`와 GitNexus repository context를 확인한다. 등록 이름은 `Vibe_test`이며 `list_repos`의 실제 경로가 현재 루트인지 확인한다.
- 수정 전에 관련 symbol context, 핵심 symbol의 callers/callees, 주요 execution flow와 관련 테스트를 확인한다. 여러 파일에 영향이 있는 변경은 upstream impact analysis를 먼저 수행한다.
- 인덱스가 stale이면 현재 루트에서 `node .gitnexus/run.cjs analyze`를 실행한다. 실행기가 없으면 `npx gitnexus analyze`를 사용한다.
- C++ 가상 호출·헤더 선언/정의·지역 변수 파싱에는 누락과 오탐이 있다. `UNKNOWN`, 빈 callers, 낮은 risk만으로 안전하다고 판단하지 않는다. 실제 소스와 모든 호출 위치를 대조한다. 문서의 계획과 구현을 구분한다.
- Ponytail 원칙: 기존 코드 재사용, YAGNI, 표준 라이브러리·플랫폼 우선, 최소 변경·관련 검증. 보안·입력 검증·데이터 보호와 명시적 요구를 생략하지 않는다. 코드 파일은 3000자 이하를 목표로 하되 정확성을 우선한다.
- production 기능 변경, commit, push는 해당 작업에서 사용자가 허용한 범위만 수행한다.

<!-- gitnexus:start -->
# GitNexus — Code Intelligence

This project is indexed by GitNexus as **Vibe_test** (1705 symbols, 5733 relationships, 71 execution flows).

> Index stale? Run `node .gitnexus/run.cjs analyze --index-only` from the project root — it auto-selects an available runner. No `.gitnexus/run.cjs` yet? Bootstrap with `npx`, `bunx`, or `pnpm dlx` — e.g. `bunx gitnexus@latest analyze` (npm 11 npx crash; #1939).

## Always Do

- **MUST run impact before editing.** Use `impact({target: "symbolName", direction: "upstream"})` or `node .gitnexus/run.cjs impact "symbolName" --direction upstream --repo .`; report callers, processes, and risk. Never substitute grep for graph analysis.
- **MUST analyze graph changes before committing.** Use `detect_changes({scope: "all"})` (MCP) or `node .gitnexus/run.cjs detect-changes --scope all --repo .` (CLI fallback). `partial: true` or `truncated: true` is not a clean check — a zero means unseen, not unaffected; re-run it. For regression review: `detect_changes({scope: "compare", base_ref: "main"})` or `node .gitnexus/run.cjs detect-changes --scope compare --base-ref "main" --repo .`.
- MUST warn on HIGH/CRITICAL `risk` pre-edit; never use `riskSharedAxes` to waive a HIGH/CRITICAL `risk` warning. Compare File/symbol: MCP File omits axes; Graph-RAG expands File.
- **MUST treat `risk: UNKNOWN` as unresolved, not as low.** An empty caller set is not evidence the symbol is unused — it can also mean the callers are not resolvable by the index (plain-object property access, dynamic dispatch, cross-language calls). `impact` pairs `UNKNOWN` with a `riskNote` saying so. Confirm with a text search before treating the symbol as safe to change or delete; do not proceed on the strength of a zero.
- **MUST use `query({search_query: "concept"})` for concepts/flows, `context({name: "symbolName"})` for a named symbol, or `impact` for blast radius, on read-only callers, dependencies, imports, or execution flow.** Graph first; text search only for empty/`UNKNOWN`/literals.
- For security review, `explain({target: "fileOrSymbol"})` lists taint findings (source→sink flows; needs `analyze --pdg`).

## Never Do

- NEVER edit a function, class, or method before MCP/CLI impact analysis.
- NEVER ignore HIGH or CRITICAL risk warnings from impact analysis, and never read `UNKNOWN` as an all-clear — it means the walk could not answer, which is the one verdict that requires confirming by other means.
- NEVER rename symbols with find-and-replace — use `rename` which understands the call graph.
- NEVER commit before MCP/CLI graph change analysis.

## Resources

| Resource | Use for |
| --- | --- |
| `gitnexus://repo/Vibe_test/context` | Codebase overview, check index freshness |
| `gitnexus://repo/Vibe_test/clusters` | All functional areas |
| `gitnexus://repo/Vibe_test/processes` | All execution flows |
| `gitnexus://repo/Vibe_test/process/{name}` | Step-by-step execution trace |

## CLI

| Task | Read this skill file |
| --- | --- |
| Understand architecture / "How does X work?" | `.claude/skills/gitnexus-exploring/SKILL.md` |
| Blast radius / "What breaks if I change X?" | `.claude/skills/gitnexus-impact-analysis/SKILL.md` |
| Trace bugs / "Why is X failing?" | `.claude/skills/gitnexus-debugging/SKILL.md` |
| Rename / extract / split / refactor | `.claude/skills/gitnexus-refactoring/SKILL.md` |
| Tools, resources, schema reference | `.claude/skills/gitnexus-guide/SKILL.md` |
| Index, status, clean, wiki CLI commands | `.claude/skills/gitnexus-cli/SKILL.md` |

<!-- gitnexus:end -->
