-- id: ingested_before_event
-- severity: blocker
-- description: row landed in the database before the event happened. The sender's timestamps can't be trusted.
SELECT event_id, source_ref, event_ts, ingested_at
FROM events
WHERE ingested_at < event_ts;
