#!/usr/bin/env python3
"""
生成模拟数据，确保 Level 分布严格匹配
目标: L1:20% | L2:30% | L3:40% | L4:10%
"""

import json
import random
import uuid
import os
from datetime import datetime, timedelta

START_DATE = datetime(2026, 1, 1)
END_DATE = datetime(2026, 6, 6)
OUTPUT_DIR = os.path.expanduser("~/.claude/projects/mock-project-2026")

# Level 对应的 token 范围（严格匹配阈值）
# Threshold: L1<100K, L2<1M, L3<10M, L4>=10M
RANGES = {
    1: (30_000, 90_000),          # L1: <100K
    2: (200_000, 900_000),        # L2: 100K-1M
    3: (2_000_000, 9_000_000),    # L3: 1M-10M
    4: (15_000_000, 80_000_000),  # L4: >10M
}

MODELS = ["claude-sonnet-4-8", "claude-opus-4-8", "claude-fable-5"]

def is_weekend(d):
    return d.weekday() >= 5

def get_level(tokens):
    if tokens == 0: return 0
    if tokens < 100_000: return 1
    if tokens < 1_000_000: return 2
    if tokens < 10_000_000: return 3
    return 4

def generate_entries(date, total_tokens):
    """生成 entries，确保总 token 严格等于 total_tokens"""
    entries = []
    remaining = total_tokens

    while remaining > 0:
        # 每条 entry 5000-50000 tokens
        entry_size = min(random.randint(5000, 50000), remaining)
        remaining -= entry_size

        # 分配比例
        inp = int(entry_size * 0.55)
        out = int(entry_size * 0.30)
        cr = int(entry_size * 0.10)
        cc = entry_size - inp - out - cr

        entries.append({
            "type": "assistant" if random.random() > 0.1 else "user",
            "uuid": str(uuid.uuid4()),
            "messageId": str(uuid.uuid4()),
            "requestId": str(uuid.uuid4()),
            "sessionId": "mock-session",
            "timestamp": (date + timedelta(
                hours=random.randint(9, 22),
                minutes=random.randint(0, 59)
            )).isoformat() + "Z",
            "model": random.choice(MODELS),
            "usage": {
                "inputTokens": inp,
                "outputTokens": out,
                "cacheReadInputTokens": max(0, cr),
                "cacheCreationInputTokens": max(0, cc),
            }
        })

    return entries

def main():
    if os.path.exists(OUTPUT_DIR):
        import shutil
        shutil.rmtree(OUTPUT_DIR)
    os.makedirs(OUTPUT_DIR, exist_ok=True)

    target = {1: 0.20, 2: 0.30, 3: 0.40, 4: 0.10}
    print(f"目标: L1:{target[1]:.0%} L2:{target[2]:.0%} L3:{target[3]:.0%} L4:{target[4]:.0%}\n")

    # 所有日期
    dates = []
    d = START_DATE
    while d <= END_DATE:
        dates.append(d)
        d += timedelta(days=1)

    n_days = len(dates)
    n_active = int(n_days * 0.85)  # 85% 有数据

    # 分配 level
    n1 = int(n_active * target[1])
    n2 = int(n_active * target[2])
    n3 = int(n_active * target[3])
    n4 = n_active - n1 - n2 - n3

    levels = [0] * (n_days - n_active) + [1]*n1 + [2]*n2 + [3]*n3 + [4]*n4
    random.shuffle(levels)

    # 生成数据
    all_entries = []
    summary = {}

    for i, date in enumerate(dates):
        lvl = levels[i]
        date_str = date.strftime("%Y-%m-%d")

        if lvl == 0:
            summary[date_str] = {'tokens': 0, 'level': 0, 'is_weekend': is_weekend(date)}
            continue

        # 生成固定范围的 token
        min_t, max_t = RANGES[lvl]
        total = random.randint(min_t, max_t)

        entries = generate_entries(date, total)
        all_entries.extend(entries)

        # 验证
        actual = sum(e['usage']['inputTokens'] + e['usage']['outputTokens'] +
                    e['usage']['cacheReadInputTokens'] + e['usage']['cacheCreationInputTokens']
                    for e in entries)
        actual_lvl = get_level(actual)

        summary[date_str] = {
            'tokens': actual,
            'level': actual_lvl,
            'target': lvl,
            'match': actual_lvl == lvl,
            'is_weekend': is_weekend(date)
        }

    # 写入文件
    n_sessions = 4
    per = len(all_entries) // n_sessions

    for i in range(n_sessions):
        start = i * per
        end = (i + 1) * per if i < n_sessions - 1 else len(all_entries)
        sess_entries = all_entries[start:end]

        sid = str(uuid.uuid4())
        meta = [
            {"type": "mode", "mode": "normal", "sessionId": sid,
             "timestamp": START_DATE.isoformat() + "Z"},
            {"type": "permission-mode", "permissionMode": "bypassPermissions",
             "sessionId": sid, "timestamp": START_DATE.isoformat() + "Z"}
        ]

        for e in sess_entries:
            e['sessionId'] = sid

        with open(os.path.join(OUTPUT_DIR, f"{sid}.jsonl"), 'w') as f:
            for e in meta + sess_entries:
                f.write(json.dumps(e) + '\n')

        print(f"✓ Session {i+1}: {len(meta) + len(sess_entries)} entries")

    # 统计
    print(f"\n{'='*50}")
    print("📊 实际分布")
    print(f"{'='*50}")

    dist = {0: [], 1: [], 2: [], 3: [], 4: []}
    mismatches = []
    for ds, info in summary.items():
        dist[info['level']].append(ds)
        if not info.get('match', True):
            mismatches.append(f"{ds}: T{info['target']} A{info['level']}")

    names = {0: '⬜ 空白', 1: '🟩 浅绿', 2: '🟩 中绿', 3: '🟩 深绿', 4: '🟩🔥 最深'}
    for lvl in range(5):
        cnt = len(dist[lvl])
        pct = cnt / n_days * 100
        tgt = f"(目标 {target.get(lvl, '-'):.0%})" if lvl in target else ""
        bar = "█" * int(pct / 2)
        print(f"  L{lvl} {names[lvl]}: {cnt:3d} ({pct:5.1f}%) {tgt} {bar}")

    if mismatches:
        print(f"\n⚠️  {len(mismatches)} 天不匹配 (显示前5):")
        for m in mismatches[:5]:
            print(f"    {m}")
    else:
        print(f"\n✅ 所有天数 level 匹配正确！")

    print(f"\n总计: {len(all_entries)} 条记录")

if __name__ == "__main__":
    main()
