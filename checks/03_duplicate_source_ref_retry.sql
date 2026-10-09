-- id: duplicate_source_ref_retry
-- severity: warn
-- description: same source_ref loaded more than once with the same event_ts. Looks like a sender retry. Reports dedupe on source_ref.
SELECT source_ref, count(*) AS copies
FROM events
GROUP BY source_ref
HAVING count(*) > 1 AND count(DISTINCT event_ts) = 1;
