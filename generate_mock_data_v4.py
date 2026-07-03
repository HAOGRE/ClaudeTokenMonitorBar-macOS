#!/usr/bin/env python3
"""
基于真实数据阈值生成模拟数据
目标分布: L1:20% | L2:30% | L3:40% | L4:10%
"""

import json
import random
import uuid
import os
from datetime import datetime, timedelta

# 配置
START_DATE = datetime(2026, 1, 1)
END_DATE = datetime(2026, 6, 6)
OUTPUT_DIR = os.path.expanduser("~/.claude/projects/mock-project-2026")

# 基于真实数据设定的阈值
THRESHOLDS = {
    0: 0,
    1: 100_000,
    2: 1_000_000,
    3: 10_000_000,
    4: 50_000_000,
}

# Level 对应的 token 范围 (严格在阈值内)
TOKEN_RANGES = {
    1: (20_000, 90_000),          # < 100K
    2: (1_100_000, 9_500_000),    # 1M - 10M
    3: (11_000_000, 48_000_000),  # 10M - 50M
    4: (52_000_000, 80_000_000),  # > 50M
}

MODELS = ["claude-sonnet-4-8", "claude-opus-4-8", "claude-fable-5"]

def is_weekend(date):
    return date.weekday() >= 5

def get_level(tokens):
    if tokens == 0:
        return 0
    elif tokens < THRESHOLDS[1]:
        return 1
    elif tokens < THRESHOLDS[2]:
        return 2
    elif tokens < THRESHOLDS[3]:
        return 3
    else:
        return 4

def generate_day_data(date, total_tokens):
    """生成某天的数据，拆分成多个 entries"""
    if total_tokens == 0:
        return []

    # 拆分成多个 entries
    entries = []
    remaining = total_tokens

    while remaining > 0:
        # 每条 entry 的 token 上限
        max_per_entry = min(80_000, remaining)
        if max_per_entry < 5000:
            entry_tokens = remaining  # 最后一点直接用完
        else:
            entry_tokens = random.randint(5000, max_per_entry)

        remaining -= entry_tokens

        hour = random.randint(9, 23)
        minute = random.randint(0, 59)
        second = random.randint(0, 59)
        request_time = date + timedelta(hours=hour, minutes=minute, seconds=second)

        # 分配 input/output/cache
        input_t = int(entry_tokens * 0.6)
        output_t = int(entry_tokens * 0.25)
        cache_r = int(entry_tokens * 0.1)
        cache_c = entry_tokens - input_t - output_t - cache_r  # 剩余部分

        entries.append({
            "type": "assistant" if random.random() > 0.1 else "user",
            "uuid": str(uuid.uuid4()),
            "messageId": str(uuid.uuid4()),
            "requestId": str(uuid.uuid4()),
            "sessionId": "mock-session",
            "timestamp": request_time.isoformat() + "Z",
            "model": random.choice(MODELS),
            "usage": {
                "inputTokens": max(0, input_t),
                "outputTokens": max(0, output_t),
                "cacheReadInputTokens": max(0, cache_r),
                "cacheCreationInputTokens": max(0, cache_c),
            }
        })

    return entries

def main():
    if os.path.exists(OUTPUT_DIR):
        import shutil
        shutil.rmtree(OUTPUT_DIR)
    os.makedirs(OUTPUT_DIR, exist_ok=True)

    target_dist = {1: 0.20, 2: 0.30, 3: 0.40, 4: 0.10}

    print(f"目标分布: L1:{target_dist[1]:.0%} | L2:{target_dist[2]:.0%} | L3:{target_dist[3]:.0%} | L4:{target_dist[4]:.0%}")
    print(f"日期范围: {START_DATE.date()} 到 {END_DATE.date()}\n")

    # 收集所有日期
    all_dates = []
    current = START_DATE
    while current <= END_DATE:
        all_dates.append(current)
        current += timedelta(days=1)

    total_days = len(all_dates)

    # 85% 的天数有数据
    active_count = int(total_days * 0.85)
    active_flags = [True] * active_count + [False] * (total_days - active_count)
    random.shuffle(active_flags)

    # 为活跃天数分配 level
    n_l1 = int(active_count * target_dist[1])
    n_l2 = int(active_count * target_dist[2])
    n_l3 = int(active_count * target_dist[3])
    n_l4 = active_count - n_l1 - n_l2 - n_l3

    level_pool = ([1] * n_l1) + ([2] * n_l2) + ([3] * n_l3) + ([4] * n_l4)
    random.shuffle(level_pool)

    # 生成数据
    all_entries = []
    daily_summary = {}
    level_idx = 0

    for i, date in enumerate(all_dates):
        date_str = date.strftime("%Y-%m-%d")

        if active_flags[i]:
            target_level = level_pool[level_idx]
            level_idx += 1
            # 生成总 token 数（严格在范围内）
            min_tok, max_tok = TOKEN_RANGES[target_level]
            total = random.randint(min_tok, max_tok)

            entries = generate_day_data(date, total)

            all_entries.extend(entries)
            daily_summary[date_str] = {
                'tokens': total,
                'level': get_level(total),
                'target_level': target_level,
                'entries': len(entries),
                'is_weekend': is_weekend(date)
            }
        else:
            daily_summary[date_str] = {
                'tokens': 0,
                'level': 0,
                'target_level': 0,
                'entries': 0,
                'is_weekend': is_weekend(date)
            }

    # 写入文件
    num_sessions = 4
    per_session = len(all_entries) // num_sessions

    for i in range(num_sessions):
        start = i * per_session
        end = (i + 1) * per_session if i < num_sessions - 1 else len(all_entries)
        session_entries = all_entries[start:end]

        session_id = str(uuid.uuid4())
        meta = [
            {"type": "mode", "mode": "normal", "sessionId": session_id,
             "timestamp": START_DATE.isoformat() + "Z"},
            {"type": "permission-mode", "permissionMode": "bypassPermissions",
             "sessionId": session_id, "timestamp": START_DATE.isoformat() + "Z"}
        ]

        for e in session_entries:
            e['sessionId'] = session_id

        with open(os.path.join(OUTPUT_DIR, f"{session_id}.jsonl"), 'w') as f:
            for e in meta + session_entries:
                f.write(json.dumps(e) + '\n')

        print(f"✓ Session {i+1}: {len(meta) + len(session_entries)} entries")

    # 统计
    print(f"\n{'='*60}")
    print(f"📊 分布对比")
    print(f"{'='*60}")

    levels = {0: [], 1: [], 2: [], 3: [], 4: []}
    mismatches = []
    for date_str, info in daily_summary.items():
        levels[info['level']].append(date_str)
        if info['level'] != info['target_level'] and info['target_level'] > 0:
            mismatches.append(f"{date_str}: target=L{info['target_level']}, actual=L{info['level']}")

    total = len(daily_summary)
    names = {0: '⬜ 空白', 1: '🟩 浅绿', 2: '🟩 中绿', 3: '🟩 深绿', 4: '🟩🔥 最深'}

    for level in range(5):
        count = len(levels[level])
        pct = count / total * 100
        target = f"(目标 {target_dist.get(level, '-'):.0%})" if level in target_dist else ""
        bar = "█" * int(pct / 2)
        print(f"  Level {level} {names[level]}: {count:3d}天 ({pct:5.1f}%) {target} {bar}")

    if mismatches:
        print(f"\n⚠️  {len(mismatches)} 天 level 不匹配 (前5个):")
        for m in mismatches[:5]:
            print(f"    {m}")

    print(f"\n总记录数: {len(all_entries)}")

if __name__ == "__main__":
    main()
