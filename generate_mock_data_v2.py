#!/usr/bin/env python3
"""
生成更真实的 Claude Code 使用数据
- 时间范围: 2026-01-01 到 2026-07-03
- 工作日活跃，周末较少
- 深浅区分明显（Level 4 要非常突出）
"""

import json
import random
import uuid
import os
from datetime import datetime, timedelta

# 配置
START_DATE = datetime(2026, 1, 1)
END_DATE = datetime(2026, 7, 3)
OUTPUT_DIR = os.path.expanduser("~/.claude/projects/mock-project-2026")

# 模型列表
MODELS = [
    "claude-sonnet-4-8",
    "claude-sonnet-4-7",
    "claude-opus-4-8",
    "claude-opus-4-7",
    "claude-haiku-4-5",
    "claude-fable-5"
]

def is_weekend(date):
    """判断是否为周末"""
    return date.weekday() >= 5

def get_activity_level(date, is_high_day=False):
    """
    根据日期返回活跃度等级
    - 周末：大概率 Level 0-1，偶尔 Level 2
    - 工作日：Level 1-4
    - is_high_day: 特定的高活跃日（Level 3-4）
    """
    if is_weekend(date):
        # 周末：70% 无数据或极少，30% 有一些
        r = random.random()
        if r < 0.4:
            return 0  # 完全休息
        elif r < 0.7:
            return 1  # 少量
        else:
            return random.choice([1, 2])  # 偶尔加班
    else:
        # 工作日
        if is_high_day:
            # 高活跃日（比如发布前、赶进度）
            return random.choice([3, 4])
        else:
            # 普通工作日
            r = random.random()
            if r < 0.1:
                return 0  # 偶尔摸鱼
            elif r < 0.4:
                return 1
            elif r < 0.7:
                return 2
            elif r < 0.9:
                return 3
            else:
                return 4

def generate_day_tokens(activity_level):
    """
    根据活跃度等级生成当天的 token 数量
    确保 Level 4 非常突出（100万+），与 Level 1 有明显差距
    """
    if activity_level == 0:
        return 0
    elif activity_level == 1:
        # 低活跃：1千 - 3万
        return random.randint(1000, 30000)
    elif activity_level == 2:
        # 中等：5万 - 15万
        return random.randint(50000, 150000)
    elif activity_level == 3:
        # 高活跃：20万 - 50万
        return random.randint(200000, 500000)
    else:  # Level 4
        # 非常高活跃：80万 - 150万（确保明显突出）
        return random.randint(800000, 1500000)

def generate_entries_for_day(date, daily_tokens):
    """为某一天生成具体的 JSONL 条目"""
    entries = []

    if daily_tokens == 0:
        return entries

    # 根据总 token 数决定请求数量
    if daily_tokens < 30000:
        num_requests = random.randint(2, 8)
    elif daily_tokens < 150000:
        num_requests = random.randint(8, 20)
    elif daily_tokens < 500000:
        num_requests = random.randint(20, 40)
    else:
        num_requests = random.randint(40, 80)

    # 生成请求
    tokens_per_request = daily_tokens // num_requests

    for i in range(num_requests):
        # 工作时间：9:00 - 22:00
        hour = random.randint(9, 22)
        minute = random.randint(0, 59)
        second = random.randint(0, 59)
        request_time = date + timedelta(hours=hour, minutes=minute, seconds=second)

        # 生成 token 数（围绕平均值波动）
        base = tokens_per_request
        variation = random.uniform(0.3, 2.0)
        input_tokens = int(base * variation)

        # 限制单条最大 token（避免太夸张）
        input_tokens = min(input_tokens, 50000)

        output_tokens = int(input_tokens * random.uniform(0.2, 0.7))
        cache_read = int(input_tokens * random.uniform(0, 0.3)) if random.random() > 0.5 else 0
        cache_create = int(input_tokens * random.uniform(0, 0.2)) if random.random() > 0.7 else 0

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

    print(f"Generating realistic mock data...")
    print(f"Date range: {START_DATE.date()} to {END_DATE.date()}")
    print(f"Pattern: Weekdays active, weekends light\n")

    all_entries = []
    daily_summary = {}

    # 设定几个特定的高活跃日（赶进度/发布前）
    high_days = [
        datetime(2026, 1, 15),   # 1月中旬冲刺
        datetime(2026, 2, 28),   # 2月底
        datetime(2026, 3, 31),   # 3月底
        datetime(2026, 4, 25),   # 4月
        datetime(2026, 5, 16),   # 5月
        datetime(2026, 6, 6),    # 6月6日（截图中的重要日期）
        datetime(2026, 6, 20),   # 6月
    ]
    high_days_set = set(d.strftime("%Y-%m-%d") for d in high_days)

    current_date = START_DATE
    while current_date <= END_DATE:
        date_str = current_date.strftime("%Y-%m-%d")
        is_high = date_str in high_days_set

        activity_level = get_activity_level(current_date, is_high)
        daily_tokens = generate_day_tokens(activity_level)

        if daily_tokens > 0:
            entries = generate_entries_for_day(current_date, daily_tokens)
            all_entries.extend(entries)
            daily_summary[date_str] = {
                'tokens': daily_tokens,
                'level': activity_level,
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

    # 将数据写入文件（分成多个 session 文件更真实）
    num_sessions = 4
    entries_per_session = len(all_entries) // num_sessions

    for i in range(num_sessions):
        start_idx = i * entries_per_session
        end_idx = (i + 1) * entries_per_session if i < num_sessions - 1 else len(all_entries)
        session_entries = all_entries[start_idx:end_idx]

        session_id = str(uuid.uuid4())

        # 添加 session 元数据
        session_meta = [
            {"type": "mode", "mode": "normal", "sessionId": session_id,
             "timestamp": START_DATE.isoformat() + "Z"},
            {"type": "permission-mode", "permissionMode": "bypassPermissions",
             "sessionId": session_id, "timestamp": START_DATE.isoformat() + "Z"}
        ]

        # 更新 session_id
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
    print(f"\n{'='*50}")
    print(f"📊 数据统计报告")
    print(f"{'='*50}")

    total_days = len(daily_summary)
    active_days = sum(1 for d in daily_summary.values() if d['tokens'] > 0)

    print(f"\n时间范围: {min(daily_summary.keys())} 到 {max(daily_summary.keys())}")
    print(f"总天数: {total_days}")
    print(f"活跃天数: {active_days}")
    print(f"总记录数: {len(all_entries)}")

    # 等级分布
    print(f"\n🔥 活跃度分布:")
    level_names = {0: '⬜ 空白', 1: '🟩 低', 2: '🟩 中', 3: '🟩 高', 4: '🟩🔥 超高'}
    for level in range(5):
        days = [d for d in daily_summary.values() if d['level'] == level]
        count = len(days)
        bar = "█" * (count // 2)
        avg_tokens = sum(d['tokens'] for d in days) // count if count > 0 else 0
        print(f"  Level {level} {level_names[level]}: {count:3d}天  平均{avg_tokens:>8,} tokens  {bar}")

    # 找出 token 最多的几天
    print(f"\n🏆 Token 最多的几天:")
    top_days = sorted(daily_summary.items(), key=lambda x: x[1]['tokens'], reverse=True)[:8]
    for date_str, info in top_days:
        day_type = "周末" if info['is_weekend'] else "工作日"
        bar = "█" * (info['level'] + 1)
        print(f"  {date_str}: {info['tokens']:>10,} tokens  {bar} Level {info['level']} ({day_type})")

    # 工作日 vs 周末统计
    weekdays = [d for d in daily_summary.values() if not d['is_weekend']]
    weekends = [d for d in daily_summary.values() if d['is_weekend']]

    print(f"\n📅 工作日 vs 周末:")
    print(f"  工作日: {len(weekdays)}天, 平均 {sum(d['tokens'] for d in weekdays)//len(weekdays):,} tokens")
    print(f"  周末:   {len(weekends)}天, 平均 {sum(d['tokens'] for d in weekends)//len(weekends):,} tokens")

if __name__ == "__main__":
    main()
