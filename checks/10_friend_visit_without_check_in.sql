-- id: friend_visit_without_check_in
-- severity: warn
-- description: friend_visit with no check_in by the member at the same branch on the same local day. A friend can only come in with the member.
WITH ev AS (
    SELECT DISTINCT ON (e.source_ref)
           e.event_id, e.member_id, lower(e.event_type) AS event_type, e.branch_id,
           (e.event_ts AT TIME ZONE b.timezone)::date AS local_day
    FROM events e
    JOIN branches b ON b.branch_id = e.branch_id
    WHERE lower(e.event_type) IN ('check_in', 'friend_visit')
    ORDER BY e.source_ref, e.ingested_at, e.event_id
)
SELECT f.event_id, f.member_id, f.branch_id, f.local_day
FROM ev f
WHERE f.event_type = 'friend_visit'
  AND NOT EXISTS (
      SELECT 1 FROM ev c
      WHERE c.event_type = 'check_in'
        AND c.member_id = f.member_id
        AND c.branch_id = f.branch_id
        AND c.local_day = f.local_day);
