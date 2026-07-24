# AGENTS.md

AI 에이전트를 위한 프로젝트 룰북입니다.

## 절대 규칙

- 모든 응답은 한국어로 작성하고, 로그와 명령어 출력은 원문 그대로 유지한다.
- 코드 변경 전후의 맥락과 테스트 결과를 커밋 메시지 또는 PR 설명에 기록한다.

## 권장 규칙

- JSON 직렬화에는 Jbuilder 대신 Alba 시리얼라이저(`app/serializers/`)를 사용한다. 새로운 JSON 응답을 추가하거나 기존 Jbuilder 템플릿을 만나면 Alba Resource 클래스로 작성·변환한다.

## 도구 사용 규칙

- 라이브러리나 런타임 구조를 조사할 때는 가능한 경우 Rails MCP Server, Context7, Sequential Thinking 같은 제공 도구를 목적에 맞게 사용한다.
- 제공된 MCP 도구가 더 적합한 작업인데 무조건 파일 전체를 읽거나 비효율적인 방식만 고집하지 않는다.
- 최신 라이브러리 문서나 예제가 필요하면 Context7을 사용하고, `resolve-library-id` 후 `query-docs` 순서로 진행한다.
- 복잡한 문제를 단계적으로 풀어야 할 때는 Sequential Thinking을 사용한다.
- Ruby 코드의 정의 탐색, 참조 찾기, 심볼 검색 등에는 ruby-lsp를 적극 활용한다.

## graphify

This project has a knowledge graph at graphify-out/ with god nodes, community structure, and cross-file relationships.

When the user types `/graphify`, use the installed graphify skill or instructions before doing anything else.

Rules:
- For codebase questions, first run `graphify query "<question>"` when graphify-out/graph.json exists. Use `graphify path "<A>" "<B>"` for relationships and `graphify explain "<concept>"` for focused concepts. These return a scoped subgraph, usually much smaller than GRAPH_REPORT.md or raw grep output.
- Dirty graphify-out/ files are expected after hooks or incremental updates; dirty graph files are not a reason to skip graphify. Only skip graphify if the task is about stale or incorrect graph output, or the user explicitly says not to use it.
- If graphify-out/wiki/index.md exists, use it for broad navigation instead of raw source browsing.
- Read graphify-out/GRAPH_REPORT.md only for broad architecture review or when query/path/explain do not surface enough context.
- After modifying code, run `graphify update .` to keep the graph current (AST-only, no API cost).
