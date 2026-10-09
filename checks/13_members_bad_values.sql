-- id: members_bad_values
-- severity: warn
-- description: members.status or membership_tier is empty or not one of the expected lower case values.
SELECT member_id, status, membership_tier
FROM members
WHERE status IS NULL OR status NOT IN ('active', 'cancelled')
   OR membership_tier IS NULL OR membership_tier NOT IN ('basic', 'standard', 'premium');
