--!strict
-- PLACEHOLDER for the real ProfileStore module (session-locked saving).
-- In Studio this is an in-memory mock with the same calls, so the game runs. Data lasts only for the
-- Studio session. OUTSIDE Studio it errors on purpose, so a published game can never pretend to save.
--
-- To get real saving: replace this file with MadStudioRoblox's ProfileStore
-- (https://github.com/MadStudioRoblox/ProfileStore), keep its licence text in the repo, then check the calls
-- used by DataService.luau still match its API (StartSessionAsync, Reconcile, AddUserId, EndSession,
-- OnSessionEnd). Then playtest a rejoin in a scratch place with live stores.

local RunService = game:GetService("RunService")

type Callback = () -> ()

export type Profile = {
	Data: { [string]: any },
	Reconcile: (self: Profile) -> (),
	AddUserId: (self: Profile, userId: number) -> (),
	EndSession: (self: Profile) -> (),
	OnSessionEnd: { Connect: (self: any, callback: Callback) -> () },
}

export type Store = {
	StartSessionAsync: (self: Store, key: string, params: any?) -> Profile?,
}

local ProfileStore = {}

function ProfileStore.New(_name: string, template: { [string]: any }): Store
	if not RunService:IsStudio() then
		error("ProfileStore.luau is a placeholder. Vendor the real module before publishing (see docs/DATA.md).")
	end

	local saved: { [string]: { [string]: any } } = {}
	local active: { [string]: boolean } = {}

	local store = {}
	function store.StartSessionAsync(_self: Store, key: string, _params: any?): Profile?
		if active[key] then
			return nil -- already loaded in this session, like a held session lock
		end
		active[key] = true
		local data = saved[key]
		if data == nil then
			data = {}
			saved[key] = data
		end
		local callbacks: { Callback } = {}
		local profile = {} :: Profile
		profile.Data = data
		function profile.Reconcile(self: Profile)
			for field, value in template do
				if self.Data[field] == nil then
					self.Data[field] = value
				end
			end
		end
		function profile.AddUserId(_self: Profile, _userId: number) end
		function profile.EndSession(_self: Profile)
			active[key] = false
			for _, callback in callbacks do
				callback()
			end
		end
		profile.OnSessionEnd = {
			Connect = function(_self: any, callback: Callback)
				table.insert(callbacks, callback)
			end,
		}
		return profile
	end
	return store :: Store
end

return ProfileStore
