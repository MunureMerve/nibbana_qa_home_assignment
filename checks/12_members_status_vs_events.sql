-- id: members_status_vs_events
-- severity: warn
-- description: members.status disagrees with the member's latest membership event. The README says events are the source of truth.
WITH latest AS (
    SELECT DISTINCT ON (member_id) member_id, lower(event_type) AS last_event
    FROM events
    WHERE lower(event_type) IN ('membership_started', 'membership_reactivated', 'membership_cancelled')
    ORDER BY member_id, event_ts DESC, event_id DESC
)
SELECT m.member_id, m.status, l.last_event
FROM members m
LEFT JOIN latest l ON l.member_id = m.member_id
WHERE l.member_id IS NULL
   OR (lower(m.status) = 'cancelled') <> (l.last_event = 'membership_cancelled');
