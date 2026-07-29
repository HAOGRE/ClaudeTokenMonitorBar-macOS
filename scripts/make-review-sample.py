#!/usr/bin/env python3
"""Generate a sample ~/.claude/projects folder to hand to App Review.

The reviewer's Mac has no Claude Code, so the app's panel would be empty.
Ship the output of this script with the submission and tell the reviewer to
point the "Grant Access" panel at it.

JSONL shape mirrors ClaudeMonitorTests/TokenDataReaderTests.swift, which is the
known-good format the parser is tested against.

    python3 scripts/make-review-sample.py [out_dir]

Prints the totals the app should display, so you can verify end to end.
"""
import json
import random
import sys
from datetime import datetime, timedelta, timezone
from pathlib import Path

# Must match pricingConfigs in Backend/TokenDataReader.swift.
# (input, output, cache_creation, cache_read) in $/MTok
PRICING = {
    "claude-opus-5": (5.0, 25.0, 6.25, 0.5),
    "claude-sonnet-5": (2.0, 10.0, 2.5, 0.2),  # intro pricing, before 2026-09-01
    "claude-haiku-4-5": (1.0, 5.0, 1.25, 0.1),
    "claude-fable-5": (10.0, 50.0, 12.5, 1.0),
}
PROJECTS = ["demo-api-service", "demo-web-client", "demo-data-pipeline"]
DAYS = 45


def cost(model, usage, at):
    inp, out, cw, cr = PRICING[model]
    if model == "claude-sonnet-5" and at >= datetime(2026, 9, 1, tzinfo=timezone.utc):
        inp, out, cw, cr = 3.0, 15.0, 3.75, 0.3
    return (
        usage["input_tokens"] * inp
        + usage["output_tokens"] * out
        + usage["cache_creation_input_tokens"] * cw
        + usage["cache_read_input_tokens"] * cr
    ) / 1_000_000


def main():
    out = Path(sys.argv[1] if len(sys.argv) > 1 else "review-sample/projects")
    rng = random.Random(20260728)  # fixed seed: regenerating gives the same numbers
    now = datetime.now(timezone.utc).replace(microsecond=0)

    total_tokens = total_cost = lines = 0
    for project in PROJECTS:
        project_dir = out / project
        project_dir.mkdir(parents=True, exist_ok=True)

        for day in range(DAYS):
            date = now - timedelta(days=day)
            # Leave some days empty so the heatmap has visible contrast.
            if rng.random() < 0.25:
                continue

            session = f"{project}-{date:%Y%m%d}"
            records = []
            for i in range(rng.randint(4, 22)):
                model = rng.choices(
                    list(PRICING), weights=[3, 5, 4, 1], k=1
                )[0]
                at = date.replace(
                    hour=rng.randint(9, 21), minute=rng.randint(0, 59), second=rng.randint(0, 59)
                )
                usage = {
                    "input_tokens": rng.randint(300, 4_000),
                    "output_tokens": rng.randint(200, 3_000),
                    "cache_creation_input_tokens": rng.randint(0, 30_000),
                    "cache_read_input_tokens": rng.randint(0, 120_000),
                }
                records.append({
                    "type": "assistant",
                    "timestamp": at.strftime("%Y-%m-%dT%H:%M:%SZ"),
                    "sessionId": session,
                    "message": {
                        "id": f"msg_{session}_{i}",
                        "model": model,
                        "usage": usage,
                    },
                })
                total_tokens += sum(usage.values())
                total_cost += cost(model, usage, at)
                lines += 1

            records.sort(key=lambda r: r["timestamp"])
            with (project_dir / f"{session}.jsonl").open("w") as f:
                for record in records:
                    f.write(json.dumps(record) + "\n")

    print(f"wrote {lines} entries to {out.resolve()}")
    print(f"the app should show roughly {total_tokens / 1_000_000:.2f}M tokens "
          f"and ${total_cost:,.2f} total")


if __name__ == "__main__":
    main()
