-- id: event_bad_reference
-- severity: blocker
-- description: event with no member_id, or an access event whose device is missing, unknown, at another branch, or the wrong kind.
SELECT e.event_id, e.event_type, e.member_id, e.branch_id, e.device_id,
       d.branch_id AS device_branch, d.kind AS device_kind
FROM events e
LEFT JOIN devices d ON d.device_id = e.device_id
WHERE e.member_id IS NULL
   OR (lower(e.event_type) IN ('check_in', 'check_out', 'friend_visit')
       AND (d.device_id IS NULL
            OR d.branch_id IS DISTINCT FROM e.branch_id
            OR NOT (   (lower(e.event_type) = 'check_in'     AND d.kind = 'entrance')
                    OR (lower(e.event_type) = 'check_out'    AND d.kind = 'exit')
                    OR (lower(e.event_type) = 'friend_visit' AND d.kind = 'front_desk'))));
