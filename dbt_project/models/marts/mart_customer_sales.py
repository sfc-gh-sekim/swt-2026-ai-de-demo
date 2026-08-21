def model(dbt, session):
    """고객 단위 매출 mart (Snowpark).

    주문 단위 매출을 고객당 한 행으로 집계하고, 고객의 세그먼트·국가·지역 정보를
    붙인다. 주문 단위로 먼저 집계하는 이유는, 고객 -> 주문 -> 라인 순으로
    조인하면 행이 불어나면서 매출이 중복 집계되는 흔한 함정을 피하기 위해서다.
    """
    dbt.config(materialized="table")

    from snowflake.snowpark import functions as F

    order_sales = dbt.ref("mart_order_sales")
    customers = dbt.ref("stg_customers")

    by_customer = order_sales.group_by("customer_id").agg(
        F.sum(F.col("net_revenue")).alias("net_revenue"),
        F.sum(F.col("order_total")).alias("order_total"),
        F.count_distinct(F.col("order_id")).alias("order_count"),
        F.sum(F.col("total_quantity")).alias("total_quantity"),
        F.max(F.col("order_date")).alias("most_recent_order_date"),
    )

    return by_customer.join(customers, on="customer_id", how="left").select(
        F.col("customer_id"),
        F.col("customer_name"),
        F.col("market_segment"),
        F.col("nation"),
        F.col("region"),
        F.col("net_revenue"),
        F.col("order_total"),
        F.col("order_count"),
        F.col("total_quantity"),
        F.col("most_recent_order_date"),
    )
