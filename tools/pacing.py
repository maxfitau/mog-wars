#!/usr/bin/env python3
"""Pacing simulation for Mog Wars. Reads the numbers from src/shared/EconomyConfig.luau, so the config is
the single source of truth, and estimates how many days different kinds of players need to reach each rank.

    python3 tools/pacing.py            # table of days to Chad and Mog God per player type
    python3 tools/pacing.py --ranks    # day-by-day rank for the casual profile

It is an expected-value model (no randomness), so it shows the typical pace, not the spread between
players. The player profiles and the share model are ASSUMPTIONS: change them here and in docs/economy.md.
Nothing here runs in the game.
"""
import argparse
import re
import sys
from pathlib import Path

CONFIG = Path(__file__).resolve().parent.parent / "src/shared/EconomyConfig.luau"


def strip_comments(text: str) -> str:
    return "\n".join(re.sub(r"--.*$", "", line) for line in text.splitlines())


def block(text: str, name: str) -> str:
    """Text inside `name = { ... }` (balanced braces), or an empty string."""
    match = re.search(r"\b" + re.escape(name) + r"\s*=\s*\{", text)
    if not match:
        return ""
    depth, index = 1, match.end()
    while index < len(text) and depth:
        depth += {"{": 1, "}": -1}.get(text[index], 0)
        index += 1
    return text[match.end():index - 1]


def number(text: str, name: str) -> float:
    match = re.search(r"\b" + re.escape(name) + r"\s*=\s*(-?[0-9.]+)", text)
    if not match:
        sys.exit(f"config is missing a number called '{name}'")
    return float(match.group(1))


def load():
    text = strip_comments(CONFIG.read_text(encoding="utf-8"))
    cfg = {}
    war, capture, aura = block(text, "war"), block(text, "capture"), block(text, "aura")
    cfg["war"] = {k: number(war, k) for k in ("winnerBonusPoints", "participantBonusPoints",
                                              "fullRewardWarsPerDay", "reducedRewardMultiplier")}
    cfg["capture"] = {k: number(capture, k) for k in ("basePool",)}
    cfg["aura"] = {"perRankBonus": number(aura, "perRankBonus")}
    cfg["ranks"] = [(m.group(1), int(m.group(2))) for m in re.finditer(
        r'\{\s*name\s*=\s*"([^"]+)"\s*,\s*cost\s*=\s*(\d+)\s*\}', block(text, "ranks"))]
    units = block(text, "units")
    cfg["unitSell"] = {u: number(block(units, u), "sellValue") for u in ("tank", "horse")}
    tiers = {}
    for tier in re.findall(r"(\w+)\s*=\s*\{\s*displayName", block(text, "tiers")):
        body = block(block(text, "tiers"), tier)
        drops = []
        for m in re.finditer(r"\{([^{}]*)\}", block(body, "drops")):
            d = m.group(1)
            weight = number(d, "weight")
            kind = re.search(r'kind\s*=\s*"([^"]+)"', d).group(1)
            if kind == "points":
                value = number(d, "amount")
            elif kind == "unit":
                value = cfg["unitSell"][re.search(r'unit\s*=\s*"([^"]+)"', d).group(1)]
            else:
                value = 0.0  # cosmetics have no points value
            drops.append((weight, value))
        tiers[tier] = drops
    cfg["boxEV"] = {t: sum(w * v for w, v in drops) / sum(w for w, _ in drops) for t, drops in tiers.items()}
    cfg["boxWeightSums"] = {t: sum(w for w, _ in drops) for t, drops in tiers.items()}
    boxes = block(text, "boxes")
    cfg["boxRules"] = [(int(m.group(1)), m.group(2)) for m in re.finditer(
        r'\{\s*minValue\s*=\s*(\d+)\s*,\s*tier\s*=\s*"([^"]+)"\s*\}', boxes)]
    cfg["boxDailyCap"] = number(boxes, "dailyCap")
    layout = (CONFIG.parent / "MapLayout.luau").read_text(encoding="utf-8")
    cfg["zoneValues"] = [int(v) for v in re.findall(r"value\s*=\s*(\d+)", block(strip_comments(layout), "zones"))]
    if not cfg["zoneValues"]:
        sys.exit("MapLayout.luau has no zones")
    streak = block(text, "dailyStreak")
    cfg["streak"] = [cfg["boxEV"][t] for t in re.findall(r'"([^"]+)"', block(streak, "rewards"))]  # the daily box, valued at its expected points
    bar = block(text, "barracks")
    cfg["barracks"] = {k: number(bar, k) for k in ("baseRatePerHour", "perRankRatePerHour", "maxStoredHours")}
    return cfg


# Assumed player types. share = the player's typical share of a capture's pool, captures = captures they
# take part in per war, winRate = how often their faction wins, awayHours = hours per day away (barracks).
PROFILES = {
    "light":   dict(wars=2,  days=(1, 1, 0, 1, 0, 1, 0), share=0.20, captures=2.5, winRate=0.25, awayHours=8),
    "casual":  dict(wars=3,  days=(1, 1, 1, 1, 1, 1, 0), share=0.25, captures=3.0, winRate=0.25, awayHours=8),
    "regular": dict(wars=5,  days=(1, 1, 1, 1, 1, 1, 1), share=0.30, captures=3.5, winRate=0.25, awayHours=8),
    "hardcore": dict(wars=12, days=(1, 1, 1, 1, 1, 1, 1), share=0.40, captures=4.0, winRate=0.30, awayHours=8),
}


def tier_for(cfg, value):
    for minimum, tier in cfg["boxRules"]:
        if value >= minimum:
            return tier
    sys.exit("no box tier matches a zone value of %s" % value)


def simulate(cfg, p, max_days=400):
    ranks = cfg["ranks"]
    avg_pool = cfg["capture"]["basePool"] * sum(cfg["zoneValues"]) / len(cfg["zoneValues"])
    avg_box = sum(cfg["boxEV"][tier_for(cfg, v)] for v in cfg["zoneValues"]) / len(cfg["zoneValues"])
    rank, points, streak_day = 1, 0.0, 0
    days_to = {}
    history = []
    for day in range(max_days):
        if not p["days"][day % 7]:
            streak_day = 0
            earned = 0.0
            # barracks still fills while away, collected on the next visit; counted when the player returns
            history.append((day, rank, points))
            continue
        wars = p["wars"]
        full = min(wars, cfg["war"]["fullRewardWarsPerDay"])
        reduced = max(0, wars - full)
        mult = (full + reduced * cfg["war"]["reducedRewardMultiplier"])
        share_mult = 1 + 0.04 * (rank - 1)  # a higher rank adds a little aura power, so a little more share
        per_war = (p["captures"] * avg_pool * min(0.9, p["share"] * share_mult)
                   + p["winRate"] * cfg["war"]["winnerBonusPoints"] + (1 - p["winRate"]) * cfg["war"]["participantBonusPoints"])
        earned = per_war * mult
        # Every paid contributor earns one box per capture, up to the daily cap, at the average zone's tier.
        boxes_today = min(cfg["boxDailyCap"], wars * p["captures"])
        earned += boxes_today * avg_box
        rewards = cfg["streak"]
        earned += rewards[streak_day % len(rewards)]
        streak_day += 1
        bar = cfg["barracks"]
        rate = bar["baseRatePerHour"] + bar["perRankRatePerHour"] * (rank - 1)
        earned += rate * min(p["awayHours"], bar["maxStoredHours"])
        points += earned
        while rank < len(ranks) and points >= ranks[rank][1]:
            points -= ranks[rank][1]
            rank += 1
            days_to.setdefault(rank, day + 1)
        history.append((day, rank, points))
    return days_to, history


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--ranks", action="store_true", help="day-by-day ranks for the casual profile")
    args = parser.parse_args()
    cfg = load()
    names = [r[0] for r in cfg["ranks"]]
    chad, god = names.index("Chad") + 1, len(names)
    print("Box odds sums (each must be 100):", cfg["boxWeightSums"])
    print("Box expected points:", {k: round(v, 1) for k, v in cfg["boxEV"].items()})
    print("Rank costs:", [(n, c) for n, c in cfg["ranks"]], " total to Chad:",
          sum(c for _, c in cfg["ranks"][1:chad]), " total to Mog God:", sum(c for _, c in cfg["ranks"][1:]))
    print()
    print(f"{'player type':<10} {'wars/day':>8} {'days/wk':>7}   days to {names[chad-1]:<6} days to {names[-1]}")
    for name, p in PROFILES.items():
        days_to, _ = simulate(cfg, p)
        print(f"{name:<10} {p['wars']:>8} {sum(p['days']):>7}   {str(days_to.get(chad, '>400')):>12} {str(days_to.get(god, '>400')):>14}")
    if args.ranks:
        print()
        _, history = simulate(cfg, PROFILES["casual"], 60)
        for day, rank, points in history:
            if day % 3 == 0:
                print(f"day {day + 1:>2}: {names[rank-1]:<9} (+{points:.0f} points toward the next rank)")


if __name__ == "__main__":
    main()
