---
name: semantic-view-authoring
description: >
  dbt_semantic_view 패키지를 써서 Snowflake Semantic View를 dbt 모델로 작성하고
  리뷰합니다. 이 프로젝트의 sv_* 모델을 만들거나 수정하거나 리뷰할 때, 또는
  semantic view, metrics, dimensions, relationships, synonyms, verified queries가
  언급될 때 사용하세요. Snowflake CREATE SEMANTIC VIEW 문법, 이 패키지의
  materialization 규칙, 그리고 우리 팀의 메타데이터 기준을 담고 있습니다.
tools:
  - read
  - write
  - edit
  - snowflake_sql_execute
---

# 지침

Semantic View는 Snowflake에 최근 추가된 기능이고 `dbt_semantic_view` 패키지는 그보다
더 최신입니다. 다른 도구(LookML, dbt MetricFlow, Cube 등)에서 익힌 패턴을 그대로
가져오지 마세요. 아래 규칙을 그대로 따르세요.

semantic view 모델은 다음과 같이 materialize됩니다.

```
{{ config(materialized='semantic_view') }}
TABLES ( ... ) RELATIONSHIPS ( ... ) FACTS ( ... ) DIMENSIONS ( ... ) METRICS ( ... )
COMMENT = '...' AI_VERIFIED_QUERIES ( ... )
```

패키지가 본문을 `CREATE OR REPLACE SEMANTIC VIEW <relation> <body>`로 감쌉니다.
즉 relation 이름 뒤에 오는 부분을 전부 직접 작성하는 것입니다.

## 규칙 (순서대로)

1. **절 순서는 반드시 지켜야 합니다:** `TABLES`, `RELATIONSHIPS`, `FACTS`,
   `DIMENSIONS`, `METRICS`, `COMMENT`, 그다음 `AI_VERIFIED_QUERIES`. 순서가
   틀리면 Snowflake가 거부합니다 (FACTS는 DIMENSIONS보다 앞에 와야 하는 등).
2. **원본 테이블이 아니라 dbt 모델을 참조하세요.** 모든 논리 테이블은
   `alias AS {{ ref('model_name') }}` 형태입니다. 데이터베이스나 스키마를
   하드코딩하지 마세요.
3. **키와 관계를 선언하세요.** 논리 테이블마다 `PRIMARY KEY`를 주고, 모든 조인을
   `RELATIONSHIPS`에 `rel_name AS child (fk_col) REFERENCES parent (pk_col)`
   형태로 선언하세요.
4. **지표는 명시적으로 정의하세요. 컬럼 이름이 의미를 말해 준다고 가정하지
   마세요.** 그럴듯한 측정값이 여러 개 있다면(예: 헤더 합계 vs 라인에서 계산한
   순액), 지표 SQL이 어느 쪽이 공식 값인지 명시해야 합니다. 그리고 혼동을 부르는
   컬럼에는 그것이 지표가 **아니라는** COMMENT를 달아야 합니다.

## 팀 메타데이터 기준 (필수)

- **모든** 디멘션과 지표에 `WITH SYNONYMS = (...)`를 붙입니다.
- **모든** 지표, 그리고 혼동 가능한 fact에는 정확한 업무 정의를 적은 `COMMENT`를
  붙입니다.
- 뷰에는 분석 목적을 설명하는 최상위 `COMMENT`가 있어야 합니다.
- `AI_VERIFIED_QUERIES`를 최소 두 개 제공하고, 시작 질문으로 가장 좋은 것에
  `ONBOARDING_QUESTION TRUE`를 설정하세요. 그 `SQL`은 **한정하지 않은** 뷰 이름으로
  작성하세요 (예: `FROM SEMANTIC_VIEW(sv_sales_analytics ...)`). 그래야 같은 쿼리가
  DEV와 PROD에서 모두 유효합니다.
- 내부용 측정값은 `PRIVATE`로 표시하고, 조회 대상은 모두 `PUBLIC`입니다.

## 검증 절차 (항상 수행)

1. `dbt parse`로 Jinja/ref 오류를 잡습니다.
2. 뷰를 빌드합니다: `dbt run --select <sv_model> --target dev`
3. 실제 질문 하나를 뷰로 통과시켜 봅니다:
   `SELECT * FROM SEMANTIC_VIEW(<db>.<schema>.<sv> METRICS <m> DIMENSIONS <d>);`
4. `DESCRIBE SEMANTIC VIEW <db>.<schema>.<sv>;`로 동의어와 코멘트가 실제로
   반영됐는지 확인합니다.

# PR 리뷰 체크리스트 (개발자 및 CI)

각 항목을 확인하고 통과/실패를 판정하세요. 실패한 항목에는 file:line 참조와 구체적인
수정 방안을 함께 제시하세요.

1. 절 순서: TABLES, RELATIONSHIPS, FACTS, DIMENSIONS, METRICS, COMMENT,
   AI_VERIFIED_QUERIES.
2. 모든 논리 테이블에 PRIMARY KEY가 있고, 모든 조인이 RELATIONSHIPS에 선언돼 있다.
3. 논리 테이블이 `{{ ref(...) }}`로 dbt 모델을 참조한다 (데이터베이스/스키마
   하드코딩 없음).
4. 모든 디멘션과 지표에 `WITH SYNONYMS`가 있다.
5. 모든 지표(및 혼동 가능한 fact)에 정의 COMMENT가 있고, 뷰에 최상위 COMMENT가 있다.
6. AI_VERIFIED_QUERIES가 두 개 이상이고, **한정하지 않은** 뷰 이름으로 작성돼 있다.
7. 내부용 측정값이 PRIVATE으로 표시돼 있다.

출력: 모델 파일 이름을 제목으로 하는 간결한 마크다운. 통과 / 실패로 묶고, file:line
참조와 실패 항목별 구체적 수정 방안을 담습니다. 파일은 하나도 수정하지 마세요.

리뷰는 요청받은 언어로 작성하세요. 한국어로 요청받았다면 리뷰 내용과 섹션 제목을
한국어('통과' / '실패')로 쓰고, 영어로 요청받았다면 영어('Pass' / 'Fail')로 쓰세요.
어느 경우든 SQL 식별자, 절 이름(TABLES, FACTS, METRICS 등), 파일 경로는 원문 그대로
두세요.

# 권장 사항

- 분석 주제 영역 하나당 semantic view 하나. 작게, 선별해서 유지하세요.
- 한 뷰에 테이블을 여러 개 밀어 넣지 말고 깔끔한 스타 구조(fact + 디멘션)를
  택하세요.
- 지표 이름은 SQL(`sum_net_rev`)이 아니라 업무 개념(`total_revenue`)으로 지으세요.
- verified query를 모델 의도에 대한 회귀 테스트로 취급하세요.

# 자주 쓰는 패턴

## 패턴 1: "매출"의 중의성 제거

지표를 명시적으로 정의하고, 함정이 되는 컬럼에 코멘트를 답니다.

```
FACTS (
  orders.net_revenue AS orders.net_revenue
    COMMENT = '라인에서 계산한 순매출: extended_price * (1 - discount).',
  orders.order_total AS orders.order_total
    COMMENT = '헤더 금액. 세금 포함. 공식 매출 지표가 아니다.'
)
METRICS (
  orders.total_revenue AS SUM(orders.net_revenue)
    WITH SYNONYMS = ('매출', '총매출', '순매출', 'revenue', 'net revenue')
    COMMENT = '공식 매출: 라인에서 계산한 순매출의 SUM.'
)
```
