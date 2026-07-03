#!/usr/bin/env python3
"""
基于真实数据阈值生成模拟数据
真实参考: 2026-06-11 有 62,157,348 tokens (Level 4)
"""

import json
import random
import uuid
import os
from datetime import datetime, timedelta

# 配置
START_DATE = datetime(2026, 1, 1)
END_DATE = datetime(2026, 6, 6)  # 生成到 6月6日
OUTPUT_DIR = os.path.expanduser("~/.claude/projects/mock-project-2026")

# 基于真实数据设定的阈值
# 参考: 62M tokens = Level 4
# 使用对数分布，因为 token 数量差异很大
REAL_MAX = 62_157_348  # 62M

# 阈值设定 (使用对数比例更合理)
THRESHOLDS = {
    0: 0,
    1: 100_000,       # 100K - 浅绿
    2: 1_000_000,     # 1M - 中绿
    3: 10_000_000,    # 10M - 深绿
    4: 50_000_000,    # 50M+ - 最深
}

# 模型列表
MODELS = [
    "claude-sonnet-4-8",
    "claude-opus-4-8",
    "claude-fable-5"
]

def is_weekend(date):
    return date.weekday() >= 5

def get_level(tokens):
    """根据 token 数返回 level"""
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

def generate_day_tokens(date, is_special_day=False):
    """生成某一天的总 token 数"""

    # 周末大概率低活跃
    if is_weekend(date):
        r = random.random()
        if r < 0.5:
            return 0  # 50% 完全休息
        elif r < 0.8:
            return random.randint(10_000, 100_000)  # Level 1
        else:
            return random.randint(100_000, 500_000)  # Level 2

    # 工作日
    if is_special_day:
        # 特殊高活跃日 (Level 4)
        return random.randint(30_000_000, 70_000_000)

    # 普通工作日分布
    r = random.random()
    if r < 0.15:
        return 0  # 15% 摸鱼
    elif r < 0.40:
        return random.randint(10_000, 100_000)  # Level 1 (25%)
    elif r < 0.65:
        return random.randint(100_000, 1_000_000)  # Level 2 (25%)
    elif r < 0.85:
        return random.randint(1_000_000, 10_000_000)  # Level 3 (20%)
    else:
        return random.randint(10_000_000, 40_000_000)  # Level 4 (15%)

def generate_entries_for_day(date, total_tokens):
    """为某一天生成具体的 JSONL 条目"""
    entries = []

    if total_tokens == 0:
        return entries

    # 根据总 token 数决定请求数量
    if total_tokens < 100_000:
        num_requests = random.randint(3, 10)
    elif total_tokens < 1_000_000:
        num_requests = random.randint(10, 30)
    elif total_tokens < 10_000_000:
        num_requests = random.randint(30, 80)
    else:
        num_requests = random.randint(80, 200)

    avg_tokens_per_request = total_tokens // num_requests

    for i in range(num_requests):
        hour = random.randint(9, 23)
        minute = random.randint(0, 59)
        second = random.randint(0, 59)
        request_time = date + timedelta(hours=hour, minutes=minute, seconds=second)

        # 生成 token 数（围绕平均值波动）
        variation = random.uniform(0.2, 3.0)
        input_tokens = int(avg_tokens_per_request * variation)
        input_tokens = min(input_tokens, 100_000)  # 单条上限

        output_tokens = int(input_tokens * random.uniform(0.3, 0.8))
        cache_read = int(input_tokens * random.uniform(0, 0.4)) if random.random() > 0.4 else 0
        cache_create = int(input_tokens * random.uniform(0, 0.3)) if random.random() > 0.6 else 0

        entry = {
            "type": "assistant" if random.random() > 0.1 else "user",
            "uuid": str(uuid.uuid4()),
            "messageId": str(uuid.uuid4()),
            "requestId": str(uuid.uuid4()),
            "sessionId": "mock-session",
            "timestamp": request_time.isoformat() + "Z",
            "model": random.choice(MODELS),
            "usage": {
                "inputTokens": input_tokens,
                "outputTokens": output_tokens,
                "cacheReadInputTokens": cache_read,
                "cacheCreationInputTokens": cache_create
            }
        }
        entries.append(entry)

    return entries

def main():
    # 清理旧数据
    if os.path.exists(OUTPUT_DIR):
        import shutil
        shutil.rmtree(OUTPUT_DIR)
    os.makedirs(OUTPUT_DIR, exist_ok=True)

    print(f"基于真实数据阈值生成模拟数据")
    print(f"参考: 62M tokens = Level 4")
    print(f"阈值: L1={THRESHOLDS[1]:,}, L2={THRESHOLDS[2]:,}, L3={THRESHOLDS[3]:,}, L4={THRESHOLDS[4]:,}+")
    print(f"日期范围: {START_DATE.date()} 到 {END_DATE.date()}\n")

    all_entries = []
    daily_summary = {}

    # 设定几个特定的 Level 4 高活跃日
    level_4_days = [
        datetime(2026, 1, 10),
        datetime(2026, 2, 15),
        datetime(2026, 3, 20),
        datetime(2026, 4, 12),
        datetime(2026, 5, 8),
        datetime(2026, 6, 3),
    ]
    level_4_set = set(d.strftime("%Y-%m-%d") for d in level_4_days)

    current_date = START_DATE
    while current_date <= END_DATE:
        date_str = current_date.strftime("%Y-%m-%d")
        is_special = date_str in level_4_set

        daily_tokens = generate_day_tokens(current_date, is_special)

        if daily_tokens > 0:
            entries = generate_entries_for_day(current_date, daily_tokens)
            all_entries.extend(entries)
            level = get_level(daily_tokens)
            daily_summary[date_str] = {
                'tokens': daily_tokens,
                'level': level,
                'entries': len(entries),
                'is_weekend': is_weekend(current_date)
            }
        else:
            daily_summary[date_str] = {
                'tokens': 0,
                'level': 0,
                'entries': 0,
                'is_weekend': is_weekend(current_date)
            }

        current_date += timedelta(days=1)

    # 写入文件
    num_sessions = 4
    entries_per_session = len(all_entries) // num_sessions

    for i in range(num_sessions):
        start_idx = i * entries_per_session
        end_idx = (i + 1) * entries_per_session if i < num_sessions - 1 else len(all_entries)
        session_entries = all_entries[start_idx:end_idx]

        session_id = str(uuid.uuid4())
        session_meta = [
            {"type": "mode", "mode": "normal", "sessionId": session_id,
             "timestamp": START_DATE.isoformat() + "Z"},
            {"type": "permission-mode", "permissionMode": "bypassPermissions",
             "sessionId": session_id, "timestamp": START_DATE.isoformat() + "Z"}
        ]

        for entry in session_entries:
            entry['sessionId'] = session_id

        all_session_entries = session_meta + session_entries

        filename = f"{session_id}.jsonl"
        filepath = os.path.join(OUTPUT_DIR, filename)
        with open(filepath, 'w', encoding='utf-8') as f:
            for entry in all_session_entries:
                f.write(json.dumps(entry, ensure_ascii=False) + '\n')

        print(f"✓ Session {i+1}: {filename} ({len(all_session_entries)} entries)")

    # 统计报告
    print(f"\n{'='*60}")
    print(f"📊 数据统计")
    print(f"{'='*60}")

    total_days = len(daily_summary)
    active_days = sum(1 for d in daily_summary.values() if d['tokens'] > 0)

    print(f"\n时间范围: {min(daily_summary.keys())} 到 {max(daily_summary.keys())}")
    print(f"总天数: {total_days}")
    print(f"活跃天数: {active_days}")
    print(f"总记录数: {len(all_entries)}")

    print(f"\n🔥 Level 分布 (基于真实阈值):")
    level_names = {0: '⬜ 空白', 1: '🟩 浅绿', 2: '🟩 中绿', 3: '🟩 深绿', 4: '🟩🔥 最深'}
    for level in range(5):
        days = [d for d in daily_summary.values() if d['level'] == level]
        count = len(days)
        if count > 0:
            avg = sum(d['tokens'] for d in days) // count
            bar = "█" * (count // 3)
            print(f"  Level {level} {level_names[level]}: {count:3d}天  平均{avg:>12,} tokens  {bar}")
        else:
            print(f"  Level {level} {level_names[level]}: 0天")

    # 显示 Level 4 的日子
    print(f"\n🏆 Level 4 (最深) 的日子:")
    level_4_days = [(d, info) for d, info in daily_summary.items() if info['level'] == 4]
    for date_str, info in sorted(level_4_days, key=lambda x: x[1]['tokens'], reverse=True):
        day_type = "周末" if info['is_weekend'] else "工作日"
        print(f"  {date_str}: {info['tokens']:>12,} tokens ({day_type})")

    # 工作日 vs 周末
    weekdays = [d for d in daily_summary.values() if not d['is_weekend']]
    weekends = [d for d in daily_summary.values() if d['is_weekend']]

    print(f"\n📅 工作日 vs 周末:")
    wday_avg = sum(d['tokens'] for d in weekdays) // len(weekdays) if weekdays else 0
    wend_avg = sum(d['tokens'] for d in weekends) // len(weekends) if weekends else 0
    print(f"  工作日 ({len(weekdays)}天): 平均 {wday_avg:,} tokens")
    print(f"  周末   ({len(weekends)}天): 平均 {wend_avg:,} tokens")

if __name__ == "__main__":
    main()
