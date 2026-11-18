USE saas_churn_analytics;

-- 1. Overall Headline KPIs (Total Customers, Churn Rate %, Total Active MRR, Revenue Lost to Churn)
SELECT 
    COUNT(*) AS total_customers,
    SUM(churn_flag) AS churned_customers,
    ROUND(SUM(churn_flag) * 100.0 / COUNT(*), 2) AS churn_rate_pct,
    SUM(active_mrr) AS total_active_mrr,
    SUM(CASE WHEN churn_flag = 1 THEN lifetime_mrr_booked ELSE 0 END) AS churned_historical_mrr
FROM vw_customer_churn_master;

-- 2. Churn Rate & Active MRR by Plan Tier (Which plan is bleeding customers?)
SELECT 
    current_plan_tier,
    COUNT(*) AS total_accounts,
    SUM(churn_flag) AS churned_accounts,
    ROUND(SUM(churn_flag) * 100.0 / COUNT(*), 2) AS churn_rate_pct,
    ROUND(AVG(active_mrr), 2) AS avg_active_mrr
FROM vw_customer_churn_master
GROUP BY current_plan_tier
ORDER BY churn_rate_pct DESC;

-- 3. Engagement & Support Behavior: Churned vs. Retained Customers
SELECT 
    CASE WHEN churn_flag = 1 THEN 'Churned' ELSE 'Active / Retained' END AS customer_status,
    COUNT(*) AS accounts,
    ROUND(AVG(total_usage_hours), 2) AS avg_usage_hours,
    ROUND(AVG(distinct_features_used), 2) AS avg_features_used,
    ROUND(AVG(total_tickets), 2) AS avg_support_tickets,
    ROUND(AVG(avg_csat_score), 2) AS avg_csat_score
FROM vw_customer_churn_master
GROUP BY churn_flag;

-- 4. Top Churn Reasons & Refund Impact
SELECT 
    COALESCE(primary_churn_reason, 'No Reason Logged') AS churn_reason,
    COUNT(*) AS churned_accounts,
    SUM(total_refunds_usd) AS total_refunds_usd
FROM vw_customer_churn_master
WHERE churn_flag = 1
GROUP BY primary_churn_reason
ORDER BY churned_accounts DESC;

-- 5. Monthly Churn Trend (Tracking cancellations & refunds over time)
SELECT 
    DATE_FORMAT(churn_date, '%Y-%m') AS churn_month,
    COUNT(churn_event_id) AS churn_events,
    ROUND(SUM(refund_amount_usd), 2) AS monthly_refunds_usd
FROM churn_events
GROUP BY churn_month
ORDER BY churn_month;

-- 6. Proactive Churn Risk Segmentation for Currently Active Customers (390 accounts)
SELECT 
    CASE 
        WHEN has_auto_renew = 0 AND (avg_csat_score < 3.5 OR total_usage_errors >= 5) THEN 'Critical Risk'
        WHEN has_auto_renew = 0 OR avg_csat_score < 3.5 THEN 'Moderate Risk'
        ELSE 'Healthy / Low Risk'
    END AS risk_segment,
    COUNT(*) AS active_accounts,
    SUM(active_mrr) AS mrr_at_risk
FROM vw_customer_churn_master
WHERE churn_flag = 0
GROUP BY risk_segment
ORDER BY mrr_at_risk DESC;

-- 7. Signup Cohort Retention (Performance by Signup Quarter)
SELECT 
    CONCAT(YEAR(signup_date), '-Q', QUARTER(signup_date)) AS signup_cohort,
    COUNT(*) AS cohort_size,
    SUM(churn_flag) AS churned_count,
    ROUND(SUM(churn_flag) * 100.0 / COUNT(*), 2) AS cohort_churn_rate_pct,
    ROUND(AVG(lifetime_mrr_booked), 2) AS avg_ltv_mrr
FROM vw_customer_churn_master
GROUP BY signup_cohort
ORDER BY signup_cohort;

-- 8. Window Function: Top 3 Highest-MRR Active Accounts At Risk per Plan Tier
WITH ranked_risk AS (
    SELECT 
        account_id,
        account_name,
        current_plan_tier,
        active_mrr,
        total_tickets,
        avg_csat_score,
        DENSE_RANK() OVER (
            PARTITION BY current_plan_tier 
            ORDER BY active_mrr DESC
        ) AS mrr_rank_in_tier
    FROM vw_customer_churn_master
    WHERE churn_flag = 0 
      AND has_auto_renew = 0
)
SELECT *
FROM ranked_risk
WHERE mrr_rank_in_tier <= 3;