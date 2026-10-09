// Runs every SQL file in checks/ and prints a summary.
// Each check returns the rows that look wrong. No rows means the check passed.
// Exit code is 1 if any blocker check fails, 0 if there are only warnings.
// The connection comes from PGHOST, PGPORT, PGDATABASE, PGUSER and PGPASSWORD.

import { readdirSync, readFileSync } from "node:fs";
import { join } from "node:path";
import { fileURLToPath } from "node:url";
import pg from "pg";

type Severity = "blocker" | "warn";

interface Check {
  file: string;
  id: string;
  severity: Severity;
  description: string;
  sql: string;
}

const checksDir = fileURLToPath(new URL("../checks", import.meta.url));

function readHeader(sql: string, key: string): string | undefined {
  const match = sql.match(new RegExp(`^--\\s*${key}:\\s*(.+)$`, "m"));
  return match?.[1].trim();
}

function loadChecks(): Check[] {
  return readdirSync(checksDir)
    .filter((file) => file.endsWith(".sql"))
    .sort()
    .map((file) => {
      const sql = readFileSync(join(checksDir, file), "utf8");
      const severity = readHeader(sql, "severity");
      if (severity !== "blocker" && severity !== "warn") {
        throw new Error(`${file}: severity must be "blocker" or "warn"`);
      }
      return {
        file,
        id: readHeader(sql, "id") ?? file.replace(/\.sql$/, ""),
        severity,
        description: readHeader(sql, "description") ?? "",
        sql,
      };
    });
}

async function main(): Promise<void> {
  const client = new pg.Client();
  await client.connect();
  await client.query("SET default_transaction_read_only = on");

  let failedBlockers = 0;
  let warnings = 0;

  for (const check of loadChecks()) {
    let rows: Record<string, unknown>[];
    try {
      rows = (await client.query(check.sql)).rows;
    } catch (err) {
      console.log(`ERROR ${check.id}: ${(err as Error).message}`);
      failedBlockers++;
      continue;
    }

    let status = "PASS";
    if (rows.length > 0) {
      status = check.severity === "blocker" ? "FAIL" : "WARN";
    }
    if (status === "FAIL") failedBlockers++;
    if (status === "WARN") warnings++;

    console.log(`\n${status.padEnd(5)} [${check.severity}] ${check.id} (${rows.length} rows)`);
    console.log(`      ${check.description}`);
    if (rows.length > 0) console.table(rows.slice(0, 5));
  }

  await client.end();
  console.log(`\n${failedBlockers} blocker(s) failed, ${warnings} warning(s).`);
  process.exit(failedBlockers > 0 ? 1 : 0);
}

main().catch((err) => {
  console.error(err);
  process.exit(2);
});
