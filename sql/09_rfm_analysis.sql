USE thelook_ecommerce_ads;

-- TheLook Ecommerce Analytics - RFM Analysis RFM 
-- Purpose : Segment customers by recency, frequency, and monetary value for CRM actions.
-- Business value : Identify champions, loyal users, high-value at-risk users, and dormant users.

-- 1. Segment distribution 
SELECT
    rfm_segment,
    COUNT(*) AS customer_count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) AS customer_share_pct,
    ROUND(AVG(recency_days), 1) AS avg_recency_days,
    ROUND(AVG(frequency), 2) AS avg_order_frequency,
    ROUND(AVG(monetary), 2) AS avg_monetary_value,
    ROUND(SUM(monetary), 2) AS segment_revenue
FROM ads_rfm_segments
GROUP BY rfm_segment
ORDER BY segment_revenue DESC;

-- 2. RFM score matrix RFM 
SELECT
    r_score,
    f_score,
    m_score,
    COUNT(*) AS customer_count,
    ROUND(AVG(monetary), 2) AS avg_revenue,
    ROUND(AVG(recency_days), 1) AS avg_recency_days
FROM ads_rfm_segments
GROUP BY r_score, f_score, m_score
ORDER BY r_score DESC, f_score DESC, m_score DESC;

-- 3. High-value at-risk customers 
SELECT
    customer_id,
    recency_days,
    frequency,
    monetary,
    rfm_score,
    rfm_segment
FROM ads_rfm_segments
WHERE rfm_segment LIKE 'At Risk High Value%'
ORDER BY monetary DESC, recency_days DESC
LIMIT 100;

-- 4. CRM action mapping CRM 
SELECT
    rfm_segment,
    COUNT(*) AS customers,
    CASE
        WHEN rfm_segment LIKE 'Champions%' THEN 'Reward, early access, referral program '
        WHEN rfm_segment LIKE 'Loyal%' THEN 'Cross-sell and bundle offers'
        WHEN rfm_segment LIKE 'New%' THEN 'Onboarding and second-purchase coupon'
        WHEN rfm_segment LIKE 'At Risk%' THEN 'Win-back campaign and service check'
        WHEN rfm_segment LIKE 'Hibernating%' THEN 'Low-cost reactivation or suppress'
        ELSE 'Routine lifecycle campaign'
    END AS recommended_action
FROM ads_rfm_segments
GROUP BY rfm_segment
ORDER BY customers DESC;
