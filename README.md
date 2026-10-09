# FitTrack data quality

My work on the FitTrack Senior QA Engineer (Data Quality) assignment. The original brief is in `ASSIGNMENT.md`.


## What's here

- `checks/` the data quality checks. One SQL file per check, each returns the rows that look wrong.
- `src/run-checks.ts` runs every check and prints a summary.
- `reports/visits_per_branch.sql` the required report. The decisions behind it are in the comments at the top.
- `DATA_QUALITY.md` what I found, with evidence, severity, impact and likely cause.
- `AI_USAGE.md` how I used AI tools on this.
- `notes.txt` and `ai_log.txt` my working notes, in the order I went.

## Setup

You need Docker and Node 18 or newer.

```bash
docker compose up -d --wait
npm install
```

## Running the test suite

The suite reads the connection from the standard Postgres variables, so it works against any database with
the same schema:

```bash
PGHOST=localhost PGPORT=5432 PGDATABASE=fittrack PGUSER=fittrack PGPASSWORD=fittrack npm test
```

Each check is either a `blocker` or a `warn`:

- **PASS** no rows came back.
- **WARN** a `warn` check found rows. Worth a look, but reports can still go out.
- **FAIL** a `blocker` check found rows. Reports should not go out until someone looks.

The exit code is `1` if any blocker fails and `0` otherwise, so it can gate a CI job.
The session is read only, so the checks can't change any data.

On the current data, 2 blockers fail: the two bulk re-sends (check 04) and the Mission Bay entrance clock (check 07).

## Adding a check

Add a new `.sql` file to `checks/` that returns the rows that break the rule. Start it with:

```sql
-- id: short_name
-- severity: blocker or warn
-- description: one line on what it catches
```

Nothing else needs to change. The runner picks up every file in the folder.

## Running the report

```bash
psql -f reports/visits_per_branch.sql
```

with the same `PG*` variables set. Or, without psql installed:

```bash
docker compose exec -T db psql -U fittrack -d fittrack < reports/visits_per_branch.sql
```

## Time spent
About 6 hours of actual work, spread over three evenings with breaks in between.
More than the suggested 3-5 hours, mostly because I spent time tracking the Mission Bay problem down to the real cause.
