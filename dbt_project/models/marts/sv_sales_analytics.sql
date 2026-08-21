{{ config(materialized='semantic_view') }}

-- 주문 단위 fact와 고객 디멘션 위에 올린 semantic view.
-- 컬럼 이름을 깔끔하게 정리하는 것만으로는 AI 에이전트에게 전달되지 않는 것들,
-- 즉 매출의 공식 정의, 올바른 조인, 업무에서 쓰는 동의어, 검증된 예시 쿼리를
-- 채워 주는 계층이다. total_revenue는 라인에서 계산한 순매출로 정의했다.
-- 세금이 포함된 헤더 값인 order_total이 아니다.

TABLES (
    orders AS {{ ref('mart_order_sales') }}
        PRIMARY KEY (order_id)
        WITH SYNONYMS = ('매출', '주문 매출', '거래', 'sales', 'order sales', 'transactions')
        COMMENT = '주문 단위 매출 fact (주문 하나당 한 행).',
    customers AS {{ ref('stg_customers') }}
        PRIMARY KEY (customer_id)
        WITH SYNONYMS = ('고객', '거래처', '계정', 'accounts', 'clients', 'buyers')
        COMMENT = '세그먼트, 국가, 지역 정보를 담은 고객 디멘션.'
)

RELATIONSHIPS (
    orders_to_customers AS
        orders (customer_id) REFERENCES customers (customer_id)
)

FACTS (
    orders.net_revenue AS orders.net_revenue
        WITH SYNONYMS = ('순매출액', 'net sales amount')
        COMMENT = '라인에서 계산한 순매출: extended_price * (1 - discount).',
    orders.order_total AS orders.order_total
        COMMENT = 'TPC-H 헤더 금액. 세금이 포함되어 있다. 공식 매출 지표가 아니다.',
    orders.gross_revenue AS orders.gross_revenue
        COMMENT = '할인 적용 전 extended price.'
)

DIMENSIONS (
    orders.order_date AS orders.order_date
        WITH SYNONYMS = ('주문일', '주문 날짜', '구매일', '거래일', 'order day', 'purchase date', 'transaction date')
        COMMENT = '주문이 발생한 날짜.',
    orders.order_status AS orders.order_status
        WITH SYNONYMS = ('상태', '주문 상태', 'status')
        COMMENT = '주문 상태 코드: F는 확정(fulfilled), O는 미결(open), P는 처리 중(in progress). total_revenue는 F만 집계하므로 매출을 해석할 때 이 코드가 기준이 된다.',
    orders.order_priority AS orders.order_priority
        WITH SYNONYMS = ('우선순위', '주문 우선순위', 'priority'),
    customers.market_segment AS customers.market_segment
        WITH SYNONYMS = ('세그먼트', '마켓 세그먼트', '고객 세그먼트', '시장', 'segment', 'customer segment', 'market')
        COMMENT = '고객의 마켓 세그먼트 (예: AUTOMOBILE, BUILDING).',
    customers.region AS customers.region
        WITH SYNONYMS = ('지역', '권역', '영업 지역', 'sales region', 'geo region', 'geography'),
    customers.nation AS customers.nation
        WITH SYNONYMS = ('국가', '나라', '국가명', 'country', 'nation name')
)

METRICS (
    orders.total_revenue AS SUM(CASE WHEN orders.order_status = 'F' THEN orders.net_revenue ELSE 0 END)
        WITH SYNONYMS = ('매출', '총매출', '순매출', '매출액', '총 순매출', 'revenue', 'net revenue', 'total sales', 'total net revenue')
        COMMENT = '공식 매출 정의: 확정된 주문(order_status = F)에 대해 라인에서 계산한 순매출(할인 반영, 세금 제외). 이 기준은 mart 컬럼만 봐서는 알 수 없다.',
    orders.order_count AS COUNT(orders.order_id)
        WITH SYNONYMS = ('주문 수', '주문 건수', '주문량', 'number of orders', 'order volume', 'count of orders')
        COMMENT = '주문 건수. total_revenue와 달리 order_status로 걸러내지 않고 모든 상태의 주문을 센다.',
    orders.avg_order_value AS SUM(orders.net_revenue) / NULLIF(COUNT(orders.order_id), 0)
        WITH SYNONYMS = ('평균 주문 금액', '건당 평균 매출', 'AOV', 'average order value', 'average basket size')
        COMMENT = '주문 한 건당 평균 순매출. 분자는 모든 상태의 net_revenue이므로 total_revenue / order_count와 값이 다르다.',
    orders.units_sold AS SUM(orders.total_quantity)
        WITH SYNONYMS = ('판매 수량', '판매량', '총 수량', 'units', 'quantity sold', 'total quantity')
        COMMENT = '주문에 포함된 라인 수량의 합. 금액이 아니라 개수 기준이다.'
)

COMMENT = '매출 분석 semantic model: 세그먼트, 지역, 기간별 순매출과 주문량, 평균 주문 금액.'

AI_VERIFIED_QUERIES (
    revenue_by_segment AS (
        QUESTION '마켓 세그먼트별 총 순매출이 어떻게 되나요?'
        ONBOARDING_QUESTION TRUE
        SQL 'SELECT * FROM SEMANTIC_VIEW(sv_sales_analytics METRICS total_revenue DIMENSIONS market_segment)'
    ),
    revenue_by_region_year AS (
        QUESTION '지역별, 주문 연도별 순매출을 보여주세요'
        ONBOARDING_QUESTION TRUE
        SQL 'SELECT region, YEAR(order_date) AS order_year, total_revenue FROM SEMANTIC_VIEW(sv_sales_analytics METRICS total_revenue DIMENSIONS region, order_date) ORDER BY region, order_year'
    )
)
