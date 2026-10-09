-- id: unknown_event_type
-- severity: blocker
-- description: event_type isn't a known type, even ignoring case. Reports would silently drop these rows.
SELECT event_type, count(*) AS events
FROM events
WHERE lower(event_type) NOT IN ('membership_started', 'membership_reactivated', 'membership_cancelled',
                                'tier_changed', 'check_in', 'check_out', 'friend_visit')
GROUP BY event_type;
