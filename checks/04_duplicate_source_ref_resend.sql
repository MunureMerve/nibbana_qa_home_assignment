-- id: duplicate_source_ref_resend
-- severity: blocker
-- description: same source_ref loaded again with a different event_ts. A bulk re-send rewrote the timestamps. Someone should look before reports go out.
SELECT max_ts::date AS resend_day, count(*) AS source_refs
FROM (
    SELECT source_ref, max(event_ts) AS max_ts
    FROM events
    GROUP BY source_ref
    HAVING count(DISTINCT event_ts) > 1
) d
GROUP BY 1
ORDER BY 1;
