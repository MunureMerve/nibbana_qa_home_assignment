A project instruction file is how AI coding tools are used today. It also gives
reviewers proof that you set the rules up front. Commit it early.

  # Working agreement for AI assistants in this repo
  - This is a data-quality assignment. I (the engineer) own every business-rule
    interpretation, severity rating and root-cause conclusion. When you hit an
    ambiguity, STOP and give me options with trade-offs. Do not choose one silently.
  - Treat the tables branches, devices, members and events as read-only. Never write
    to them. Put helper objects in a separate schema (e.g. `qa`).
  - Back every claim about the data with the exact SQL you ran and its result.
    If you have not run it, label it "UNVERIFIED".
  - Report queries in reports/ must be one standalone Postgres 17 query, with no
    dependency on objects we create, and must run with psql -f in a read-only session.
  - The test suite must read its connection from PGHOST/PGPORT/PGDATABASE/PGUSER/
    PGPASSWORD and run with one command.
  - Do not git add, commit or push unless I ask.
  - Keep code simple and easy to read. A reviewer will judge it.