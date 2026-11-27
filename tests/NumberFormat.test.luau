--!strict
-- Plain-Luau tests, no Roblox needed. Run from the repo root with the standalone Luau runtime:
--   luau tests/NumberFormat.test.luau
-- STATUS: written but NOT yet run (no Luau runtime in the cloud session). Run it on a PC first.

local NumberFormat = require("../src/shared/NumberFormat")

local failures = 0

local function check(name: string, condition: boolean)
	if condition then
		print("PASS " .. name)
	else
		failures += 1
		print("FAIL " .. name)
	end
end

local cases: { { number | string } } = {
	{ 0, "0" },
	{ 12, "12" },
	{ 100, "100" },
	{ 300, "300" },
	{ 999, "999" },
	{ 1000, "1.00K" },
	{ 1234, "1.23K" },
	{ 12345, "12.3K" },
	{ 123456, "123K" },
	{ 999950, "1.00M" }, -- the rollover case: never "1000K"
	{ 3400000000, "3.40B" },
	{ 5600000000000, "5.60T" },
	{ 7800000000000000, "7.80aa" },
	{ 35800000000000000000, "35.8ab" },
	{ -1234, "-1.23K" },
}
for _, case in cases do
	local value, expected = case[1] :: number, case[2] :: string
	check(("%d formats as %s"):format(value, expected), NumberFormat.format(value) == expected)
end
check("a fraction is floored below 1000", NumberFormat.format(12.9) == "12")
check("nan is zero", NumberFormat.format(0 / 0) == "0")
check("infinity is zero", NumberFormat.format(math.huge) == "0")

check("small numbers are white", NumberFormat.tier(12) == "white" and NumberFormat.tier(999) == "white")
check("thousands are gold", NumberFormat.tier(1000) == "gold" and NumberFormat.tier(999999) == "gold")
check("millions are purple", NumberFormat.tier(1000000) == "purple" and NumberFormat.tier(4.7e9) == "purple")
check("bad numbers are white", NumberFormat.tier(0 / 0) == "white")

check("bigger numbers get bigger text", NumberFormat.sizeScale(1000000) > NumberFormat.sizeScale(100))
check("the text size is limited", NumberFormat.sizeScale(1e30) <= 1.8 and NumberFormat.sizeScale(1) >= 1)
check("bad numbers get normal size", NumberFormat.sizeScale(0 / 0) == 1)

if failures > 0 then
	error(failures .. " test(s) failed")
end
print("All tests passed")
