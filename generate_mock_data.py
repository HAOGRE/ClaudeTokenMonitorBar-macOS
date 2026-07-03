#!/usr/bin/env python3
"""
生成模拟的 Claude Code 使用数据用于截图展示
时间范围: 2026-01-01 到 2026-06-06 (完整覆盖)
"""

import json
import random
import uuid
import os
from datetime import datetime, timedelta

# 配置 - 确保完整覆盖 2026-01-01 到 2026-06-06
START_DATE = datetime(2026, 1, 1)
END_DATE = datetime(2026, 6, 6)
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

# 生成单个 session 的完整数据 - 确保覆盖整个日期范围
def generate_session_data(session_id: str, start_date: datetime, end_date: datetime, session_idx: int):
    """生成一个 session 的完整数据"""
    entries = []

    # session 元数据
    entries.append({
        "type": "mode",
        "mode": "normal",
        "sessionId": session_id,
        "timestamp": start_date.isoformat() + "Z"
    })

    entries.append({
        "type": "permission-mode",
        "permissionMode": "bypassPermissions",
        "sessionId": session_id,
        "timestamp": start_date.isoformat() + "Z"
    })

    # 生成每天的使用记录 - 确保每天都有数据
    current_date = start_date
    day_counter = 0

    while current_date <= end_date:
        day_counter += 1

        # 使用正弦波 + 偏移来模拟不同 session 的活跃度差异
        # 这样不同 session 在不同时间段活跃，合并后会有丰富的层次
        day_of_year = current_date.timetuple().tm_yday

        # 每个 session 有不同的活跃模式
        phase_offset = session_idx * 30  # 相位偏移
        base_pattern = (1 + 0.6 * ((day_of_year + phase_offset) % 60) / 60)

        # 添加随机波动
        random_factor = random.random()

        # 周末活跃度降低
        weekend_factor = 0.4 if current_date.weekday() >= 5 else 1.0

        # 计算活跃度等级 (0-4)
        activity_score = base_pattern * random_factor * weekend_factor
        activity_level = min(4, int(activity_score * 2.5))

        # 即使是低活跃日也至少有一些数据（确保每天都有记录）
        if activity_level == 0:
            activity_level = random.choice([0, 1])  # 偶尔完全空白，偶尔有少量

        # 根据活跃度决定请求数量和 token 数
        if activity_level == 0:
            # 空白日 - 无数据
            pass
        elif activity_level == 1:
            # 低活跃 - 少量小请求
            num_requests = random.randint(1, 3)
            base_tokens = random.randint(100, 1000)
        elif activity_level == 2:
            # 中等活跃
            num_requests = random.randint(3, 8)
            base_tokens = random.randint(1000, 5000)
        elif activity_level == 3:
            # 高活跃
            num_requests = random.randint(8, 15)
            base_tokens = random.randint(5000, 15000)
        else:  # level 4
            # 非常高活跃
            num_requests = random.randint(15, 30)
            base_tokens = random.randint(15000, 50000)

        if activity_level > 0:
            for i in range(num_requests):
                # 在白天工作时间分布
                hour = random.randint(9, 21)
                minute = random.randint(0, 59)
                second = random.randint(0, 59)

                request_time = current_date + timedelta(hours=hour, minutes=minute, seconds=second)

                # 生成 token 数据
                model = random.choice(MODELS)

                # 根据活跃度等级调整 token 数量
                if activity_level == 1:
                    input_tokens = random.randint(100, 2000)
                elif activity_level == 2:
                    input_tokens = random.randint(500, 8000)
                elif activity_level == 3:
                    input_tokens = random.randint(2000, 15000)
                else:
                    input_tokens = random.randint(8000, 30000)

                output_tokens = int(input_tokens * random.uniform(0.15, 0.6))
                cache_read = random.randint(0, input_tokens // 3) if random.random() > 0.6 else 0
                cache_create = random.randint(0, input_tokens // 5) if random.random() > 0.7 else 0

                message_id = str(uuid.uuid4())
                request_id = str(uuid.uuid4())

                entry = {
                    "type": "assistant" if random.random() > 0.15 else "user",
                    "uuid": str(uuid.uuid4()),
                    "messageId": message_id,
                    "requestId": request_id,
                    "sessionId": session_id,
                    "timestamp": request_time.isoformat() + "Z",
                    "model": model,
                    "usage": {
                        "inputTokens": input_tokens,
                        "outputTokens": output_tokens,
                        "cacheReadInputTokens": cache_read,
                        "cacheCreationInputTokens": cache_create
                    }
                }
                entries.append(entry)

        current_date += timedelta(days=1)

    return entries

def main():
    # 删除旧数据
    if os.path.exists(OUTPUT_DIR):
        for f in os.listdir(OUTPUT_DIR):
            if f.endswith('.jsonl'):
                os.remove(os.path.join(OUTPUT_DIR, f))
    else:
        os.makedirs(OUTPUT_DIR, exist_ok=True)

    # 生成 4-6 个 session，覆盖不同的时间段
    num_sessions = 5
    all_entries = []

    print(f"Generating mock data from {START_DATE.date()} to {END_DATE.date()}...")
    print(f"Target: Cover all days with varied activity levels\n")

    for i in range(num_sessions):
        session_id = str(uuid.uuid4())

        # 每个 session 覆盖整个日期范围，但活跃模式不同
        entries = generate_session_data(session_id, START_DATE, END_DATE, i)
        all_entries.extend(entries)

        # 写入单独的 session 文件
        filename = f"{session_id}.jsonl"
        filepath = os.path.join(OUTPUT_DIR, filename)
        with open(filepath, 'w', encoding='utf-8') as f:
            for entry in entries:
                f.write(json.dumps(entry, ensure_ascii=False) + '\n')

        print(f"✓ Session {i+1}: {filename} ({len(entries)} entries)")

    # 统计验证
    daily_tokens = {}
    for entry in all_entries:
        if 'usage' in entry:
            day = entry['timestamp'][:10]
            usage = entry.get('usage', {})
            tokens = usage.get('inputTokens', 0) + usage.get('outputTokens', 0) + usage.get('cacheReadInputTokens', 0) + usage.get('cacheCreationInputTokens', 0)
            daily_tokens[day] = daily_tokens.get(day, 0) + tokens

    # 计算等级分布
    if daily_tokens:
        max_tokens = max(daily_tokens.values())
        levels = {0: 0, 1: 0, 2: 0, 3: 0, 4: 0}
        for day, tokens in daily_tokens.items():
            ratio = tokens / max_tokens if max_tokens > 0 else 0
            if tokens == 0:
                level = 0
            elif ratio < 0.25:
                level = 1
            elif ratio < 0.5:
                level = 2
            elif ratio < 0.75:
                level = 3
            else:
                level = 4
            levels[level] += 1

        print(f"\n📊 Activity Level Distribution:")
        for level in sorted(levels.keys()):
            bar = "█" * (levels[level] // 2)
            print(f"   Level {level}: {levels[level]:3d} days {bar}")

    print(f"\n✅ Mock data generated!")
    print(f"   Directory: {OUTPUT_DIR}")
    print(f"   Sessions: {num_sessions}")
    print(f"   Total entries: {len(all_entries)}")
    print(f"   Days with data: {len(daily_tokens)}")
    print(f"   Date range: {min(daily_tokens.keys())} to {max(daily_tokens.keys())}")

if __name__ == "__main__":
    main()
