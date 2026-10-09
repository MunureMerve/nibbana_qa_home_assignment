-- id: event_type_wrong_case
-- severity: warn
-- description: event_type is a known type but not in lower case. Our reports handle it, a simple filter would not.
SELECT event_type, device_id, count(*) AS events, min(event_ts) AS first_seen, max(event_ts) AS last_seen
FROM events
WHERE event_type <> lower(event_type)
GROUP BY event_type, device_id;
