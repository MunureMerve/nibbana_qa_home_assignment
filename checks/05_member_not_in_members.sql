-- id: member_not_in_members
-- severity: warn
-- description: events for a member_id that isn't in the members table. In this data these are turnstile test cards. Reports leave them out.
SELECT e.member_id, count(*) AS events
FROM events e
WHERE e.member_id IS NOT NULL
  AND NOT EXISTS (SELECT 1 FROM members m WHERE m.member_id = e.member_id)
GROUP BY e.member_id;
