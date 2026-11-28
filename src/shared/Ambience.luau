--!strict
-- Ambient sound ids for each territory now come from Sounds.luau (the one place for every sound id). This file only forwards them,
-- so the places keep reading Ambience.<territory id>.

local Sounds = require(script.Parent:WaitForChild("Sounds"))

local Ambience = {
	npc_village = Sounds.ambientFor("npc_village"),
	brainrot_bog = Sounds.ambientFor("brainrot_bog"),
	cooked_canyon = Sounds.ambientFor("cooked_canyon"),
	rizz_ravine = Sounds.ambientFor("rizz_ravine"),
	locked_in_lighthouse = Sounds.ambientFor("locked_in_lighthouse"),
	gigachad_gate = Sounds.ambientFor("gigachad_gate"),
	chud_chambers = Sounds.ambientFor("chud_chambers"),
	moments = { rizz_heart = "", geyser = "", gate_flex = "", brain_pulse = "", stare = "", lamp = "" },
}

return Ambience
