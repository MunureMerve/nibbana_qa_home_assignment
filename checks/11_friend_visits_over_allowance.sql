-- id: friend_visits_over_allowance
-- severity: warn
-- description: member brought more friends in a month than their tier allows (basic 2, standard 3, premium 8). The data is probably right, the limit just isn't enforced.
WITH friend_visits AS (
    SELECT DISTINCT ON (e.source_ref)
           e.member_id,
           b.timezone,
           date_trunc('month', e.event_ts AT TIME ZONE b.timezone) AS month_start
    FROM events e
    JOIN branches b ON b.branch_id = e.branch_id
    JOIN members m ON m.member_id = e.member_id
    WHERE lower(e.event_type) = 'friend_visit'
    ORDER BY e.source_ref, e.ingested_at, e.event_id
),
per_month AS (
    SELECT member_id, month_start, min(timezone) AS timezone, count(*) AS friends
    FROM friend_visits
    GROUP BY member_id, month_start
),
tier_events AS (
    SELECT member_id, event_ts, coalesce(details->>'tier', details->>'to') AS tier
    FROM events
    WHERE lower(event_type) IN ('membership_started', 'membership_reactivated', 'tier_changed')
),
with_tier AS (
    SELECT p.*,
           (SELECT t.tier
            FROM tier_events t
            WHERE t.member_id = p.member_id
              AND t.event_ts < (p.month_start + interval '1 month') AT TIME ZONE p.timezone
            ORDER BY t.event_ts DESC
            LIMIT 1) AS tier
    FROM per_month p
)
SELECT member_id, to_char(month_start, 'YYYY-MM') AS month, tier, friends
FROM with_tier
WHERE friends > CASE tier WHEN 'basic' THEN 2 WHEN 'standard' THEN 3 WHEN 'premium' THEN 8 END
ORDER BY month, member_id;
