-- id: unmatched_check_in_rate
-- severity: blocker
-- description: branch-months where more than 5% of check_ins have no check_out at the same branch on the same local day. Normal is 1-2%.
WITH access_events AS (
    SELECT DISTINCT ON (e.source_ref)
           e.event_id, e.member_id, lower(e.event_type) AS event_type, e.event_ts, e.branch_id
    FROM events e
    JOIN members m ON m.member_id = e.member_id
    WHERE lower(e.event_type) IN ('check_in', 'check_out')
    ORDER BY e.source_ref, e.ingested_at, e.event_id
),
ordered AS (
    SELECT a.*,
           lead(a.event_type) OVER w AS next_type,
           lead(a.branch_id)  OVER w AS next_branch,
           lead(a.event_ts)   OVER w AS next_ts
    FROM access_events a
    WINDOW w AS (PARTITION BY a.member_id ORDER BY a.event_ts, a.event_id)
),
per_month AS (
    SELECT o.branch_id,
           to_char(o.event_ts AT TIME ZONE b.timezone, 'YYYY-MM') AS month,
           count(*) AS check_ins,
           count(*) FILTER (WHERE NOT coalesce(
               o.next_type = 'check_out'
               AND o.next_branch = o.branch_id
               AND (o.next_ts AT TIME ZONE b.timezone)::date = (o.event_ts AT TIME ZONE b.timezone)::date,
               false)) AS unmatched
    FROM ordered o
    JOIN branches b ON b.branch_id = o.branch_id
    WHERE o.event_type = 'check_in'
    GROUP BY 1, 2
)
SELECT branch_id, month, check_ins, unmatched, round(100.0 * unmatched / check_ins, 1) AS pct
FROM per_month
WHERE unmatched > 0.05 * check_ins
ORDER BY branch_id, month;
