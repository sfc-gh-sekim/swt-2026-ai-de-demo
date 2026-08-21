# AGENTS.md - DE214 데모 프로젝트

이 dbt 프로젝트에서 작업하는 AI 코딩 에이전트(Cortex Code)를 위한 안내서입니다. 이
파일의 목적은 **재현성**입니다. 사람이든 에이전트든, 누가 하더라도 매번 같은 결과가
나와야 합니다.

## 이 프로젝트는 무엇인가

난독화된 TPC-H 원본 데이터를 깔끔한 분석 계층으로 변환하고, AI 에이전트와 BI 도구가
쓸 수 있도록 Snowflake **Semantic View**까지 만들어 두는 Snowflake상의 dbt
프로젝트입니다.

## 환경과 연결

- 로컬 Python 환경: conda 환경 `de214`, 경로는 `/opt/homebrew/Caskroom/miniconda/base/envs/de214/bin`.
- Snowflake 연결: **`default`**. `-c` 플래그는 붙이지 않습니다.
- `profiles.yml`, `~/.dbt/profiles.yml`, `connections.toml`은 **절대** 읽거나 출력하지 마세요. 비밀 정보가 들어 있을 수 있습니다.

## 데이터베이스와 스키마 구성

`DE214_DEMO` 데이터베이스 아래에 스키마 세 개가 있습니다.

- `RAW`  - 난독화된 원본 테이블 (`scripts/00_setup_sources.sql`로 적재).
- `DEV`  - 로컬에서 반복 개발할 때 쓰는 dbt 대상.
- `PROD` - CI/CD 배포 대상.

모든 모델은 대상 스키마(`DEV` 또는 `PROD`)에 그대로 빌드됩니다. 데이터 영역 구분은
스키마가 아니라 **오브젝트 이름 접두어**로 합니다.

## 이름 규칙 (데이터 영역)

- `stg_*`  - staging: 원본 하나를 정리하고 이름만 바꿉니다. 비즈니스 로직은 넣지 않습니다.
- `mart_*` - mart: 비즈니스 단위의 fact와 집계.
- `sv_*`   - Snowflake Semantic View (`dbt_semantic_view`로 생성).

## 모델링 규칙

- **Python 모델은 Snowpark DataFrame을 선언형으로 씁니다.** DataFrame을 만들어서
  반환하세요. 행 단위 루프를 돌리거나 커서로 직접 SQL을 실행하지 않습니다.
- Python 모델은 `table` 또는 `incremental`만 가능합니다(`view`는 안 됩니다). SQL
  모델인 `stg_customers`는 `view`입니다.
- incremental 모델인 `mart_order_sales`는 다음 쿼리로 새 파티션을 걸러냅니다.
  `session.sql(f"select max(order_date) as max_date from {dbt.this}")`. incremental
  로직을 바꾼 뒤에는 `--full-refresh`를 쓰세요.
- 지표, 조인, 동의어는 mart가 아니라 `sv_*` 모델에 둡니다. `sv_*` 관련 작업은
  `semantic-view-authoring` 스킬을 쓰세요.

## 최초 1회 셋업

```bash
BIN=/opt/homebrew/Caskroom/miniconda/base/envs/de214/bin

# TPC-H에서 난독화된 RAW 원본 테이블 생성
$BIN/snow sql -f scripts/00_setup_sources.sql

# dbt 패키지 번들 (배포본에 함께 포함됨. 로컬에서도 필요)
cd dbt_project && $BIN/dbt deps --profiles-dir .
```

## 실행 방법

**로컬** (개발 기본값. 배포를 거치지 않아서 빠릅니다):

```bash
BIN=/opt/homebrew/Caskroom/miniconda/base/envs/de214/bin
cd dbt_project
$BIN/dbt run --target dev
$BIN/dbt test --target dev
# 모델 하나만 돌릴 때:
$BIN/dbt run --select <model> --target dev
```

`DBT_PROFILES_DIR=$HOME/.dbt`가 필요합니다. `~/.dbt/profiles.yml`은
`dbt_project/profiles.local.example.yml`을 보고 처음에 한 번 만들어 두세요.

**네이티브 / CI** (dbt 프로젝트 오브젝트를 Snowflake에 배포. PROD에 올릴 때, 그리고
배포 파이프라인 전체를 확인할 때 필요합니다):

```bash
BIN=/opt/homebrew/Caskroom/miniconda/base/envs/de214/bin
cd dbt_project
$BIN/snow dbt deploy DE214_DEMO --source . --database DE214_DEMO --schema DEV
$BIN/snow dbt execute --dbt-version "1.10.15" --database DE214_DEMO --schema DEV DE214_DEMO run --target dev
$BIN/snow dbt execute --dbt-version "1.10.15" --database DE214_DEMO --schema DEV DE214_DEMO test --target dev
```

## 반드시 지킬 것

- dbt를 실행하거나 배포해 달라는 요청을 받으면 **위에 적힌 dbt 방식대로** 하세요.
  모델이 할 일을 SQL로 즉석에서 대신 써서 흉내 내는 건 안 됩니다.
- 변경 사항은 dbt를 직접 호출해서 로컬에서 확인하세요(`dbt parse` 후 `dbt run` /
  `dbt test --target dev`). 배포된 오브젝트는 CI나 prod에서 `snow dbt execute`로
  확인합니다.
- 배포는 Snowflake CLI나 반복 실행 가능한 스크립트로만 합니다. Cortex Code는 *개발과
  리뷰*에 쓰는 도구이고, 데이터를 직접 바꾸는 데 쓰지 않습니다.
- `dbt_project/profiles.yml`에 `authenticator`, `password`, `{{ env_var(...) }}`를
  넣지 마세요. 서버 쪽에서 실패합니다.
