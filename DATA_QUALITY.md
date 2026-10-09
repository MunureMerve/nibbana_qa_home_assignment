# Data quality report

What I found in the FitTrack data, grouped by root cause. Every number here comes from a query I ran. Most of them are also checks in `checks/`, so they run again on every load.

The report `reports/visits_per_branch.sql` already handles every problem below. The "Impact" part says how far off the report would be if it didn't.

## In short

1. Mission Bay's entrance clock was 3 hours ahead for two months. Blocker.
2. Two bulk re-sends rewrote event timestamps. Blocker.
3. Small sender retries. Warning.
4. One entrance sent CHECK_IN in capitals for a week. Warning.
5. Two turnstile test cards in the data. Warning.
6. The members table is out of date. Warning.
7. Friend visit rules aren't enforced. Warning.
8. A normal 1-2% of check_ins have no check_out. Info.

---

## 1. Mission Bay entrance clock was 3 hours ahead

**What it is.** From June 6 to August 5, 2024, the Mission Bay entrance (D07-IN) stamped every check_in 
3 hours late. The exit was fine. 3 hours is the gap between Eastern and Pacific time, so my guess is the 
device was set to Eastern.

This one problem explains three things I found earlier:

- **check_ins after closing.** 172 check_ins between 11pm and 1am, all June to August. Really these were people coming in between 8pm and 10pm.
- **check_ins with no check_out.** Mission Bay had about 4%, the other branches 1-2%. A check_in stamped 3 hours late ends up after its own check_out, so they don't pair.
- **"Visits" lasting days.** 1,195 check_ins were followed by a check_out on a different day, 6 hours to 42 days later. Same reason.

**Evidence.**

```sql
SELECT device_id, count(*), min(event_ts - ingested_at), max(event_ts - ingested_at),
       min(ingested_at), max(ingested_at)
FROM events
WHERE ingested_at < event_ts
GROUP BY device_id;
```

1,542 rows, all D07-IN. event_ts is always 2h55m to 3h ahead of ingested_at, which can't happen for a real event. First one June 6 at opening, last one August 5 in the evening. Check `07_ingested_before_event`.

**Severity: blocker.** It quietly removes about a sixth of one branch's visits for two months.

**Impact.** Mission Bay drops from 9,624 to 8,143 visits if event_ts is used as is. The report uses 
`least(event_ts, ingested_at)`, which gets them back. ingested_at is only a few minutes after the real time.

**I got this wrong at first.** I thought both turnstiles were losing events and the visits couldn't be recovered. The `ingested_at < event_ts` check showed what was really going on.

---

## 2. Two bulk re-sends rewrote event_ts

**What it is.** On March 20 and October 20, 2024, something sent the last few days of access events again, with the send time as event_ts instead of the real time.

**Evidence.**

```sql
SELECT max_ts::date AS later_copy_day, count(*)
FROM (SELECT source_ref, max(event_ts) AS max_ts FROM events
      GROUP BY source_ref
      HAVING count(*) > 1 AND count(DISTINCT event_ts) > 1) d
GROUP BY 1;
```

3,036 source_refs have a later copy with a different event_ts (3,056 extra rows). All of the later copies are on March 20 (1,224) or October 20 (1,812).

- Every device at every branch.
- Mar 20 between 07:11 and 07:18 UTC, Oct 20 between 07:21 and 07:32 UTC. Middle of the night everywhere.
- The March batch copied Mar 17 to Mar 20, the October batch Oct 16 to Oct 20.
- D08 (Pearl District) is only in October, which makes sense since it opened in May.

Check `04_duplicate_source_ref_resend`.

**Severity: blocker.** It adds fake visits at 3am and puts real ones on the wrong day. Someone should know about it before reports go out.

**Impact.** check_in and check_out counts match per device, so whole visits got copied. That's up to about 584 extra visits on March 20 and 874 on October 20. The report dedupes on source_ref and keeps the first row that came in. source_ref is the only safe key, because the copies have a different event_ts.

**Likely cause.** A device or the ingest service retrying when it doesn't hear back.

---

## 3. Small sender retries

**What it is.** 700 source_refs show up twice with the same event_ts, a few seconds apart. Spread over the whole year.

**Evidence.** `03_duplicate_source_ref_retry`, 700 rows.

**Severity: warning.** The report dedupes these.

**Impact.** A duplicated check_in can break the pairing for that visit. I didn't measure this one separately, the same dedupe as #2 handles it.

**Likely cause.** A device or the ingest service retrying when it doesn't hear back.

---

## 4. CHECK_IN in capitals at Riverwalk for a week.

**What it is.** From Monday April 8 to Sunday April 14, 2024, the Riverwalk entrance (D04-IN) sent `CHECK_IN` instead of `check_in`. 181 rows. Only that device, only that week. No lowercase check_ins from it that week.

**Evidence.**

```sql
SELECT (event_ts AT TIME ZONE 'America/Chicago')::date, event_type, count(*)
FROM events
WHERE device_id = 'D04-IN' AND event_ts BETWEEN '2024-04-05' AND '2024-04-19'
GROUP BY 1, 2 ORDER BY 1, 2;
```

The daily counts that week (18 to 35) look like the weeks around it, so nothing is missing, it's just labelled differently. Check `02_event_type_wrong_case`.

**Severity: warning.** The report compares event_type in lower case. But a simple filter on `'check_in'` would lose the whole week.

**Impact.** Riverwalk short by 181 visits if matched exactly.

**Likely cause.** A firmware or config change on that device, rolled back after a week.

---

## 5. Turnstile test cards

**What it is.** 828 events belong to member_ids that aren't in the members table. Only two ids: 990001 and 990002.

- Only check_ins and check_outs, no membership events.
- 990001 goes to branches 1-4, 990002 to branches 5-8.
- About 54 visits per branch, so once a week. Pearl District has 35, which fits since it opened in May.
- Always right at opening, about a minute each.

**This also explained another finding.** I first found 60 check_ins followed by a check_out at a different branch a few seconds or minutes later. 58 of those were these test cards. Without them, only 2 are left.

**Evidence.** `05_member_not_in_members`, 2 member_ids, 828 events.

**Severity: warning.** The report leaves them out.

**Impact.** 414 extra visits if counted, about 54 per branch.

**Likely cause.** Maintenance testing the turnstiles every week.

The report doesn't hardcode these ids. It ignores any member_id that isn't in the members table, so it still works on a different database.

---

## 6. members table out of date

**What it is.** The README says membership state comes from events. When I compared:

- 34 members are `active` in members, but their last event is a cancellation.
- 15 are `cancelled` but started or reactivated after that.
- 2 are `active` but have no membership events at all.
- 5 have status `Active` with a capital A.

Also, `joined_on` is the UTC date of membership_started. For 241 members that's one day after their local start date. In UTC, no event is ever before joined_on.

**Evidence.** `12_members_status_vs_events` (51 rows), `13_members_bad_values` (5 rows), `14_event_before_join_date` (passes in UTC).

**Severity: warning.**

**Impact.** None on visits_per_branch. Anything counting active members from `members.status` would be off by about 50.

**Likely cause.** The CRM writes events but doesn't always update the members table.

---

## 7. Friend visit rules

**What it is.**

- 55 of 6,875 friend_visits have no check_in by the member at that branch that day. The README says a friend can only come in with the member.
- 71 member-months went over the friend limit (basic 41, standard 20, premium 10). Worst cases: 5 in a month on basic (limit 2), 11 on premium (limit 8).

**Evidence.** `10_friend_visit_without_check_in` (55), `11_friend_visits_over_allowance` (71).

**Severity: warning.** The over-limit data is probably right. The front desk just isn't enforcing the limit, so this is more about the process than the data.

**Impact.** None on visits_per_branch.

---

## 8. Normal missing check_outs

After all of the above is handled, every branch still has about 1-2% of check_ins with no check_out after them. Probably normal stuff, like people tailgating or a card not reading.

**Decision.** These aren't counted as visits, because the README says a visit ends with a check_out at the same branch. So the report is a little low everywhere, by about the same amount at each branch.

Check `08_unmatched_check_in_rate` fails if a branch goes over 5% in a month. Before the clock fix, Mission Bay was at 81% in June and 99% in July.

---

## Questions for the teams

**Access-control team**
- Was D07-IN at Mission Bay set to Eastern time from June 6 to August 5? What changed on those days?
- What changed on D04-IN on April 8, and why was it rolled back a week later?
- What ran on March 20 and October 20 around 07:15 UTC? Why did it use the send time as event_ts?
- Are 990001 and 990002 test cards? Is there a list of test or staff cards we should always leave out?
- Is there a known reason for the 1-2% missing check_outs, like a side exit?

**CRM team**
- How does the members table get updated from events? Why do about 50 members not match their latest event?
- Is joined_on meant to be a UTC date or the branch's local date?
- Why do 2 active members have no membership events?
- If a tier changes in the middle of a month, which tier sets that month's friend limit?

**Front desk**
- Are friend limits checked at the desk? 71 member-months went over.
 
## What I'd watch from now on

The checks in `checks/` run on every load. On top of that I'd keep an eye on:

- **event_ts later than ingested_at**, per device. Even one row means a device clock is wrong.
- **Daily events per device**, compared with the same weekday in past weeks. A big jump means a re-send, a big drop means a device is down.
- **check_ins with no check_out**, per branch per day. Normal is 1-2%.
- **Duplicate source_refs per load.** A few retries are fine, thousands in one day are not.
**New event_type spellings and unknown member_ids.**
- **members table vs latest membership event.** This number should go down over time.

