# How I used AI

## Tools

- **Claude chat.** Most of the work. I used it to plant the plan the exploration, draft SQL, talk through what the results meant, and draft the written files.
- **Claude Code in VS Code.** At the start, to write a prompt plan for each step and the rules in `CLAUDE.md`. I kept the prompt plan out of the repo.

`ai_log.txt` has the running log I kept while working. This file is a summary of it. 

## What was mine and what was the AI's

To be straight about it: the AI wrote most of the SQL, the test runner, and first drafts of the written files. I wrote some of the SQL myself (the join date check and the clock fix in checks 08 to 10), and typed the report query out by hand from the AI's draft so I understood every line. I made the decisions, ran and checked everything, and caught the AI's mistakes along the way. The sections below show which was which.

**Mine**
- The decision that a check_in with no check_out is not a visit, because a visit ends with a check_out.
- Wanting to check each check_in for its own check_out, instead of comparing totals. That's what showed the 892 gap was hiding two separate problems.
- The check for events before `joined_on`. I wrote it first as a Jest test, then moved it into the `checks/` format.
- Choosing TypeScript for the test suite.
- Updating checks 08, 09 and 10 myself to use the same clock fix as the report.
- Typing the report query out by hand from the AI draft, so I understood every part.
- Keeping notes as I went. Some started as AI drafts that I rewrote in my own words.

**The AI's, and I agreed**
- Breaking the CHECK_IN problem down by device and then by day.
- Leaving out member_ids that aren't in the members table, instead of hardcoding the two test card ids. I agreed because the report has to run on a different database.
- The same-day rule for pairing a check_in with its check_out.
- Using `least(event_ts, ingested_at)` to fix the Mission Bay clock, because it doesn't name a device or a 3 hour offset.
- A small runner instead of Jest, so a check can warn without failing the build.
- The severities and the 5% threshold for check 08. I kept them as proposed.

## Where I rejected or corrected the AI

- **Wrong column name.** The AI's first duplicate query called a column `extra_rows`, but it was counting source_refs, not rows. Those aren't the same when some refs have 3 or more copies. I caught it and we fixed the query.
- **Fractional seconds.** The AI guessed that timestamps with fractional seconds were the re-sent rows. Counting them per day showed they appear every day, so I dropped that and looked at the spike days instead. That's how the two bulk re-sends showed up.
- **The Mission Bay clock.** The AI first suggested a clock problem for the late check_ins at Mission Bay, then dropped the idea with bad reasoning. It only thought about the clock being behind, not ahead. Later, when I ran the test suite, the `ingested_at < event_ts` check failed and showed the entrance was 3 hours ahead all summer. So the first idea was right, and for a while my notes said the visits couldn't be recoreved when they could.
- **Join date check.** The AI changed my events-before-join check to use the branch's local date. That flagged 241 members. Comparing in UTC gave 0, because `joined_on` is stored as a UTC date. I switched it back to UTC, which is what my first version did.
- **My own notes.** I caught number and id mistakes as I went (DO4 instead of D04, 74,904 instead of 74,094).

## How I checked the AI's SQL

- **Same number two ways.** Rows removed by dedupe came to 3,756 by two different queries. The pairing query gave 72,305 check_ins, the same as the dedupe count.
- **Expectations first.** Before running the report I rewrite down what I expected (Pearl District lowest, total around 70,000), then checked it against the result.
- **What each rule removes.** I broke the report down by which rule dropped each check_in, per branch. Every branch lost about 2%, except Mission Bay at 17%. That's what led to the clock problem.
- **Test suite against my findings.** The first time I ran the suite, I compared every result with what I had already found by hand. They all matched, except check 07, which found something new.
- **Before and after.** After the clock fix, the other seven branches didn't change at all, and Mission Bay went from 8,143 to 9,624 visits, about 98% of its check_ins like everyone else.