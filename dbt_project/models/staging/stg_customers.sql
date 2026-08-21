{{
    config(
        materialized='table'
    )
}}

-- 이 프로젝트에서 유일한 SQL 모델이다(나머지는 전부 Python/Snowpark).
-- 한 dbt 프로젝트 안에서 SQL 모델과 Python 모델이 같이 굴러간다는 걸 보여주려고 넣었다.
-- 알아보기 힘든 RAW 고객 마스터를 업무에서 쓰는 이름의 컬럼으로 정리하고,
-- GEO 룩업에서 국가와 지역을 붙인다.

with customers as (
    select
        c_k    as customer_id,
        c_nm   as customer_name,
        c_seg  as market_segment,
        c_nat  as nation_id,
        c_abal as account_balance,
        c_ph   as phone
    from {{ source('raw', 'C_MST') }}
),
geo as (
    select
        n_k  as nation_id,
        n_nm as nation,
        r_nm as region
    from {{ source('raw', 'GEO') }}
)
select
    c.customer_id,
    c.customer_name,
    c.market_segment,
    g.nation,
    g.region,
    c.account_balance,
    c.phone
from customers c
left join geo g
    on c.nation_id = g.nation_id
