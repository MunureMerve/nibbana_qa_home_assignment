-- Member visits per branch in 2024.
--
-- Decisions (the evidence for each one is in DATA_QUALITY.md):
-- 1. event_type is compared in lower case. One entrance device sent CHECK_IN in capitals for a week
--    in April 2024.
-- 2. Duplicates are removed on source_ref, keeping the first row ingested. Re-sent copies have the wrong
--    event_ts, so source_ref is the only safe key.
-- 3. Events for member_ids that aren't in the members table are ignored. In this data those are two turnstile
--    test cards.
-- 4. A visit is a check_in where the member's next access event is a check_out at the same branch on the same
--    local day.
-- 5. A check_in with no matching check_out is not counted as a visit.
-- 6. Days and years use the branch's local time zone. A visit counts for 2024 when its check is in 2024
--    local time.
-- 7. Every branch is listed, with 0 if it had no visits.

WITH access_events AS (
    -- decisions 1, 2, and 3
    SELECT DISTINCT ON (e.source_ref)
           e.event_id,
           e.member_id,
           lower(e.event_type) AS event_type,
           e.event_ts,
           e.branch_id
    FROM events e
    JOIN members m ON m.member_id = e.member_id
    WHERE lower(e.event_type) IN ('check_in', 'check_out')
    ORDER BY e.source_ref, e.ingested_at, e.event_id
),

ordered AS (
    -- line up each member's events by time and look at the next one
    SELECT a.*,
           lead(a.event_type) OVER w AS next_type,
           lead(a.branch_id) OVER w AS next_branch,
           lead(a.event_ts) OVER w AS next_ts
    FROM access_events a 
    WINDOW w AS (PARTITION BY a.member_id ORDER BY a.event_ts, a.event_id)      
),

visits AS (
    -- decisions 4,5 and 6
    SELECT o.branch_id
    FROM ordered o
    JOIN branches b ON b.branch_id = o.branch_id
    WHERE o.event_type = 'check_in'
      AND o.next_type = 'check_out'
      AND o.next_branch = o.branch_id
      AND (o.next_ts AT TIME ZONE b.timezone)::date = (o.event_ts AT TIME ZONE b.timezone)::date
      AND extract(year FROM o.event_ts AT TIME ZONE b.timezone) = 2024
)

-- decision 7
SELECT b.branch_id,
       b.name AS branch_name,
       count(v.branch_id) AS member_visits
FROM branches b
LEFT JOIN visits v ON v.branch_id = b.branch_id
GROUP BY b.branch_id, b.name
ORDER BY b.branch_id;