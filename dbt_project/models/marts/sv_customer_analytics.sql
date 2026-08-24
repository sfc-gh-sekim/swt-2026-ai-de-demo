{{ config(materialized='semantic_view') }}

-- Semantic view at customer grain over mart_customer_sales.
-- Answers: top customers by revenue, revenue and customer counts by
-- market segment, nation, and region. net_revenue is the official metric;
-- order_total (header, includes tax) is exposed as a fact but NOT the metric.

TABLES (
    customers AS {{ ref('mart_customer_sales') }}
        PRIMARY KEY (customer_id)
        WITH SYNONYMS = ('고객', '거래처', '계정', 'accounts', 'clients', 'buyers', 'customer sales')
        COMMENT = 'Customer-grain fact: one row per customer with rolled-up revenue, order counts, and geo enrichment.'
)

FACTS (
    customers.net_revenue AS customers.net_revenue
        WITH SYNONYMS = ('순매출액', 'net sales amount')
        COMMENT = 'Line-derived net revenue for this customer: SUM of extended_price * (1 - discount) across all orders. This is the official revenue measure.',
    customers.order_total AS customers.order_total
        COMMENT = 'Sum of TPC-H header order_total for this customer; includes tax. NOT the official revenue metric.',
    customers.order_count AS customers.order_count
        COMMENT = 'Number of distinct orders placed by this customer.',
    customers.total_quantity AS customers.total_quantity
        COMMENT = 'Total line-item quantity ordered by this customer.'
)

DIMENSIONS (
    customers.customer_name AS customers.customer_name
        WITH SYNONYMS = ('고객명', '거래처명', '계정명', 'customer', 'account name', 'client name', 'buyer name')
        COMMENT = '고객 이름. TPC-H 생성값이라 Customer#000012345 형태이며, 사람이 읽는 상호명이 아니다.',
    customers.market_segment AS customers.market_segment
        WITH SYNONYMS = ('세그먼트', '마켓 세그먼트', '고객 세그먼트', '시장', '산업', 'segment', 'customer segment', 'market', 'industry')
        COMMENT = 'Customer market segment (e.g. AUTOMOBILE, BUILDING, FURNITURE).',
    customers.nation AS customers.nation
        WITH SYNONYMS = ('국가', '나라', '국가명', '고객 국가', 'country', 'nation name', 'customer country')
        COMMENT = '고객이 속한 국가. region 안에 중첩된 값이므로 단독 집계 시 region과 함께 보는 것이 안전하다.',
    customers.region AS customers.region
        WITH SYNONYMS = ('지역', '권역', '영업 지역', '고객 지역', 'sales region', 'geo region', 'geography', 'customer region')
        COMMENT = '고객이 속한 대륙 단위 권역 (예: ASIA, EUROPE). nation의 상위 레벨이다.',
    customers.most_recent_order_date AS customers.most_recent_order_date
        WITH SYNONYMS = ('최근 주문일', '마지막 주문일', '최종 구매일', 'last order date', 'latest order', 'most recent purchase')
        COMMENT = 'Date of the most recent order placed by this customer.'
)

METRICS (
    customers.total_revenue AS SUM(customers.net_revenue)
        WITH SYNONYMS = ('매출', '총매출', '순매출', '매출액', '고객 매출', 'revenue', 'net revenue', 'total sales', 'total net revenue', 'customer revenue')
        COMMENT = 'Official revenue: SUM of line-derived net revenue (net of discount, excludes tax) across all customers in the group.',
    customers.customer_count AS COUNT(customers.customer_id)
        WITH SYNONYMS = ('고객 수', '고객 수량', '거래처 수', 'number of customers', 'count of customers', 'customer volume', 'headcount')
        COMMENT = '고객 수. 뷰가 고객 단위이므로 행 수와 같다. 주문한 적 없는 고객은 mart_customer_sales에 없어 집계에서 빠진다.',
    customers.avg_revenue_per_customer AS SUM(customers.net_revenue) / NULLIF(COUNT(customers.customer_id), 0)
        WITH SYNONYMS = ('고객당 평균 매출', '평균 고객 매출', 'ARPC', 'average customer revenue', 'revenue per customer')
        COMMENT = 'Average net revenue per customer: total_revenue / customer_count.'
)

COMMENT = 'Customer analytics semantic view: net revenue, customer counts and average revenue by segment, nation, and region at customer grain.'

AI_VERIFIED_QUERIES (
    top_customers_by_revenue AS (
        QUESTION 'Who are the top 10 customers by revenue?'
        ONBOARDING_QUESTION TRUE
        SQL 'SELECT customer_name, total_revenue FROM SEMANTIC_VIEW(sv_customer_analytics METRICS total_revenue DIMENSIONS customer_name) ORDER BY total_revenue DESC LIMIT 10'
    ),
    revenue_and_customers_by_segment AS (
        QUESTION 'What is total revenue and customer count by market segment?'
        ONBOARDING_QUESTION TRUE
        SQL 'SELECT * FROM SEMANTIC_VIEW(sv_customer_analytics METRICS total_revenue, customer_count DIMENSIONS market_segment) ORDER BY total_revenue DESC'
    ),
    revenue_by_nation_and_region AS (
        QUESTION 'Show total revenue and customer count by nation and region'
        SQL 'SELECT * FROM SEMANTIC_VIEW(sv_customer_analytics METRICS total_revenue, customer_count DIMENSIONS nation, region) ORDER BY region, total_revenue DESC'
    )
)
