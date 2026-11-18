USE saas_churn_analytics;

CREATE OR REPLACE VIEW vw_customer_churn_master AS
WITH sub_summary AS (
    SELECT 
        account_id,
        COUNT(subscription_id) AS total_subscriptions,
        SUM(CASE WHEN is_active_sub = 1 THEN mrr_amount ELSE 0 END) AS active_mrr,
        SUM(CASE WHEN is_active_sub = 1 THEN arr_amount ELSE 0 END) AS active_arr,
        SUM(mrr_amount) AS lifetime_mrr_booked,
        MAX(upgrade_flag) AS has_upgraded,
        MAX(downgrade_flag) AS has_downgraded,
        MAX(auto_renew_flag) AS has_auto_renew
    FROM subscriptions
    GROUP BY account_id
),
usage_summary AS (
    SELECT 
        s.account_id,
        COUNT(u.usage_id) AS total_usage_events,
        COALESCE(SUM(u.usage_count), 0) AS total_feature_clicks,
        ROUND(COALESCE(SUM(u.usage_duration_secs), 0) / 3600.0, 2) AS total_usage_hours,
        COALESCE(SUM(u.error_count), 0) AS total_usage_errors,
        COUNT(DISTINCT u.feature_name) AS distinct_features_used
    FROM subscriptions s
    LEFT JOIN feature_usage u ON s.subscription_id = u.subscription_id
    GROUP BY s.account_id
),
ticket_summary AS (
    SELECT 
        account_id,
        COUNT(ticket_id) AS total_tickets,
        ROUND(AVG(resolution_time_hours), 2) AS avg_resolution_hours,
        ROUND(AVG(satisfaction_score), 2) AS avg_csat_score
    FROM support_tickets
    GROUP BY account_id
),
churn_summary AS (
    SELECT 
        account_id,
        COUNT(churn_event_id) AS total_churn_events,
        MAX(churn_date) AS latest_churn_date,
        MAX(reason_code) AS primary_churn_reason,
        COALESCE(SUM(refund_amount_usd), 0) AS total_refunds_usd
    FROM churn_events
    GROUP BY account_id
)
SELECT 
    a.account_id,
    a.account_name,
    a.industry,
    a.country,
    a.signup_date,
    a.referral_source,
    a.plan_tier AS current_plan_tier,
    a.seats,
    a.is_trial,
    a.churn_flag,
    
    -- Subscription & Revenue Metrics
    COALESCE(sub.total_subscriptions, 0) AS total_subscriptions,
    COALESCE(sub.active_mrr, 0) AS active_mrr,
    COALESCE(sub.active_arr, 0) AS active_arr,
    COALESCE(sub.lifetime_mrr_booked, 0) AS lifetime_mrr_booked,
    COALESCE(sub.has_upgraded, 0) AS has_upgraded,
    COALESCE(sub.has_downgraded, 0) AS has_downgraded,
    COALESCE(sub.has_auto_renew, 0) AS has_auto_renew,
    
    -- Product Engagement Metrics
    COALESCE(usg.total_usage_events, 0) AS total_usage_events,
    COALESCE(usg.total_feature_clicks, 0) AS total_feature_clicks,
    COALESCE(usg.total_usage_hours, 0) AS total_usage_hours,
    COALESCE(usg.total_usage_errors, 0) AS total_usage_errors,
    COALESCE(usg.distinct_features_used, 0) AS distinct_features_used,
    
-- Customer Support Metrics
    COALESCE(tkt.total_tickets, 0) AS total_tickets,
    tkt.avg_resolution_hours,
    tkt.avg_csat_score,
    
    -- Churn & Refund Details
    COALESCE(chr.total_churn_events, 0) AS total_churn_events,
    chr.latest_churn_date,
    chr.primary_churn_reason,
    COALESCE(chr.total_refunds_usd, 0) AS total_refunds_usd
FROM accounts a
LEFT JOIN sub_summary sub ON a.account_id = sub.account_id
LEFT JOIN usage_summary usg ON a.account_id = usg.account_id
LEFT JOIN ticket_summary tkt ON a.account_id = tkt.account_id
LEFT JOIN churn_summary chr ON a.account_id = chr.account_id;

-- Verify the view returns 500 rows (1 per account) and inspect 5 sample rows
SELECT COUNT(*) AS total_accounts FROM vw_customer_churn_master;
SELECT * FROM vw_customer_churn_master LIMIT 5;