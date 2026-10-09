-- id: access_event_outside_opening_hours
-- severity: warn
-- description: access event (after dedupe, known members only) outside the branch's local opening hours.
WITH access_events AS (
    SELECT DISTINCT ON (e.source_ref) e.*
    FROM events e
    JOIN members m ON m.member_id = e.member_id
    WHERE lower(e.event_type) IN ('check_in', 'check_out', 'friend_visit')
    ORDER BY e.source_ref, e.ingested_at, e.event_id
)
SELECT a.branch_id, lower(a.event_type) AS event_type,
       to_char(a.event_ts AT TIME ZONE b.timezone, 'YYYY-MM') AS month, count(*) AS events
FROM access_events a
JOIN branches b ON b.branch_id = a.branch_id
WHERE (a.event_ts AT TIME ZONE b.timezone)::time < b.opens_at
   OR (a.event_ts AT TIME ZONE b.timezone)::time > b.closes_at
GROUP BY 1, 2, 3
ORDER BY 1, 2, 3;
