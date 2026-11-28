#!/usr/bin/env python3
"""Same pacing model as tests/Pacing.test.luau (the cloud session has no Luau runtime). Run: python3 tools/pacing_sim.py"""
bands = [(0, 11, 50, 59.1), (11, 10, 105, 135), (21, 10, 150, 210), (31, 10, 550, 890), (41, 10, 18000, 31680), (51, 10, 33000, 60000)]
growth, nominal, passive, passive_max = 1.74, 11.3, 1.7, 10

def secs(level):
    end = 0
    for first, count, a, b in bands:
        end = first + count
        if first <= level < end:
            return a + (b - a) * (level - first) / max(1, count - 1)
    return 63000 * 1.05 ** (level - end)

def reach(level):
    return sum(secs(i) for i in range(level))

prev = 0
for level in range(80):
    assert secs(level) > prev, level
    prev = secs(level)
for name, level in (("Rookie", 1), ("Sigma", 11), ("Chadlite", 21), ("Chad", 31), ("Gigachad", 41), ("Mog God", 51)):
    t = reach(level)
    print(f"active {name:9s} {t/60:9.1f} min  {t/3600:7.2f} h  {t/86400:5.2f} days")
cum = [0.0]
for level in range(1, 80):
    cum.append(cum[-1] + secs(level - 1) * nominal * growth ** (level - 1))
aura = 0.0; level = 0; t = 0
while t < 14 * 86400 and level < passive_max:
    aura += passive * growth ** level
    t += 1
    while aura >= cum[level + 1]:
        level += 1
print(f"idle: stops at level {level} (Rookie X) after {t/3600:.1f} h; never reaches Sigma")
