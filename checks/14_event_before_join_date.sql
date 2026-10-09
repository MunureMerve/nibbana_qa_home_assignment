-- id: event_before_join_date
-- severity: warn
-- description: event dated before the member's joined_on. Compared in UTC, because joined_on is stored as UTC date.
SELECT lower(e.event_type) AS event_type, count(*) AS events, count(DISTINCT e.member_id) AS members
FROM events e
JOIN members m ON m.member_id = e.member_id
WHERE (e.event_ts AT TIME ZONE coalesce('UTC'))::date < m.joined_on
GROUP BY 1
ORDER BY 1;
