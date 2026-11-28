-- PISTOL DUELS | Skin Changer + legit menu, on Meowthjrlib  |  made by meowthjr & Claude
--
-- Meowthjrlib draws the window. Everything here is local to your own client:
--   Skins      one box per weapon: skin, pattern, wear, tint, ammo FX, re-equip
--   Effects    bullet tracers on your own shots, weapon spin
--   Boost      lower graphics, FPS cap, lighter world
--   Display    stretched resolution, key viewer, watermark, FPS and ping
--   World      color looks, glow, sun rays
--   Camera     motion blur, field of view, gun size and position
--   Legit      silent aim, triggerbot, no recoil, aim assist
--   Rage       ragebot, rapid fire, spinbot, third person, air steering
--   ESP        boxes, skeleton, labels, radar, chams
--   Incognito  local-only names, stats and avatar
--   Misc       auto slide on jump, free cursor, server hop, auto load
--
-- Keys, window size, theme, accent, profiles, search and the on-screen widgets all come from
-- Meowthjrlib, so the script carries no settings pages and no save file of its own.

pcall(function() game:GetService("RunService"):UnbindFromRenderStep("PDSkinChangerPlayers") end)
if _G.PistolDuelsSkinChanger and _G.PistolDuelsSkinChanger.unload then pcall(_G.PistolDuelsSkinChanger.unload) end

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local lp = Players.LocalPlayer
local function requireGame(module: Instance): any
	assert(module:IsA("ModuleScript"), "Expected a game ModuleScript")
	return require(module)
end

local ui                      -- the Meowthjrlib window, made near the bottom
local alive = true
local conns = {}
local function keep(c) conns[#conns + 1] = c; return c end
local function menuOpen() return ui ~= nil and ui.Open == true end
local function setStatus(t) if ui then ui:Notify("Pistol Duels", t, 4) end end
local function save() if ui and ui._started then pcall(function() ui:SaveNow() end) end end

local privacy = { on = false, ready = false, values = {
	username = "Player", displayName = "Player", avatarId = 1,
	streak = 0, level = 1, coins = 0, cash = 0, ping = 0,
	server = 0, serverId = "Hidden", region = "Hidden", xp = 0, xpTotal = 0,
} }

-- online counter: while the script runs it pings the counter every 30 seconds with a random id made up for
-- this run, a random id kept on this PC (so switching servers doesn't count you twice) and the number of the
-- server you're in with its region. Active pings also share your Roblox username on the public counter.
local onlineGone = function() end
local serverHop
do
	local ONLINE_URL = "https://pd-online.meowthjr.workers.dev"
	local ID_FILE = "pistol_duels_online_id.txt"
	local send = (type(request) == "function" and request)
		or (type(http_request) == "function" and http_request)
		or (type(syn) == "table" and type(syn.request) == "function" and syn.request)
		or (type(http) == "table" and type(http.request) == "function" and http.request)
	if send and ONLINE_URL ~= "" then
		local runId = HttpService:GenerateGUID(false)
		local userId
		pcall(function()
			if type(isfile) == "function" and isfile(ID_FILE) then userId = string.match(readfile(ID_FILE), "%x+%-%x+%-%x+%-%x+%-%x+") end
			if not userId and type(writefile) == "function" then userId = HttpService:GenerateGUID(false); writefile(ID_FILE, userId) end
		end)
		local server, region, lobby
		local serverList, listVersion = {}, 0
		local function askServer()
			if not lobby and type(getgc) == "function" then
				for _, v in ipairs(getgc(true)) do
					if type(v) == "table" and rawget(v, "duels") ~= nil and rawget(v, "state") ~= nil and rawget(v, "movement") ~= nil then
						local r = rawget(v, "remotes")
						lobby = type(r) == "table" and r.Lobby or nil
						break
					end
				end
				if lobby then
					keep(lobby.OnClientEvent:Connect(function(msg)
						if type(msg) ~= "table" or msg.kind ~= "Servers" or type(msg.servers) ~= "table" then return end
						serverList = msg.servers
						listVersion += 1
						for _, s in ipairs(serverList) do
							if type(s) == "table" and (s.current == true or s.id == game.JobId) then
								server, region = tonumber(s.number), type(s.region) == "string" and s.region or nil
							end
						end
					end))
				end
			end
			if lobby then pcall(function() lobby:FireServer({ kind = "Servers" }) end) end
		end
		serverHop = function(number)
			local version = listVersion
			askServer()
			if not lobby then return "Server list unavailable." end
			local deadline = os.clock() + 5
			while alive and version == listVersion and os.clock() < deadline do task.wait(0.1) end
			if not alive or version == listVersion then return "Server list did not respond." end
			for _, entry in ipairs(serverList) do
				if type(entry) == "table" and tonumber(entry.number) == number then
					if entry.current or entry.id == game.JobId then return "Already in that server." end
					if type(entry.id) ~= "string" or entry.id == "" then return "Server cannot be joined." end
					game:GetService("TeleportService"):TeleportToPlaceInstance(game.PlaceId, entry.id, lp)
					return "Joining server #" .. number .. "..."
				end
			end
			return "Server #" .. number .. " was not found."
		end
		local function ping(gone)
			if not gone and (not privacy.ready or privacy.on) then return end
			pcall(send, {
				Url = ONLINE_URL .. "/ping", Method = "POST", Headers = { ["Content-Type"] = "application/json" },
				Body = HttpService:JSONEncode({ id = runId, user = userId, gone = gone or nil, server = server, region = region, username = not gone and lp.Name or nil }),
			})
		end
		task.spawn(function()
			local beats = 0
			while alive do
				if beats % 20 == 0 then
					pcall(askServer)
					local t0 = os.clock()
					while alive and not server and os.clock() - t0 < 5 do task.wait(0.2) end
				end
				beats += 1
				ping(false)
				task.wait(30)
			end
		end)
		onlineGone = function() task.spawn(ping, true) end
	end
end

-- the game's modules can only be required from a thread with identity 2 (executors run at 8), so anything that
-- touches them goes through g(): it runs the function in such a thread, waits for it, and returns pcall's results
local setIdentity = (type(setthreadidentity) == "function" and setthreadidentity)
	or (type(rawget(getfenv(), "set_thread_identity")) == "function" and rawget(getfenv(), "set_thread_identity"))
	or (type(rawget(getfenv(), "setidentity")) == "function" and rawget(getfenv(), "setidentity"))
	or (type(setthreadcontext) == "function" and setthreadcontext)
	or (type(syn) == "table" and type(rawget(syn, "set_thread_identity")) == "function" and rawget(syn, "set_thread_identity"))
	or nil
local function g(fn, ...)
	local args, res, done = table.pack(...), nil, false
	task.spawn(function()
		if setIdentity then pcall(setIdentity, 2) end
		res = table.pack(pcall(fn, table.unpack(args, 1, args.n)))
		done = true
	end)
	local t = os.clock()
	while not done and os.clock() - t < 5 do task.wait() end
	if not res then return false, "timed out" end
	return table.unpack(res, 1, res.n)
end

local SkinCatalog, WM, FC, CE
g(function()
	local cos = RS:FindFirstChild("Cosmetics")
	if not cos then return end
	SkinCatalog = requireGame(cos.SkinCatalog)
	WM = requireGame(cos.WeaponModel)
	pcall(function() FC = requireGame(lp.PlayerScripts.Client.Cosmetics.FinishClient) end)
	pcall(function() CE = requireGame(lp.PlayerScripts.Client.Effects.CosmeticEffects) end)
end)
if not (SkinCatalog and WM) then
	local cos = RS:FindFirstChild("Cosmetics")
	if cos and cos:FindFirstChild("SkinCatalog") then
		warn("[SkinChanger] Your executor can't run the game's own scripts" .. (setIdentity and "" or " (it has no setthreadidentity)")
			.. ", which this script needs. Nothing was changed.")
	else
		warn("[SkinChanger] This doesn't look like Pistol Duels (its skin scripts were not found), so nothing was changed.")
	end
	return
end

local Lib
do
	local URL = "https://raw.githubusercontent.com/Emmauwuuwu/Meowthjrlib/main/Meowthjrlib.lua"
	local ok, res = pcall(function() return loadstring(game:HttpGet(URL))() end)
	if not ok or type(res) ~= "table" then
		ok, res = pcall(function()
			assert(type(isfile) == "function" and isfile("Meowthjrlib.lua"), "no local copy")
			return loadstring(readfile("Meowthjrlib.lua"))()
		end)
	end
	if not ok or type(res) ~= "table" then
		warn("[SkinChanger] Meowthjrlib could not be loaded (" .. tostring(res) .. "), so nothing was changed.")
		return
	end
	Lib = res
end

-- ===================== runtime state =====================
-- Every value below is written by a Meowthjrlib callback and read by the logic, so the logic itself is
-- unchanged and Meowthjrlib's profiles are the only place settings are saved.
local sel, pat, wear = {}, {}, {}
local sa = { triggerCooldown = 0.15, incognito = false, ragebot = false, triggerbot = false, rapidFire = false, noRecoil = false,
	airOn = false, airResponse = 8, disableInLobby = true, spinOn = false, spinSpeed = 1440, thirdPerson = false, thirdDistance = 10,
	esp = { enabled = false, box = false, boxMode = "2D", names = false, distance = false, health = false, healthMode = "Both",
		tracers = false, chams = false, glow = false, snaplines = false, weapon = false, teamColor = false, visibility = false,
		arrows = false, radar = false, fov = false, velocity = false, hitboxes = false, status = false, target = false,
		throughWalls = true, tracerOrigin = "Bottom", snapOrigin = "Center", color = "Accent", unifiedColor = true,
		hiddenColor = "Red", maxDistance = 1500, textSize = 13, font = "Gotham", backplates = true, chamsOpacity = 0.45,
		fovRadius = 150, radarRange = 200, radarSize = 180, targetUserId = 0, skeleton = true, headDot = true, hideTeam = true,
		practice = true, thickness = 1.5, dotRadius = 3 },
	targetMode = "Closest Part", headWeight = 20, bodyWeight = 50, limbWeight = 30, cameraHead = false, cameraRadius = 80,
	cameraShowFov = true, cameraOn = false, cameraSmooth = true, cameraSpeed = 8, cameraHold = "MouseButton2",
	showFov = true, radius = 120, on = false, range = 250, players = true, npcs = true, head = false }
function sa.lobbyBlocked() return false end   -- replaced once the combat controller is found
local hideArms = false
local freeCursor = false
local tr = { on = false, color = "Cyan", thick = 0.12, life = 0.6, glow = true, streak = false, replace = true }
local spin = { on = false, speed = 180, dir = 1, axis = "Y", mode = "Continuous" }
local st = { on = false, amount = 0.35 }
local wd = { on = false, preset = "Natural", tint = 1, sat = 0, con = 0, dark = 0, bloom = 0, rays = 0 }
local mb = { on = false, strength = 12, threshold = 120, smooth = 0.12 }
local vm = { on = false, fov = 0, size = 1, x = 0, y = 0, z = 0 }
local opt = { on = false, cap = 240, quality = 3, post = true, particles = true, textures = false, plain = false }
local tints = {}
local ammoFx = {}
local shuffle = { on = false }
local slideJump = { on = false }
local autoLoad = { on = false }
local function tintOf(w)
	if not tints[w] then tints[w] = { on = false, color = "Cyan", strength = 0.45 } end
	return tints[w]
end

-- ===================== skin lists =====================
local weapons, skinsOf, displayOf, byId = {}, {}, {}, {}
g(function()
	local RANK = { Secret = 1, Exclusive = 2, Knife = 3, Legendary = 4, Epic = 5, Rare = 6, Uncommon = 7 }
	local order = type(SkinCatalog.WeaponOrder) == "table" and SkinCatalog.WeaponOrder or { "Glock", "Tec9", "Deagle", "Knife" }
	local names = type(SkinCatalog.WeaponNames) == "table" and SkinCatalog.WeaponNames or {}
	for _, w in ipairs(order) do
		local list = {}
		for id, it in pairs(SkinCatalog.Items) do
			if it.weapon == w and not it.standard then
				-- skins only staff can be given are listed too, marked Staff and kept at the end of the list
				local staff = it.adminOnly == true or string.find(tostring(id), "^admin_") ~= nil
				local s = {
					id = id, display = it.name or id, rarity = staff and "Staff" or tostring(it.rarity or ""),
					patterned = it.procedural ~= nil, weapon = w, staff = staff,
					exclusiveFx = type(it.exclusiveFx) == "string" and it.exclusiveFx or nil,
				}
				list[#list + 1] = s
				byId[id] = s
			end
		end
		table.sort(list, function(a, b)
			local ra, rb = a.staff and 100 or RANK[a.rarity] or 99, b.staff and 100 or RANK[b.rarity] or 99
			if ra ~= rb then return ra < rb end
			return string.lower(a.display) < string.lower(b.display)
		end)
		skinsOf[w] = list
		weapons[#weapons + 1] = w
		displayOf[w] = names[w] or w
	end
end)
if #weapons == 0 then warn("[SkinChanger] Found no weapons in the skin catalog, so nothing was changed."); return end

local function clampPat(n) return math.clamp(math.floor((tonumber(n) or 1) + 0.5), 1, 1000) end
local function clampWear(n) return math.clamp(tonumber(n) or 0, 0, 1) end

-- ===================== the hooks =====================
-- The game builds your gun in one place (CombatController's "model" function). We only swap the skin there, so
-- the inventory, the inspect screen, trades and the final-kill replay keep showing the real thing.
local hits = 0
local function fromCombat()
	local tb = debug.traceback("", 3)
	return string.find(tb, "CombatController:%d+ function model") ~= nil
end

local origCreateAnimated, origCreate, origBind = WM.createAnimated, WM.create, FC and FC.bind
local wrapCA, wrapC, wrapBind

-- Shuffle: each time the game builds your weapon a random skin is rolled. The game makes a few calls per build,
-- so calls close together share one roll.
local rolled, rollAt = {}, {}
local function pickFor(w)
	if not shuffle.on then return sel[w], pat[w], wear[w] end
	local now = os.clock()
	if not rolled[w] or now - (rollAt[w] or 0) > 0.5 then
		local from = {}
		for _, s in ipairs(skinsOf[w] or {}) do
			if not s.staff then from[#from + 1] = s end
		end
		local s = from[math.random(1, math.max(#from, 1))]
		rolled[w] = s and { id = s.id, pat = math.random(1, 1000), wear = math.random() * 0.4 } or nil
	end
	rollAt[w] = now
	local r = rolled[w]
	if r then return r.id, r.pat, r.wear end
	return sel[w], pat[w], wear[w]
end

wrapCA = function(weapon, skinId, ...)
	if (sel[weapon] or shuffle.on) and fromCombat() then
		local want = pickFor(weapon)
		if want then hits += 1; skinId = want end
	end
	return origCreateAnimated(weapon, skinId, ...)
end
wrapC = function(weapon, flag, skinId, ...)
	if (sel[weapon] or shuffle.on) and fromCombat() then
		local want = pickFor(weapon)
		if want then skinId = want end
	end
	return origCreate(weapon, flag, skinId, ...)
end
if origBind then
	wrapBind = function(model, item, dist, opts, ...)
		if typeof(model) == "Instance" and type(opts) == "table" and opts.fullDetail and not opts.transient then
			local w = string.match(model.Name, "^PD_(.+)$")
			if w and (sel[w] or shuffle.on) and fromCombat() then
				local id, p, we = pickFor(w)
				if id then item = { skinId = id, pattern = p or 1, wear = we or 0 } end
			end
		end
		return origBind(model, item, dist, opts, ...)
	end
end
g(function()
	WM.createAnimated = wrapCA
	WM.create = wrapC
	if wrapBind then FC.bind = wrapBind end
end)

-- ===================== re-equip =====================
-- Switching to the other slot and back makes the game build your weapon again, which is when the skin is swapped in.
local function heldModel()
	local cam = workspace.CurrentCamera
	if not cam then return nil end
	local fallback, fallbackW
	for _, c in ipairs(cam:GetChildren()) do
		if c:IsA("Model") then
			local w = string.match(c.Name, "^PD_(.+)$")
			if w then
				if c:GetAttribute("PDSkinId") ~= nil then return c, w end   -- the real viewmodel carries its skin id
				fallback, fallbackW = fallback or c, fallbackW or w
			end
		end
	end
	return fallback, fallbackW
end
local reEquip
do
local reEquipping = false
function reEquip()
	if reEquipping then return false end
	local _, w = heldModel()
	if not w then return false end
	local ok, VIM = pcall(function() return game:GetService("VirtualInputManager") end)
	if not ok then return false end
	local function tap(key)
		VIM:SendKeyEvent(true, key, false, game)
		task.wait(0.06)
		VIM:SendKeyEvent(false, key, false, game)
	end
	reEquipping = true
	local isKnife = (w == "Knife")
	-- press a key and wait until the weapon in your hands really changes (one retry if the game ignored the press)
	local function switchTo(key, wantKnife)
		for _ = 1, 2 do
			tap(key)
			local t = os.clock()
			while os.clock() - t < 1.2 do
				local _, now = heldModel()
				if now ~= nil and (now == "Knife") == wantKnife then task.wait(0.25); return true end
				task.wait(0.05)
			end
		end
		return false
	end
	local ok2, res = pcall(function()
		if not switchTo(isKnife and Enum.KeyCode.One or Enum.KeyCode.Two, not isKnife) then return false end
		return switchTo(isKnife and Enum.KeyCode.Two or Enum.KeyCode.One, isKnife)
	end)
	reEquipping = false
	return ok2 and res == true
end
end

-- ===================== invisible arms =====================
-- Hides the arms of your viewmodel so they don't cover the skin. Done every frame (after the game's own update)
-- because the game keeps setting the arm transparency itself.
local TweenService = game:GetService("TweenService")
local armOrig = setmetatable({}, { __mode = "k" })
local trackedModels = setmetatable({}, { __mode = "k" })
local function isArmPart(p)
	if not p:IsA("BasePart") then return false end
	if p:FindFirstAncestor("AvatarArms") then return true end
	local n = string.lower(p.Name)
	if string.find(n, "^left") or string.find(n, "^right") then
		return string.find(n, "arm", 1, true) or string.find(n, "hand", 1, true) or string.find(n, "glove", 1, true)
			or string.find(n, "sleeve", 1, true) or false
	end
	return false
end
local function track(model)
	if trackedModels[model] then return trackedModels[model] end
	local rec = { parts = {} }
	trackedModels[model] = rec
	local function consider(d) if isArmPart(d) then rec.parts[d] = true end end
	consider(model)
	for _, d in ipairs(model:GetDescendants()) do consider(d) end
	keep(model.DescendantAdded:Connect(consider))
	return rec
end
local function enforceArms()
	if not hideArms then return end
	local cam = workspace.CurrentCamera
	if not cam then return end
	for _, c in ipairs(cam:GetChildren()) do
		if string.find(c.Name, "^PD_") or c.Name == "AvatarArms" then
			local rec = track(c)
			for p in pairs(rec.parts) do
				if p.Parent then
					if armOrig[p] == nil then armOrig[p] = p.Transparency end
					if p.Transparency ~= 1 then p.Transparency = 1 end
				else
					rec.parts[p] = nil
				end
			end
		end
	end
end
local function restoreArms()
	for _, rec in pairs(trackedModels) do
		for p in pairs(rec.parts) do
			local o = armOrig[p]
			if o ~= nil and p.Parent then p.Transparency = o end
		end
	end
end
do local okB, eB = pcall(function() RunService:BindToRenderStep("PDSkinChangerArms", Enum.RenderPriority.Last.Value, enforceArms) end); if not okB then warn("[SkinChanger] could not start PDSkinChangerArms: " .. tostring(eB)) end end

-- ===================== free cursor =====================
local function enforceCursor()
	if not freeCursor then return end
	UIS.MouseBehavior = Enum.MouseBehavior.Default
	UIS.MouseIconEnabled = true
end
do local okB, eB = pcall(function() RunService:BindToRenderStep("PDSkinChangerCursor", Enum.RenderPriority.Last.Value + 1, enforceCursor) end); if not okB then warn("[SkinChanger] could not start PDSkinChangerCursor: " .. tostring(eB)) end end

-- ===================== tracers =====================
-- Draws a glowing beam from your gun to where each of YOUR shots lands. Other players' shots are never touched.
local TRACER_COLORS = {
	Cyan = Color3.fromRGB(80, 220, 255), Pink = Color3.fromRGB(255, 105, 200), Gold = Color3.fromRGB(255, 205, 80),
	Green = Color3.fromRGB(100, 255, 140), Red = Color3.fromRGB(255, 80, 80), White = Color3.fromRGB(255, 255, 255),
	Purple = Color3.fromRGB(170, 110, 255),
}
local COLOR_ORDER = { "Cyan", "Pink", "Gold", "Green", "Red", "White", "Purple", "Rainbow" }
local pool, active = {}, {}
local spawnTracer, stepTracers, recycle
do
local terrain = workspace.Terrain
local MAX_TRACERS = 30
local function newTracer()
	local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
	a0.Parent = terrain; a1.Parent = terrain
	local function beam()
		local b = Instance.new("Beam")
		b.Attachment0 = a0; b.Attachment1 = a1; b.FaceCamera = true; b.LightEmission = 1; b.LightInfluence = 0
		b.Segments = 1; b.Enabled = false; b.Parent = terrain
		return b
	end
	return { a0 = a0, a1 = a1, core = beam(), glow = beam() }
end
function recycle(t)
	t.core.Enabled = false; t.glow.Enabled = false
	pool[#pool + 1] = t
end
function spawnTracer(from, to)
	if #active >= MAX_TRACERS then recycle(table.remove(active, 1)) end
	local t = table.remove(pool) or newTracer()
	local col = tr.color == "Rainbow" and Color3.fromHSV((os.clock() * 0.7) % 1, 0.85, 1) or TRACER_COLORS[tr.color] or TRACER_COLORS.Cyan
	t.from, t.to, t.born, t.life, t.streak, t.thick = from, to, os.clock(), math.max(tr.life, 0.05), tr.streak, tr.thick
	t.core.Color = ColorSequence.new(col); t.glow.Color = ColorSequence.new(col)
	t.core.Transparency = NumberSequence.new(0); t.glow.Transparency = NumberSequence.new(0.55)
	t.core.Width0, t.core.Width1 = tr.thick, tr.thick
	t.glow.Width0, t.glow.Width1 = tr.thick * 3.2, tr.thick * 3.2
	t.a0.WorldPosition = from; t.a1.WorldPosition = to
	t.core.Enabled = true; t.glow.Enabled = tr.glow
	active[#active + 1] = t
end
function stepTracers()
	local now = os.clock()
	for i = #active, 1, -1 do
		local t = active[i]
		local p = (now - t.born) / t.life
		if p >= 1 then
			recycle(t); table.remove(active, i)
		else
			local tp
			if t.streak then
				local dir = t.to - t.from
				local head = math.clamp(p / 0.45, 0, 1)
				local tail = math.clamp(head - 0.22, 0, 1) + (p > 0.45 and (p - 0.45) / 0.55 * 0.22 or 0)
				t.a0.WorldPosition = t.from + dir * math.min(tail, 1)
				t.a1.WorldPosition = t.from + dir * head
				tp = math.max(0, (p - 0.7) / 0.3) ^ 2
			else
				tp = p ^ 1.6
			end
			local w = t.thick * (1 - 0.6 * p)
			t.core.Width0, t.core.Width1 = w, w
			t.glow.Width0, t.glow.Width1 = w * 3.2, w * 3.2
			t.core.Transparency = NumberSequence.new(tp)
			t.glow.Transparency = NumberSequence.new(0.55 + 0.45 * tp)
		end
	end
end
end

local fxApi = {}
do
local origShot, wrapShot
if CE and type(CE.shot) == "function" then
	origShot = CE.shot
	wrapShot = function(origin, endpoint, a3, a4, a5, muzzle, a7, ...)
		local skip = false
		if tr.on then
			local ok, res = pcall(function()
				local cam = workspace.CurrentCamera
				if typeof(origin) == "Vector3" and typeof(endpoint) == "Vector3" and typeof(muzzle) == "Instance"
					and cam and muzzle:IsDescendantOf(cam) then   -- only shots from YOUR viewmodel
					local from = origin
					if muzzle:IsA("Attachment") then from = muzzle.WorldPosition end
					spawnTracer(from, endpoint)
					return tr.replace
				end
				return false
			end)
			skip = ok and res == true
		end
		if skip then return end
		return origShot(origin, endpoint, a3, a4, a5, muzzle, a7, ...)
	end
	g(function() CE.shot = wrapShot end)
end
fxApi.unshot = function() if CE and wrapShot and CE.shot == wrapShot then CE.shot = origShot end end
end

-- ===================== ammo FX =====================
-- The game asks its inventory which FX the weapon in your hands has, and uses the answer only for the effects on
-- your own screen (the shot it sends the server has no FX in it). Answering with the one picked here changes how
-- your shots look to you, and nothing else.
do
local FXC
g(function() FXC = requireGame(RS.Cosmetics.AmmoFXCatalog) end)
fxApi.color = function(id) return FXC and FXC.color(id) end
local FX_ORDER = { "Red", "Orange", "Yellow", "Green", "Cyan", "Blue", "Purple", "Pink", "White", "Black", "Prism", "Bloxxed" }
local fxCombat, fxCol, nextFxFind = nil, nil, 0
local function fxName(id)
	if id == nil then return "Your own" elseif id == "None" then return "No FX" end
	return FXC and FXC.name(id) or id
end
fxApi.order, fxApi.name = FX_ORDER, fxName
-- the FX a weapon gets: the one picked here, else the one that comes with its skin (the Linked Sword's Bloxxed)
local function pickOf(w)
	if ammoFx[w] then return ammoFx[w] end
	local id = (shuffle.on and rolled[w] and rolled[w].id) or sel[w]
	return id and byId[id] and byId[id].exclusiveFx or nil
end
local function hookFx()
	if fxCol then return true end
	if os.clock() < nextFxFind or type(getgc) ~= "function" then return false end
	nextFxFind = os.clock() + 5
	for _, v in ipairs(getgc(true)) do
		if type(v) == "table" and rawget(v, "duels") ~= nil and rawget(v, "state") ~= nil and rawget(v, "movement") ~= nil then
			local col = rawget(v, "collection")
			local mt = type(col) == "table" and getmetatable(col)
			local orig = mt and type(mt.__index) == "table" and mt.__index.fx
			if type(orig) == "function" then
				fxCombat, fxCol = v, col
				rawset(col, "fx", function(self, w)
					local pick = pickOf(w)
					if pick == "None" then return nil end
					if pick and pick ~= "Bloxxed" then return pick end   -- Bloxxed is a kill effect only (see wrapDeath)
					return orig(self, w)
				end)
				return true
			end
		end
	end
	return false
end
hookFx()
keep(RunService.Heartbeat:Connect(function() if not fxCol then hookFx() end end))
local origDeath, wrapDeath
if CE and type(CE.death) == "function" then
	origDeath = CE.death
	wrapDeath = function(fx, ...)
		if select("#", ...) == 0 and type(fx) == "table" and fxCombat then   -- one argument = a kill confirmed for your shot
			local s = rawget(fxCombat, "state")
			local pick = type(s) == "table" and pickOf(s.knife and "Knife" or s.preset)
			if pick then
				local copy = table.clone(fx)
				copy.kind = (pick == "None") and "Default" or pick
				return origDeath(copy)
			end
		end
		return origDeath(fx, ...)
	end
	g(function() CE.death = wrapDeath end)
end
function fxApi.unhook()
	g(function() if CE and wrapDeath and CE.death == wrapDeath then CE.death = origDeath end end)
	if fxCol then rawset(fxCol, "fx", nil) end
end
end

-- ===================== weapon spin =====================
-- Turns only the gun in YOUR view, after the game has placed it each frame. Nothing else is affected.
local stepSpin, stepViewmodel
do
local spinAngle, spinModel, spinEquip, spinLast = 0, nil, 0, os.clock()
local AXES = { X = Vector3.xAxis, Y = Vector3.yAxis, Z = Vector3.zAxis }
local function gunCenter(m)
	local sum, n = Vector3.zero, 0
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("BasePart") and d.Name ~= "HumanoidRootPart" and not isArmPart(d) and d.Transparency < 1 then
			sum += d.Position; n += 1
		end
	end
	return n > 0 and sum / n or m:GetPivot().Position
end
function stepSpin()
	local now = os.clock()
	local dt = math.min(now - spinLast, 0.1)
	spinLast = now
	if not spin.on then return end
	local cam = workspace.CurrentCamera
	local m = heldModel()
	if not (cam and m) then return end
	if m ~= spinModel then spinModel = m; spinAngle = 0; spinEquip = now end
	local ang
	if spin.mode == "Swing" then
		ang = 60 * math.sin(math.rad(spin.speed) * (now - spinEquip) * 0.5) * spin.dir
	elseif spin.mode == "On equip" then
		local dur = math.max(360 / math.max(spin.speed, 1), 0.25)
		local p = math.clamp((now - spinEquip) / dur, 0, 1)
		ang = 360 * (1 - (1 - p) ^ 3) * spin.dir
	else
		spinAngle = (spinAngle + spin.speed * spin.dir * dt) % 360
		ang = spinAngle
	end
	if math.abs(ang) < 0.01 or math.abs(ang % 360) < 0.01 then return end
	local center = gunCenter(m)
	local camRot = cam.CFrame.Rotation
	local worldRot = camRot * CFrame.fromAxisAngle(AXES[spin.axis] or Vector3.yAxis, math.rad(ang)) * camRot:Inverse()
	m:PivotTo(CFrame.new(center) * worldRot * CFrame.new(-center) * m:GetPivot())
end
end

-- ===================== gun size and position =====================
-- Resizes and moves the gun (and arms) in YOUR view after the game has placed it. The game puts it back every
-- frame, so the offset never adds up. ScaleTo grows the model around its root, which sits at your eye, so a
-- bigger gun is slid back to keep its middle where the game put it.
function stepViewmodel()
	local cam = workspace.CurrentCamera
	local m = heldModel()
	if not (cam and m) then return end
	local s = vm.on and math.clamp(vm.size, 0.5, 2) or 1
	if math.abs(m:GetScale() - s) > 1e-3 then m:ScaleTo(s) end
	local root = m.PrimaryPart
	if s ~= 1 and root then
		local sum, n = Vector3.zero, 0
		for _, d in ipairs(m:GetDescendants()) do
			if d:IsA("BasePart") and d ~= root and not isArmPart(d) then sum += d.Position; n += 1 end
		end
		if n > 0 then
			local c1, o = sum / n, root.Position
			m:PivotTo(m:GetPivot() + ((o + (c1 - o) / s) - c1))
		end
	end
	if vm.on and (vm.x ~= 0 or vm.y ~= 0 or vm.z ~= 0) then
		local camCF = cam.CFrame
		m:PivotTo(camCF * CFrame.new(vm.x, vm.y, -vm.z) * camCF:ToObjectSpace(m:GetPivot()))
	end
end

local fxWarned = {}
local function guarded(name, fn)
	local ok, e = pcall(fn)
	if not ok and not fxWarned[name] then fxWarned[name] = true; warn("[SkinChanger] " .. name .. " error: " .. tostring(e)) end
end
-- the game's ammo FX coats were put on the rounds before the gun is moved or spun here: move the ones on the gun
-- along with it, so they don't stay behind where the game had put the gun
local stepFx
do
local function followCoats(m, before)
	local after = m:GetPivot()
	if after == before then return end
	local folder = workspace:FindFirstChild("PDAmmoFX")
	if not folder then return end
	local delta = after * before:Inverse()
	local cf, size = m:GetBoundingBox()
	local was, half = delta:Inverse() * cf, size / 2 + Vector3.new(0.3, 0.3, 0.3)
	for _, c in ipairs(folder:GetChildren()) do
		if c:IsA("BasePart") then
			local p = was:PointToObjectSpace(c.Position)
			if math.abs(p.X) <= half.X and math.abs(p.Y) <= half.Y and math.abs(p.Z) <= half.Z then c.CFrame = delta * c.CFrame end
		end
	end
end
function stepFx()
	guarded("tracers", stepTracers)
	local m = (vm.on or spin.on) and heldModel()
	local before = m and m:GetPivot()
	guarded("gun position", stepViewmodel); guarded("spin", stepSpin)
	if before then guarded("ammo fx", function() followCoats(m, before) end) end
end
end
do local okB, eB = pcall(function() RunService:BindToRenderStep("PDSkinChangerFx", Enum.RenderPriority.Last.Value + 2, stepFx) end); if not okB then warn("[SkinChanger] could not start PDSkinChangerFx: " .. tostring(eB)) end end

-- ===================== stretched resolution and field of view =====================
-- Flattens your camera vertically so everything looks wider, like a stretched resolution. The stretch is taken
-- off again right before the game's camera code runs each frame, so the game never sees it. Field of view works
-- the same way: added on top of the game's own value, so zooming in still works.
local unstretch, unFov
do
local stretchedCF, cleanCF = nil, nil
function unstretch()
	local cam = workspace.CurrentCamera
	if stretchedCF and cam and cam.CFrame == stretchedCF then cam.CFrame = cleanCF end
	stretchedCF, cleanCF = nil, nil
end
local function applyStretch()
	local cam = workspace.CurrentCamera
	if not (cam and st.on) then return end
	cleanCF = cam.CFrame
	stretchedCF = cleanCF * CFrame.new(0, 0, 0, 1, 0, 0, 0, 1 - math.clamp(st.amount, 0, 0.7), 0, 0, 0, 1)
	cam.CFrame = stretchedCF
end
local fovSet, fovClean = nil, nil
function unFov()
	local cam = workspace.CurrentCamera
	if fovSet and cam and math.abs(cam.FieldOfView - fovSet) < 1e-3 then cam.FieldOfView = fovClean end
	fovSet, fovClean = nil, nil
end
local function applyFov()
	local cam = workspace.CurrentCamera
	if not (cam and vm.on and vm.fov ~= 0) then return end
	fovClean = cam.FieldOfView
	fovSet = math.clamp(fovClean + vm.fov, 1, 120)
	cam.FieldOfView = fovSet
end
do local okB, eB = pcall(function() RunService:BindToRenderStep("PDSkinChangerStretchA", 1, function() unstretch(); unFov() end) end); if not okB then warn("[SkinChanger] could not start stretch: " .. tostring(eB)) end end
do local okB, eB = pcall(function() RunService:BindToRenderStep("PDSkinChangerStretchB", Enum.RenderPriority.Last.Value + 3, function(dt) if sa.cameraStep then guarded("aim assist", function() sa.cameraStep(dt) end) end; guarded("stretch", applyStretch); guarded("fov", applyFov) end) end); if not okB then warn("[SkinChanger] could not start stretch: " .. tostring(eB)) end end
end

-- ===================== motion blur =====================
-- Blurs your screen while you turn the camera fast and fades back to sharp when you stop.
local mbBlur
do
local mbLook, mbLast = nil, os.clock()
local function stepBlur()
	local now = os.clock()
	local dt = math.max(now - mbLast, 1 / 240)
	mbLast = now
	local cam = workspace.CurrentCamera
	if not (mb.on and cam) then
		if mbBlur then mbBlur.Enabled = false; mbBlur.Size = 0 end
		mbLook = nil
		return
	end
	if not mbBlur or not mbBlur.Parent then
		mbBlur = Instance.new("BlurEffect"); mbBlur.Name = "PDMotionBlur"; mbBlur.Size = 0; mbBlur.Parent = game:GetService("Lighting")
	end
	local look = cam.CFrame.LookVector
	local target = 0
	if mbLook then
		local ang = math.deg(math.acos(math.clamp(mbLook:Dot(look), -1, 1)))
		if ang < 60 then   -- a bigger jump in one frame is a camera cut (respawn, spectate), not you turning
			target = mb.strength * math.clamp((ang / dt - mb.threshold) / 540, 0, 1)
		end
	end
	mbLook = look
	local k = 1 - math.exp(-dt / math.max(mb.smooth, 0.01))
	mbBlur.Size = mbBlur.Size + (target - mbBlur.Size) * k
	mbBlur.Enabled = mbBlur.Size > 0.05
end
do local okB, eB = pcall(function() RunService:BindToRenderStep("PDSkinChangerBlur", Enum.RenderPriority.Camera.Value + 5, function() guarded("motion blur", stepBlur) end) end); if not okB then warn("[SkinChanger] could not start motion blur: " .. tostring(eB)) end end
end

-- ===================== world look =====================
-- Your own color grade, bloom and sun rays layered on top of the game's lighting. Local only.
local PRESETS = {
	{ id = "Natural", tint = Color3.fromRGB(255, 255, 255), sat = 0,    con = 0,    dark = 0,    bloom = 0,   rays = 0 },
	{ id = "Sunset",  tint = Color3.fromRGB(255, 190, 140), sat = 0.15, con = 0.08, dark = 0,    bloom = 0.4, rays = 0.15 },
	{ id = "Neon",    tint = Color3.fromRGB(170, 140, 255), sat = 0.35, con = 0.15, dark = 0.12, bloom = 1.0, rays = 0 },
	{ id = "Frost",   tint = Color3.fromRGB(170, 210, 255), sat = -0.1, con = 0.05, dark = 0,    bloom = 0.3, rays = 0 },
	{ id = "Mono",    tint = Color3.fromRGB(255, 255, 255), sat = -1,   con = 0.2,  dark = 0,    bloom = 0,   rays = 0 },
	{ id = "Vintage", tint = Color3.fromRGB(255, 225, 180), sat = -0.3, con = 0.1,  dark = 0.05, bloom = 0.2, rays = 0 },
	{ id = "Toxic",   tint = Color3.fromRGB(170, 255, 170), sat = 0.3,  con = 0.12, dark = 0.08, bloom = 0.6, rays = 0 },
	{ id = "Rose",    tint = Color3.fromRGB(255, 170, 205), sat = 0.2,  con = 0.06, dark = 0,    bloom = 0.5, rays = 0.1 },
}
local PRESET_BY = {}
for _, p in ipairs(PRESETS) do PRESET_BY[p.id] = p end
local wGrade, wBloom, wRays
local applyWorld, setPreset
do
local function worldGone(i) return not i or not i.Parent end
function applyWorld()
	local L = game:GetService("Lighting")
	if not wd.on then
		if wGrade then wGrade.Enabled = false end
		if wBloom then wBloom.Enabled = false end
		if wRays then wRays.Enabled = false end
		return
	end
	if worldGone(wGrade) then wGrade = Instance.new("ColorCorrectionEffect"); wGrade.Name = "PDWorldGrade"; wGrade.Parent = L end
	if worldGone(wBloom) then wBloom = Instance.new("BloomEffect"); wBloom.Name = "PDWorldBloom"; wBloom.Size = 24; wBloom.Threshold = 1; wBloom.Parent = L end
	if worldGone(wRays) then wRays = Instance.new("SunRaysEffect"); wRays.Name = "PDWorldRays"; wRays.Spread = 0.8; wRays.Parent = L end
	local pr = PRESET_BY[wd.preset] or PRESETS[1]
	wGrade.Enabled = true
	wGrade.TintColor = Color3.new(1, 1, 1):Lerp(pr.tint, math.clamp(wd.tint, 0, 1))
	wGrade.Saturation = math.clamp(wd.sat, -1, 1)
	wGrade.Contrast = math.clamp(wd.con, 0, 0.5)
	wGrade.Brightness = -math.clamp(wd.dark, 0, 0.4)   -- can only darken, never brighten
	wBloom.Intensity = math.clamp(wd.bloom, 0, 2); wBloom.Enabled = wd.bloom > 0
	wRays.Intensity = math.clamp(wd.rays, 0, 0.5); wRays.Enabled = wd.rays > 0
end
function setPreset(id)
	local pr = PRESET_BY[id]; if not pr then return end
	wd.preset, wd.tint, wd.sat, wd.con, wd.dark, wd.bloom, wd.rays = id, 1, pr.sat, pr.con, pr.dark, pr.bloom, pr.rays
	applyWorld()
end
local acc = 0
keep(RunService.Heartbeat:Connect(function(dt)
	acc += dt
	if acc >= 0.5 then acc = 0; if wd.on then guarded("world", applyWorld) end end
end))
end

-- ===================== FPS boost =====================
-- Makes the game cheaper to draw on YOUR screen. Every changed property is remembered and put back when Boost is
-- turned off or the script is closed. The weapon in your hands (and its skin) is never touched.
local applyOpt, restoreOpt
do
	local saved = { post = {}, particles = {}, textures = {}, plain = {} }
	local OURS = { PDMotionBlur = true, PDWorldGrade = true, PDWorldBloom = true, PDWorldRays = true }
	local function set(cat, inst, prop, value)
		local s = saved[cat][inst]
		if not s then s = {}; saved[cat][inst] = s end
		if s[prop] == nil then s[prop] = inst[prop] end
		if inst[prop] ~= value then inst[prop] = value end
	end
	local function restore(cat)
		for inst, props in pairs(saved[cat]) do
			for prop, v in pairs(props) do pcall(function() inst[prop] = v end) end
		end
		table.clear(saved[cat])
	end
	local function want(cat) return opt.on and opt[cat] end
	local function inView(d)
		local cam = workspace.CurrentCamera
		return cam ~= nil and d:IsDescendantOf(cam)
	end
	local function consider(d)
		if want("particles") and (d:IsA("ParticleEmitter") or d:IsA("Trail") or d:IsA("Smoke") or d:IsA("Fire") or d:IsA("Sparkles")) then
			if not inView(d) then set("particles", d, "Enabled", false) end
		elseif want("textures") and d:IsA("Decal") then
			if not inView(d) then set("textures", d, "Transparency", 1) end
		elseif want("plain") and d:IsA("BasePart") and not d:IsA("Terrain") then
			if not inView(d) then set("plain", d, "Material", Enum.Material.SmoothPlastic); set("plain", d, "Reflectance", 0) end
		end
	end
	local function doPost()
		if not want("post") then return end
		for _, c in ipairs(game:GetService("Lighting"):GetChildren()) do
			if not OURS[c.Name] then
				if c:IsA("PostEffect") then set("post", c, "Enabled", false)
				elseif c:IsA("Atmosphere") then set("post", c, "Density", 0); set("post", c, "Haze", 0); set("post", c, "Glare", 0) end
			end
		end
	end
	local origQuality, origCap, rendered = nil, nil, false
	pcall(function() origQuality = settings().Rendering.QualityLevel end)
	pcall(function() if type(getfpscap) == "function" then origCap = getfpscap() end end)
	local function doRender()
		if opt.on then
			local q = Enum.QualityLevel["Level" .. string.format("%02d", math.clamp(math.floor(opt.quality + 0.5), 1, 21))]
			pcall(function() if settings().Rendering.QualityLevel ~= q then settings().Rendering.QualityLevel = q end end)
			if type(setfpscap) == "function" then pcall(setfpscap, opt.cap) end
			rendered = true
		elseif rendered then
			if origQuality then pcall(function() settings().Rendering.QualityLevel = origQuality end) end
			if origCap and type(setfpscap) == "function" then pcall(setfpscap, origCap) end
			rendered = false
		end
	end
	function applyOpt()
		for cat in pairs(saved) do if not want(cat) then restore(cat) end end
		doRender(); doPost()
		if want("particles") or want("textures") or want("plain") then
			for _, d in ipairs(workspace:GetDescendants()) do pcall(consider, d) end
		end
	end
	function restoreOpt()
		for cat in pairs(saved) do restore(cat) end
		local was = opt.on
		opt.on = false; doRender(); opt.on = was
	end
	keep(workspace.DescendantAdded:Connect(function(d) if opt.on then pcall(consider, d) end end))
	local acc = 0
	keep(RunService.Heartbeat:Connect(function(dt)   -- maps and menus change lighting, so check again every second
		acc += dt
		if acc >= 1 then acc = 0; if opt.on then guarded("boost", function() doPost(); doRender() end) end end
	end))
end

-- ===================== weapon tint =====================
-- Recolors the skin's own texture (SurfaceAppearance.Color multiplies it), so blue on Emerald comes out
-- blue-green. Arms are left alone. Each weapon keeps its own tint.
local untint
do
	local origColor = {}
	local function tintModel(m, c)
		for _, d in ipairs(m:GetDescendants()) do
			local target, prop
			if d:IsA("SurfaceAppearance") then
				if not (d.Parent and isArmPart(d.Parent)) then target, prop = d, "Color" end
			elseif d:IsA("BasePart") and not isArmPart(d) and d.Name ~= "HumanoidRootPart" and not d:FindFirstChildOfClass("SurfaceAppearance") then
				target, prop = d, "Color"
			end
			if target then
				local o = origColor[target]
				if o == nil then
					local ok, v = pcall(function() return target[prop] end)
					if not ok then continue end
					o = v; origColor[target] = o
				end
				local want = Color3.new(o.R * c.R, o.G * c.G, o.B * c.B)   -- multiply: keeps the texture, shifts its colors
				if target[prop] ~= want then target[prop] = want end
			end
		end
	end
	function untint()
		for target, o in pairs(origColor) do pcall(function() target.Color = o end) end
		table.clear(origColor)
	end
	local function untintModel(m)
		for target, o in pairs(origColor) do
			if not target.Parent then origColor[target] = nil
			elseif target:IsDescendantOf(m) then pcall(function() target.Color = o end); origColor[target] = nil end
		end
	end
	local function handle(m, w)
		local t = w and tints[w]
		if t and t.on then
			local col = t.color == "Rainbow" and Color3.fromHSV((os.clock() * 0.7) % 1, 0.85, 1) or TRACER_COLORS[t.color] or TRACER_COLORS.Cyan
			tintModel(m, Color3.new(1, 1, 1):Lerp(col, math.clamp(t.strength, 0, 1)))
		elseif next(origColor) then
			untintModel(m)
		end
	end
	local prune = 0
	local function stepTint()
		local held, hw = heldModel()
		if held then handle(held, hw) end
		for bodyModel, weapon in pairs(sa.bodySkinModels or {}) do handle(bodyModel, weapon) end
		prune += 1
		if prune >= 120 then   -- now and then, forget guns that were destroyed while tinted
			prune = 0
			for target in pairs(origColor) do if not target.Parent then origColor[target] = nil end end
		end
	end
	do local okB, eB = pcall(function() RunService:BindToRenderStep("PDSkinChangerTint", Enum.RenderPriority.Last.Value + 6, function() guarded("tint", stepTint) end) end); if not okB then warn("[SkinChanger] could not start tint: " .. tostring(eB)) end end
end

-- ===================== small instance helpers =====================
-- Only the overlays Meowthjrlib has no widget for (FOV circles, ESP) are built by hand.
local function mk(class, props, parent)
	local o = Instance.new(class)
	for k, v in pairs(props) do o[k] = v end
	o.Parent = parent
	return o
end
local function accentColor() return (ui and ui.Accent) or Color3.fromRGB(94, 138, 255) end
local INK = Color3.fromRGB(240, 241, 246)
local overlayGui
do
	local parents = {
		function() return type(gethui) == "function" and gethui() or nil end,
		function() return game:GetService("CoreGui") end,
		function() return lp:WaitForChild("PlayerGui", 5) end,
	}
	for _, get in ipairs(parents) do
		local ok, p = pcall(get)
		if ok and typeof(p) == "Instance" then
			local gui = Instance.new("ScreenGui")
			gui.Name = "PDOverlays"; gui.ResetOnSpawn = false; gui.DisplayOrder = 49; gui.IgnoreGuiInset = true
			pcall(function() if type(syn) == "table" and syn.protect_gui then syn.protect_gui(gui) end end)
			local okP = pcall(function() gui.Parent = p end)
			if okP and gui.Parent == p then overlayGui = gui; break end
			pcall(function() gui:Destroy() end)
		end
	end
	if not overlayGui then warn("[SkinChanger] Couldn't place the overlays anywhere."); return end
end

-- ===================== silent aim =====================
-- Uses the game's own direction input and hit calculations.
do
	-- Drawing and targeting share a pixel radius in viewport coordinates.
	function sa.circleContains(camera, position, radius)
		local projected, onScreen = camera:WorldToViewportPoint(position)
		local center = camera.ViewportSize * 0.5
		local dx, dy = projected.X - center.X, projected.Y - center.Y
		local distanceSquared = dx * dx + dy * dy
		return onScreen and projected.Z > 0 and distanceSquared <= radius * radius, distanceSquared
	end
	local ring = mk("Frame", { Name = "SilentAimFOV", AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1, BorderSizePixel = 0, Active = false, Visible = false }, overlayGui)
	mk("UICorner", { CornerRadius = UDim.new(0.5, 0) }, ring)
	local outline = mk("UIStroke", { Color = accentColor(), Thickness = 1.5, Transparency = 0.15, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, ring)
	keep(RunService.RenderStepped:Connect(function()
		local cam = workspace.CurrentCamera
		ring.Visible = alive and sa.showFov and not sa.lobbyBlocked() and cam ~= nil
		if not ring.Visible then return end
		local center = cam.ViewportSize * 0.5
		ring.Position = UDim2.fromOffset(center.X, center.Y)
		ring.Size = UDim2.fromOffset(sa.radius * 2, sa.radius * 2)
		outline.Color = accentColor()
	end))
	local ctl, origAttack, origAim, wrappedAttack, priorAttack
	local raycast, combatConfig, shotSpread
	local ok = g(function()
		raycast = requireGame(RS.Combat.CombatRaycast)
		combatConfig = requireGame(RS.Combat.Config)
		shotSpread = requireGame(RS.Combat.ShotSpread)
		if type(filtergc) == "function" then
			ctl = filtergc("table", { Keys = { "duels", "state", "movement" } }, true)
		elseif type(getgc) == "function" then
			for _, value in ipairs(getgc(true)) do
				if type(value) == "table" and rawget(value, "duels") and rawget(value, "state") and rawget(value, "movement") then ctl = value; break end
			end
		end
		assert(ctl and type(ctl.attack) == "function" and type(ctl.aimHit) == "function", "Combat controller unavailable")
		origAttack, origAim = ctl.attack, ctl.aimHit
		priorAttack = rawget(ctl, "attack")
	end)
	function sa.lobbyBlocked()
		return sa.disableInLobby and ctl ~= nil and ctl.state ~= nil and ctl.state.mode == "Lobby"
	end
	local ready = ok and ctl and origAttack and origAim and raycast
	sa.ready = ready and true or false
	function sa.targetPart(character, targetHead)
		if targetHead then return character:FindFirstChild("Head") end
		return character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso") or character:FindFirstChild("HumanoidRootPart")
	end
	local partGroups = {
		Head = { "Head" },
		Body = { "UpperTorso", "LowerTorso", "Torso" },
		Limbs = { "LeftUpperArm", "LeftLowerArm", "LeftHand", "RightUpperArm", "RightLowerArm", "RightHand", "LeftUpperLeg", "LeftLowerLeg", "LeftFoot", "RightUpperLeg", "RightLowerLeg", "RightFoot", "Left Arm", "Right Arm", "Left Leg", "Right Leg" },
	}
	function sa.rollGroup(available, roll)
		local weights = { Head = sa.headWeight, Body = sa.bodyWeight, Limbs = sa.limbWeight }
		local total = 0
		for _, group in ipairs({ "Head", "Body", "Limbs" }) do if available[group] then total += weights[group] end end
		if total <= 0 then return nil end
		local threshold = math.clamp(roll, 0, 0.999999999) * total
		for _, group in ipairs({ "Head", "Body", "Limbs" }) do
			if available[group] then
				threshold -= weights[group]
				if threshold < 0 then return group end
			end
		end
	end
	function sa.shotOrigin(camera)
		local head = lp.Character and lp.Character:FindFirstChild("Head")
		return sa.thirdPerson and head and head.Position or camera.CFrame.Position
	end
	local function choose(self, reach, radius, targetHead, mode, allDirections)
		local camera = workspace.CurrentCamera
		if not camera or not lp.Character then return end
		reach = math.min(reach, combatConfig.Prototype.GunReach)
		local origin = mode and sa.shotOrigin(camera) or camera.CFrame.Position
		local bestDistance = math.huge
		local best, bestCharacter
		local groups = {}
		for _, character in ipairs(raycast.livingCharacters(lp.Character)) do
			local player = Players:GetPlayerFromCharacter(character)
			local permitted = (player and sa.players) or (not player and sa.npcs)
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			local candidates = {}
			if mode == "Closest Part" or mode == "Weighted Random" then
				for group, names in pairs(partGroups) do
					for _, name in ipairs(names) do
						local p = character:FindFirstChild(name)
						if p then candidates[#candidates + 1] = { part = p, group = group } end
					end
				end
			else
				candidates[1] = { part = sa.targetPart(character, mode == "Head" or (mode == nil and targetHead)), group = targetHead and "Head" or "Body" }
			end
			for _, candidate in ipairs(candidates) do
			local part = candidate.part
			if permitted and humanoid and humanoid.Health > 0 and part and part:IsA("BasePart")
				and not character:FindFirstChildOfClass("ForceField")
				and self:enemyFromHit({ Instance = part }) == character then
				local delta = part.Position - origin
				local distance = delta.Magnitude
				if distance > 0.001 and distance <= math.min(reach, sa.range) then
					local direction = delta / distance
					local inside, screenDistance = sa.circleContains(camera, part.Position, radius)
					if allDirections then inside, screenDistance = true, distance * distance end
					if inside and (screenDistance < bestDistance or mode == "Weighted Random") then
						-- The game's raycast enforces region and wall visibility.
						local frame = camera.CFrame
						camera.CFrame = CFrame.new(origin) * frame.Rotation
						local hitOK, hit = pcall(origAim, self, reach, 0, direction)
						camera.CFrame = frame
						if not hitOK then error(hit, 0) end
						if hit and self:enemyFromHit(hit) == character then
							if screenDistance < bestDistance then
								bestDistance, best = screenDistance, direction
								bestCharacter = character
							end
							local previous = groups[candidate.group]
							if not previous or screenDistance < previous.distance then
								groups[candidate.group] = { distance = screenDistance, direction = direction, character = character }
							end
						end
					end
				end
			end
			end
		end
		if mode == "Weighted Random" then
			local group = sa.rollGroup(groups, math.random())
			local picked = group and groups[group]
			return picked and picked.direction, picked and picked.character
		end
		return best, bestCharacter
	end
	sa.chooseTarget = function(radius, targetHead)
		if ready and not sa.lobbyBlocked() and ctl:canAct() then
			local direction, target = choose(ctl, sa.range, radius, targetHead)
			sa.targetCharacter = target
			return direction, target
		end
		sa.targetCharacter = nil
	end
	-- Invert the game's deterministic spread using the same seed and shot index.
	function sa.compensateSpread(direction, angle, rollX, rollY)
		local aim = direction
		for _ = 1, 4 do
			local actual = shotSpread.apply(aim, angle, rollX, rollY)
			aim = (aim + direction - actual).Unit
		end
		return aim
	end
	local function shotDirection(self)
		local direction, target
		if sa.ragebot then
			direction, target = choose(self, sa.range, sa.radius, true, "Head", true)
			if not direction then direction, target = choose(self, sa.range, sa.radius, false, "Body", true) end
		else
			direction, target = choose(self, sa.range, sa.radius, sa.head, sa.targetMode)
		end
		sa.targetCharacter = target
		if not direction then return end
		local state = self.state
		local humanoid = lp.Character and lp.Character:FindFirstChildOfClass("Humanoid")
		local movement = humanoid and humanoid:GetState()
		local airborne = movement == Enum.HumanoidStateType.Jumping or movement == Enum.HumanoidStateType.Freefall
		local aimAmount = math.round(math.clamp(self.aimAmount or 0, 0, 1) * 255) / 255
		local angle = shotSpread.angle(combatConfig.Weapons[state.preset], aimAmount, airborne and combatConfig.AirSpread or nil)
		local rollX, rollY = shotSpread.roll(state.spreadSeed, self:spreadIndex(state))
		return sa.compensateSpread(direction, angle, rollX, rollY)
	end
	if ready then
		wrappedAttack = function(self, ...)
			local camera = workspace.CurrentCamera
			local originalFrame, aimedFrame
			if alive and (sa.on or sa.ragebot) and not sa.lobbyBlocked() and self == ctl and camera and not self.state.knife
				and not self.menu and not menuOpen() then
				local selected, direction = pcall(shotDirection, self)
				sa.lastError = not selected and tostring(direction) or nil
				if sa.ragebot and (not selected or not direction) then return end
				if selected and direction then
					-- The game reads both aimLook and hit direction during attack: give those reads the same aim,
					-- then restore the visible camera.
					originalFrame = camera.CFrame
					local origin = sa.shotOrigin(camera)
					aimedFrame = CFrame.lookAt(origin, origin + direction)
					camera.CFrame = aimedFrame
					sa.redirected = (sa.redirected or 0) + 1
				end
			end
			local result = table.pack(pcall(origAttack, self, ...))
			if originalFrame and aimedFrame then
				-- Preserve camera motion applied by the game's shot/recoil code.
				camera.CFrame = originalFrame * aimedFrame:ToObjectSpace(camera.CFrame)
			end
			if not result[1] then error(result[2], 0) end
			return table.unpack(result, 2, result.n)
		end
		g(function() ctl.attack = wrappedAttack end)
		sa.cleanup = function()
			sa.on = false
			sa.ragebot = false
			sa.noRecoil = false
			g(function()
				if rawget(ctl, "attack") == wrappedAttack then ctl.attack = priorAttack end
			end)
		end
	else
		sa.cleanup = function() end
	end

	-- Clear queued camera recoil after shot() populates its springs.
	do
		local motion, originalShot, previousShot, wrappedShot
		local function detach()
			if motion and rawget(motion, "shot") == wrappedShot then
				motion.shot = previousShot
			end
			motion, originalShot, previousShot, wrappedShot = nil, nil, nil, nil
		end
		local function enabled()
			return alive and sa.noRecoil and not sa.lobbyBlocked()
		end
		local function attach()
			local current = ctl and ctl.cameraMotion
			if current == motion then return end
			detach()
			if type(current) ~= "table" or type(current.shot) ~= "function"
				or type(current.clearRecoil) ~= "function" then return end
			motion, originalShot, previousShot = current, current.shot, rawget(current, "shot")
			local target, shot = current, originalShot
			wrappedShot = function(self, ...)
				local results = table.pack(shot(self, ...))
				if self == target and enabled() then
					self:clearRecoil()
					sa.noRecoilCleared = (sa.noRecoilCleared or 0) + 1
				end
				return table.unpack(results, 1, results.n)
			end
			current.shot = wrappedShot
		end
		attach()
		keep(RunService.Heartbeat:Connect(function()
			attach()
			if motion and enabled() then motion:clearRecoil() end
		end))
		sa.noRecoilCleanup = detach
	end

	-- Use the game's ordinary crosshair ray and enemy filter, including walls.
	local function triggerTarget()
		local camera = workspace.CurrentCamera
		if not camera or not lp.Character then return nil end
		local reach = math.min(sa.range, combatConfig.Prototype.GunReach)
		local hit = origAim(ctl, reach, 0, camera.CFrame.LookVector)
		if not hit then return nil end
		local character = ctl:enemyFromHit(hit)
		if not character or character == lp.Character then return nil end
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if not humanoid or humanoid.Health <= 0 or character:FindFirstChildOfClass("ForceField") then return nil end
		local player = Players:GetPlayerFromCharacter(character)
		if (player and not sa.players) or (not player and not sa.npcs) then return nil end
		return character
	end

	-- Tec-9 Triggerbot uses native held fire; other automatic modes share tap timing.
	do
		local busy, nextAttempt, nextScan, nextTrigger = false, 0, 0, 0
		local holding, holdWeapon, holdCharacter, focused = false, nil, nil, true
		local function releaseHold(force)
			if not holding then return end
			holding, sa.tecTriggerHolding = false, false
			holdWeapon, holdCharacter = nil, nil
			nextTrigger = os.clock() + sa.triggerCooldown
			if ctl and (force or not UIS:IsMouseButtonPressed(Enum.UserInputType.MouseButton1)) then
				pcall(ctl.releaseFire, ctl, true)
			end
		end
		sa.releaseTriggerHold = releaseHold
		local function allowed()
			return alive and ready and focused and not menuOpen() and not sa.lobbyBlocked() and not UIS:GetFocusedTextBox()
				and not ctl.menu and ctl.state and not ctl.state.knife and not ctl.state.reloading
		end
		local function fireDue()
			if not allowed() or not (sa.rapidFire or sa.triggerbot or sa.ragebot)
				or (not sa.triggerbot and not sa.ragebot and not UIS:IsMouseButtonPressed(Enum.UserInputType.MouseButton1)) then return false end
			local weapon = combatConfig.Weapons[ctl.state.preset]
			local interval = weapon and weapon.Interval
			if type(interval) ~= "number" or interval <= 0 then return false end
			local due = math.max(nextAttempt, tonumber(ctl.nextShot) or 0,
				(tonumber(ctl.shotTime) or 0) + interval) + 0.025
			return os.clock() >= due, interval
		end
		local function failed(err)
			releaseHold(true)
			sa.rapidFire, sa.triggerbot, sa.ragebot = false, false, false
			sa.rapidFireError = tostring(err)
			warn("[SkinChanger] Auto-fire stopped: " .. tostring(err))
		end
		keep(UIS.WindowFocusReleased:Connect(function() focused = false; releaseHold(true) end))
		keep(UIS.WindowFocused:Connect(function() focused = true end))
		keep(lp.CharacterRemoving:Connect(function() releaseHold(true) end))
		keep(RunService.Heartbeat:Connect(function()
			if busy or not ready then return end
			local tec = allowed() and sa.triggerbot and not sa.ragebot and ctl.state.preset == "Tec9"
			if holding and (not tec or holdCharacter ~= lp.Character or holdWeapon ~= ctl.state.weaponId) then releaseHold() end
			if tec then
				busy = true
				local okT, err = g(function()
					if not allowed() or not sa.triggerbot or sa.ragebot or ctl.state.preset ~= "Tec9"
						or not ctl:canAct() or (type(ctl.state.ammo) == "number" and ctl.state.ammo <= 0) then
						releaseHold(); return
					end
					if not triggerTarget() then releaseHold(); return end
					if holding then
						if not ctl.held then releaseHold() end
						return
					end
					-- A real input that already holds fire belongs to the player.
					if ctl.held or os.clock() < nextTrigger then return end
					assert(type(ctl.pressFire) == "function" and type(ctl.releaseFire) == "function", "Native held fire unavailable")
					holding, sa.tecTriggerHolding = true, true
					holdWeapon, holdCharacter = ctl.state.weaponId, lp.Character
					ctl:pressFire()
					if not ctl.held then releaseHold() end
				end)
				busy = false
				if not okT then failed(err) end
				return
			end
			if os.clock() < nextScan or not fireDue() then return end
			nextScan = os.clock() + 0.05
			busy = true
			local okF, err = g(function()
				local due, interval = fireDue()
				if due and sa.ragebot and type(ctl.state.ammo) == "number" and ctl.state.ammo <= 0 then
					if ctl:canHandle() then nextAttempt = os.clock() + 0.5; ctl:reload() end
					return
				end
				if due and ctl:canAct() then
					local manual = sa.rapidFire and UIS:IsMouseButtonPressed(Enum.UserInputType.MouseButton1)
					if sa.ragebot then
						if not shotDirection(ctl) then return end
					elseif not manual then
						if not sa.triggerbot or os.clock() < nextTrigger or not triggerTarget() then return end
					end
					nextAttempt = os.clock() + interval
					ctl:attack()
					if not sa.ragebot and not manual then nextTrigger = os.clock() + sa.triggerCooldown end
				end
			end)
			busy = false
			if not okF then failed(err) end
		end))
	end
end

-- ===================== aim assist =====================
do
	local ring = mk("Frame", { Name = "AimAssistFOV", AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1, BorderSizePixel = 0, Active = false, Visible = false }, overlayGui)
	mk("UICorner", { CornerRadius = UDim.new(0.5, 0) }, ring)
	mk("UIStroke", { Color = Color3.fromRGB(255, 170, 65), Thickness = 1.5, Transparency = 0.15, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, ring)
	keep(RunService.RenderStepped:Connect(function()
		local camera = workspace.CurrentCamera
		ring.Visible = alive and sa.cameraShowFov and not sa.lobbyBlocked() and camera ~= nil
		if not ring.Visible then return end
		local center = camera.ViewportSize / 2
		ring.Position = UDim2.fromOffset(center.X, center.Y)
		ring.Size = UDim2.fromOffset(sa.cameraRadius * 2, sa.cameraRadius * 2)
	end))
	function sa.cameraBlend(current, direction, dt)
		local goal = CFrame.lookAt(current.Position, current.Position + direction)
		local alpha = sa.cameraSmooth and (1 - math.exp(-sa.cameraSpeed * math.max(0, dt))) or 1
		return current:Lerp(goal, alpha)
	end
	function sa.holdActive()
		if sa.cameraHold == "MouseButton2" or sa.cameraHold == "MouseButton3" then
			return UIS:IsMouseButtonPressed(Enum.UserInputType[sa.cameraHold])
		end
		local okK, key = pcall(function() return Enum.KeyCode[sa.cameraHold] end)
		return okK and key ~= nil and UIS:IsKeyDown(key)
	end
	function sa.cameraStep(dt)
		if not alive or not sa.cameraOn or sa.lobbyBlocked() or menuOpen() or freeCursor or not sa.holdActive() or UIS:GetFocusedTextBox() then return end
		local camera = workspace.CurrentCamera
		if not camera or camera.CameraType ~= Enum.CameraType.Custom then return end
		local clean, field = camera.CFrame, camera.FieldOfView
		-- Select using the same projection the user sees after stretch and FOV effects.
		if st.on then camera.CFrame = clean * CFrame.new(0, 0, 0, 1, 0, 0, 0, 1 - math.clamp(st.amount, 0, 0.7), 0, 0, 0, 1) end
		if vm.on and vm.fov ~= 0 then camera.FieldOfView = math.clamp(field + vm.fov, 1, 120) end
		-- The combat visibility check needs game-thread identity.
		local okC, direction = g(sa.chooseTarget, sa.cameraRadius, sa.cameraHead)
		camera.CFrame, camera.FieldOfView = clean, field
		sa.cameraError = not okC and tostring(direction) or nil
		if okC and direction then
			camera.CFrame = sa.cameraBlend(clean, direction, dt)
			sa.cameraUpdates = (sa.cameraUpdates or 0) + 1
		end
	end
end

-- ===================== player ESP =====================
do
	local es = sa.esp
	local fontFaces = { Gotham = Font.fromEnum(Enum.Font.GothamMedium), Mono = Font.fromEnum(Enum.Font.Code) }
	local function currentFont() return fontFaces[es.font] or fontFaces.Gotham end
	local palette = { White = Color3.new(1, 1, 1), Cyan = Color3.fromRGB(70, 230, 255), Green = Color3.fromRGB(80, 240, 130),
		Gold = Color3.fromRGB(255, 205, 65), Pink = Color3.fromRGB(255, 110, 190), Red = Color3.fromRGB(255, 75, 80),
		Orange = Color3.fromRGB(255, 150, 60), Purple = Color3.fromRGB(180, 110, 255) }
	local function chosenColor(name) return palette[name] or accentColor() end
	local overlay = mk("ScreenGui", { Name = "PDPlayerESP", IgnoreGuiInset = true, ResetOnSpawn = false, DisplayOrder = 48 }, lp.PlayerGui)
	local layer = mk("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ClipsDescendants = true }, overlay)
	local world = mk("Folder", { Name = "PDPlayerESPWorld" }, workspace)
	local function line(parent, name)
		local frame = mk("Frame", { Name = name, AnchorPoint = Vector2.new(0.5, 0.5), BorderSizePixel = 0,
			BackgroundTransparency = 0.08, Visible = false, Active = false, ZIndex = 2 }, parent)
		mk("UIStroke", { Name = "Contrast", Thickness = 1, Color = Color3.fromRGB(8, 11, 17), Transparency = 0.45 }, frame)
		return frame
	end
	local function label(parent, name)
		return mk("TextLabel", { Name = name, AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1,
			Size = UDim2.fromOffset(240, 22), FontFace = currentFont(), TextSize = es.textSize,
			TextStrokeTransparency = 0.65, TextStrokeColor3 = Color3.fromRGB(5, 8, 13),
			TextColor3 = INK, TextWrapped = false, TextTruncate = Enum.TextTruncate.AtEnd,
			ZIndex = 5, Active = false, Visible = false }, parent)
	end
	local function dot(parent, name)
		local frame = line(parent, name)
		mk("UICorner", { CornerRadius = UDim.new(0.5, 0) }, frame)
		return frame
	end
	local function segment(frame, a, b, color)
		if a.Z <= 0.1 or b.Z <= 0.1 then frame.Visible = false; return end
		local delta = Vector2.new(b.X - a.X, b.Y - a.Y)
		frame.Visible = delta.Magnitude > 0.1
		frame.Position = UDim2.fromOffset((a.X + b.X) / 2, (a.Y + b.Y) / 2)
		frame.Size = UDim2.fromOffset(delta.Magnitude, es.thickness)
		frame.Rotation = math.deg(math.atan2(delta.Y, delta.X))
		frame.BackgroundColor3 = color
		frame.BackgroundTransparency = (frame.Name == "Tracer" or frame.Name == "Snapline") and 0.38 or 0.08
	end
	local ring = mk("Frame", { Name = "ESPFOV", AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1, Visible = false }, layer)
	mk("UICorner", { CornerRadius = UDim.new(0.5, 0) }, ring)
	local ringStroke = mk("UIStroke", { Thickness = 1, Color = accentColor(), Transparency = 0.35 }, ring)
	local radar = mk("Frame", { Name = "Radar", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -20, 0, 80),
		BackgroundColor3 = Color3.fromRGB(12, 17, 25), BackgroundTransparency = 0.16, BorderSizePixel = 0, Visible = false }, layer)
	mk("UICorner", { CornerRadius = UDim.new(0.5, 0) }, radar)
	mk("UIStroke", { Thickness = 1, Color = Color3.fromRGB(140, 150, 170), Transparency = 0.65 }, radar)
	mk("Frame", { Position = UDim2.new(0.5, 0, 0, 10), Size = UDim2.new(0, 1, 1, -20), BorderSizePixel = 0, BackgroundTransparency = 0.8 }, radar)
	mk("Frame", { Position = UDim2.new(0, 10, 0.5, 0), Size = UDim2.new(1, -20, 0, 1), BorderSizePixel = 0, BackgroundTransparency = 0.8 }, radar)
	local radarGuide = mk("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.5, 0.5), BackgroundTransparency = 1 }, radar)
	mk("UICorner", { CornerRadius = UDim.new(0.5, 0) }, radarGuide)
	mk("UIStroke", { Thickness = 1, Color = Color3.fromRGB(155, 170, 190), Transparency = 0.86 }, radarGuide)
	local selfDot = dot(radar, "You")
	selfDot.Visible, selfDot.Position, selfDot.Size, selfDot.BackgroundColor3 = true, UDim2.fromScale(0.5, 0.5), UDim2.fromOffset(6, 6), Color3.new(1, 1, 1)
	local bonesR6 = { { "Head", "Torso" }, { "Torso", "Left Arm" }, { "Torso", "Right Arm" }, { "Torso", "Left Leg" }, { "Torso", "Right Leg" } }
	local bonesR15 = { { "Head", "UpperTorso" }, { "UpperTorso", "LowerTorso" }, { "UpperTorso", "LeftUpperArm" }, { "LeftUpperArm", "LeftLowerArm" }, { "LeftLowerArm", "LeftHand" }, { "UpperTorso", "RightUpperArm" }, { "RightUpperArm", "RightLowerArm" }, { "RightLowerArm", "RightHand" }, { "LowerTorso", "LeftUpperLeg" }, { "LeftUpperLeg", "LeftLowerLeg" }, { "LeftLowerLeg", "LeftFoot" }, { "LowerTorso", "RightUpperLeg" }, { "RightUpperLeg", "RightLowerLeg" }, { "RightLowerLeg", "RightFoot" } }
	local edges = { { 1, 2 }, { 1, 3 }, { 1, 5 }, { 2, 4 }, { 2, 6 }, { 3, 4 }, { 3, 7 }, { 4, 8 }, { 5, 6 }, { 5, 7 }, { 6, 8 }, { 7, 8 } }
	local entries, nextScan = {}, 0
	local combatRay
	g(function() combatRay = requireGame(RS.Combat.CombatRaycast) end)
	local function remove(character)
		local entry = entries[character]
		entry.group:Destroy(); entry.radarDot:Destroy()
		for _, box in pairs(entry.hitboxes) do box:Destroy() end
		entries[character] = nil
	end
	local function add(character, owner)
		if character == lp.Character or entries[character] then return end
		local group = mk("Frame", { Name = character.Name, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, layer)
		local entry = { group = group, owner = owner, bones = {}, boxLines = {}, hitboxes = {}, visibleAt = 0, visible = true }
		for i = 1, 14 do entry.bones[i] = line(group, "Bone") end
		for i = 1, 12 do entry.boxLines[i] = line(group, "BoxEdge") end
		entry.head = dot(group, "HeadDot")
		entry.name = label(group, "Name")
		entry.details = label(group, "Details")
		entry.state = label(group, "State")
		for _, item in ipairs({ entry.name, entry.details, entry.state }) do
			item.BackgroundColor3 = Color3.fromRGB(12, 15, 21)
			mk("UICorner", { CornerRadius = UDim.new(0, 4) }, item)
			mk("UIPadding", { PaddingLeft = UDim.new(0, 7), PaddingRight = UDim.new(0, 7) }, item)
			item.AutomaticSize = Enum.AutomaticSize.X
		end
		entry.tracer = line(group, "Tracer")
		entry.snap = line(group, "Snapline")
		entry.velocity = line(group, "Velocity")
		entry.velocityTip = label(group, "VelocityTip"); entry.velocityTip.Text = "▲"; entry.velocityTip.TextSize = 14; entry.velocityTip.Size = UDim2.fromOffset(16, 16)
		entry.arrow = label(group, "OffscreenArrow"); entry.arrow.Text = "▲"; entry.arrow.TextSize = 24; entry.arrow.Size = UDim2.fromOffset(26, 26)
		entry.radarDot = dot(radar, character.Name); entry.radarDot.Size = UDim2.fromOffset(5, 5)
		entry.health = mk("Frame", { Name = "Health", BackgroundColor3 = Color3.fromRGB(20, 20, 20), BorderSizePixel = 0, Visible = false, ZIndex = 3 }, group)
		entry.healthFill = mk("Frame", { AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), BorderSizePixel = 0, ZIndex = 3 }, entry.health)
		mk("UIStroke", { Thickness = 1, Color = Color3.fromRGB(5, 8, 13) }, entry.health)
		entry.healthRatio = nil
		entries[character] = entry
	end
	local function scan()
		local present = {}
		for _, player in ipairs(Players:GetPlayers()) do
			if player ~= lp and player.Character then present[player.Character] = true; add(player.Character, player) end
		end
		if es.practice and combatRay then
			for _, character in ipairs(combatRay.livingCharacters(lp.Character)) do
				if character:GetAttribute("PDPracticeTarget") == true then present[character] = true; add(character, nil) end
			end
		end
		for character in pairs(entries) do if not present[character] or not character.Parent then remove(character) end end
	end
	local function team(owner)
		if not owner then return nil end
		local match, side = owner:GetAttribute("PDMatch"), owner:GetAttribute("PDTeam")
		if match ~= nil and side ~= nil then return tostring(match) .. "/" .. tostring(side) end
		if not owner.Neutral and owner.Team then return owner.Team.Name end
		return nil
	end
	local function teamTint(owner)
		if owner and owner.Team and not owner.Neutral then return owner.TeamColor.Color end
		local value = tostring(owner and owner:GetAttribute("PDTeam") or "")
		local hash = 0
		for i = 1, #value do hash = (hash * 31 + string.byte(value, i)) % 360 end
		return value ~= "" and Color3.fromHSV(hash / 360, 0.65, 1) or chosenColor(es.color)
	end
	local function bounds(character, root)
		local low, high = Vector3.new(math.huge, math.huge, math.huge), Vector3.new(-math.huge, -math.huge, -math.huge)
		for _, part in ipairs(character:GetChildren()) do
			if part:IsA("BasePart") then
				local relative = root.CFrame:ToObjectSpace(part.CFrame)
				local half = part.Size / 2
				local r, u, l = relative.RightVector, relative.UpVector, relative.LookVector
				local extent = Vector3.new(math.abs(r.X)*half.X + math.abs(u.X)*half.Y + math.abs(l.X)*half.Z,
					math.abs(r.Y)*half.X + math.abs(u.Y)*half.Y + math.abs(l.Y)*half.Z,
					math.abs(r.Z)*half.X + math.abs(u.Z)*half.Y + math.abs(l.Z)*half.Z)
				low = low:Min(relative.Position - extent)
				high = high:Max(relative.Position + extent)
			end
		end
		return root.CFrame * CFrame.new((low + high) / 2), (high - low) / 2
	end
	local function screenOrigin(name, viewport)
		if name == "Mouse" then local mouse = UIS:GetMouseLocation(); return Vector3.new(mouse.X, mouse.Y, 1) end
		local y = name == "Top" and 4 or name == "Center" and viewport.Y / 2 or viewport.Y - 4
		return Vector3.new(viewport.X / 2, y, 1)
	end
	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	rayParams.IgnoreWater = true
	local function visible(character, camera, root, head)
		for _, part in ipairs({ head or root, root }) do
			local hit = workspace:Raycast(camera.CFrame.Position, part.Position - camera.CFrame.Position, rayParams)
			if not hit or hit.Instance:IsDescendantOf(character) then return true end
		end
		return false
	end
	local function hide(entry)
		entry.group.Visible = false
		entry.radarDot.Visible = false
		for _, box in pairs(entry.hitboxes) do box.Visible = false end
	end
	local function statusOf(character, owner, humanoid, root)
		local function attr(name) return character:GetAttribute(name) or (owner and owner:GetAttribute(name)) end
		if attr("PDSliding") then return "Sliding" end
		if attr("PDCrouching") then return "Crouching" end
		if humanoid.Sit then return "Seated" end
		local state = humanoid:GetState()
		if state == Enum.HumanoidStateType.Jumping or state == Enum.HumanoidStateType.Freefall then return "Airborne" end
		if root.AssemblyLinearVelocity.Magnitude > 2 then return "Moving" end
		return "Standing"
	end
	local lastFrame = os.clock()
	local function step()
		local now = os.clock()
		local healthBlend = 1 - math.exp(-12 * math.clamp(now - lastFrame, 0, 0.15))
		lastFrame = now
		local camera = workspace.CurrentCamera
		local active = alive and es.enabled and camera ~= nil
		layer.Visible = active
		if not active then for _, entry in pairs(entries) do hide(entry) end; return end
		local viewport, center = camera.ViewportSize, camera.ViewportSize / 2
		ring.Visible = es.fov
		ring.Position, ring.Size = UDim2.fromOffset(center.X, center.Y), UDim2.fromOffset(es.fovRadius * 2, es.fovRadius * 2)
		ringStroke.Color, ringStroke.Thickness = chosenColor(es.color), math.clamp(es.thickness, 1, 2)
		selfDot.BackgroundColor3 = es.unifiedColor and chosenColor(es.color) or Color3.new(1, 1, 1)
		radar.Visible, radar.Size = es.radar, UDim2.fromOffset(es.radarSize, es.radarSize)
		if os.clock() >= nextScan then nextScan = os.clock() + 0.5; scan() end
		rayParams.FilterDescendantsInstances = { lp.Character, camera, world }
		local localRoot = lp.Character and lp.Character:FindFirstChild("HumanoidRootPart")
		local origin = localRoot and localRoot.Position or camera.CFrame.Position
		for character, entry in pairs(entries) do
			hide(entry)
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			local root = character:FindFirstChild("HumanoidRootPart") or character:FindFirstChild("Torso")
			local head = character:FindFirstChild("Head")
			local owner = entry.owner
			local sameTeam = team(owner) ~= nil and team(owner) == team(lp)
			local distance = root and (root.Position - origin).Magnitude or math.huge
			if humanoid and humanoid.Health > 0 and root and distance <= es.maxDistance and not (es.hideTeam and sameTeam) then
				entry.group.Visible = true
				local point, onScreen = camera:WorldToViewportPoint(root.Position)
				local target = es.target and ((es.targetUserId ~= 0 and owner and owner.UserId == es.targetUserId) or (es.targetUserId == 0 and sa.targetCharacter == character))
				if es.visibility and os.clock() >= entry.visibleAt then
					entry.visible = visible(character, camera, root, head)
					entry.visibleAt = os.clock() + 0.15
				end
				local color = not es.unifiedColor and es.teamColor and teamTint(owner) or chosenColor(es.color)
				if not es.unifiedColor and es.visibility and not entry.visible then color = chosenColor(es.hiddenColor) end
				if target and not es.unifiedColor then color = palette.Gold end
				local boxFrame, half = bounds(character, root)
				local projected, low, high, front = {}, Vector2.new(math.huge, math.huge), Vector2.new(-math.huge, -math.huge), true
				for _, x in ipairs({ -1, 1 }) do for _, y in ipairs({ -1, 1 }) do for _, z in ipairs({ -1, 1 }) do
					local corner = camera:WorldToViewportPoint(boxFrame:PointToWorldSpace(Vector3.new(x*half.X, y*half.Y, z*half.Z)))
					projected[#projected + 1] = corner
					front = front and corner.Z > 0.1
					low = low:Min(Vector2.new(corner.X, corner.Y)); high = high:Max(Vector2.new(corner.X, corner.Y))
				end end end
				local corners2D = { Vector3.new(low.X, low.Y, 1), Vector3.new(high.X, low.Y, 1),
					Vector3.new(high.X, high.Y, 1), Vector3.new(low.X, high.Y, 1) }
				for i, frame in ipairs(entry.boxLines) do
					frame.Visible = false
					if es.box and front then
						if es.boxMode == "3D" then
							segment(frame, projected[edges[i][1]], projected[edges[i][2]], color)
						elseif es.boxMode == "Corners" then
							if i <= 8 then
								local cornerIndex = math.ceil(i / 2)
								local corner = corners2D[cornerIndex]
								local span = math.min(18, (high.X - low.X) * .24, (high.Y - low.Y) * .24)
								local dx = (cornerIndex == 1 or cornerIndex == 4) and span or -span
								local dy = cornerIndex <= 2 and span or -span
								local offset = i % 2 == 1 and Vector3.new(dx, 0, 0) or Vector3.new(0, dy, 0)
								segment(frame, corner, corner + offset, color)
							end
						elseif i <= 4 then
							segment(frame, corners2D[i], corners2D[i % 4 + 1], color)
						end
					end
				end
				local bones = character:FindFirstChild("UpperTorso") and bonesR15 or bonesR6
				for i, frame in ipairs(entry.bones) do
					frame.Visible = false
					local bone = bones[i]
					local a, b = bone and character:FindFirstChild(bone[1]), bone and character:FindFirstChild(bone[2])
					if es.skeleton and a and b then segment(frame, camera:WorldToViewportPoint(a.Position), camera:WorldToViewportPoint(b.Position), color) end
				end
				entry.head.Visible = false
				if es.headDot and head then
					local h, shown = camera:WorldToViewportPoint(head.Position)
					entry.head.Visible = shown and h.Z > 0.1
					entry.head.Position, entry.head.Size = UDim2.fromOffset(h.X, h.Y), UDim2.fromOffset(es.dotRadius*2, es.dotRadius*2)
					entry.head.BackgroundColor3 = color
				end
				local labelX = (low.X + high.X) / 2
				local labelHeight = es.textSize + 8
				entry.name.Visible = es.names and onScreen and front
				entry.name.Text = owner and owner.Name or character.Name
				entry.name.Position = UDim2.fromOffset(labelX, low.Y - labelHeight / 2 - 7)
				local details = {}
				if es.distance then details[#details + 1] = tostring(math.floor(distance + 0.5)) .. " studs" end
				if es.health and es.healthMode ~= "Bar" then details[#details + 1] = tostring(math.ceil(humanoid.Health)) .. " HP" end
				if es.weapon then
					local held = character:FindFirstChild("PDHeldWeapon")
					local weapon = held and held:GetAttribute("PDPreset")
					if not weapon then local tool = character:FindFirstChildOfClass("Tool"); weapon = tool and tool.Name end
					details[#details + 1] = weapon and tostring(weapon) or "Unarmed"
				end
				local states = {}
				if es.status then states[#states + 1] = statusOf(character, owner, humanoid, root) end
				if es.visibility then states[#states + 1] = entry.visible and "Visible" or "Obstructed" end
				entry.state.Text = table.concat(states, "  ·  ")
				entry.state.Visible = #states > 0 and onScreen and front
				entry.state.Position = UDim2.fromOffset(labelX, high.Y + labelHeight / 2 + 7 + (#details > 0 and labelHeight + 3 or 0))
				entry.details.Visible = #details > 0 and onScreen and front
				entry.details.Text = table.concat(details, "  ·  ")
				entry.details.Position = UDim2.fromOffset(labelX, high.Y + labelHeight / 2 + 7)
				for _, item in ipairs({ entry.name, entry.details, entry.state }) do
					item.FontFace = currentFont()
					item.TextSize = es.textSize
					item.TextColor3 = es.unifiedColor and color or (item == entry.name and Color3.fromRGB(242, 245, 250) or (item == entry.state and Color3.fromRGB(160, 173, 192) or Color3.fromRGB(205, 215, 230)))
					item.BackgroundTransparency = es.backplates and 0.22 or 1
					item.Size = UDim2.fromOffset(24, labelHeight)
				end
				entry.health.Visible = es.health and es.healthMode ~= "Number" and front and onScreen
				if entry.health.Visible then
					local ratio = math.clamp(humanoid.Health / math.max(humanoid.MaxHealth, 1), 0, 1)
					entry.health.Position, entry.health.Size = UDim2.fromOffset(low.X - 8, low.Y), UDim2.fromOffset(4, high.Y - low.Y)
					entry.healthRatio = entry.healthRatio and (entry.healthRatio + (ratio - entry.healthRatio) * healthBlend) or ratio
					entry.healthFill.Size = UDim2.fromScale(1, entry.healthRatio)
					local red, amber, green = Color3.fromRGB(242, 100, 112), Color3.fromRGB(242, 197, 105), Color3.fromRGB(102, 218, 164)
					ratio = entry.healthRatio
					entry.healthFill.BackgroundColor3 = es.unifiedColor and color or (ratio < 0.5 and red:Lerp(amber, ratio * 2) or amber:Lerp(green, (ratio - 0.5) * 2))
				end
				entry.tracer.Visible, entry.snap.Visible = false, false
				if es.tracers and onScreen and front then segment(entry.tracer, screenOrigin(es.tracerOrigin, viewport), Vector3.new(point.X, high.Y, 1), color) end
				if es.snaplines and onScreen then segment(entry.snap, screenOrigin(es.snapOrigin, viewport), point, color) end
				entry.velocity.Visible, entry.velocityTip.Visible = false, false
				if es.velocity and onScreen and root.AssemblyLinearVelocity.Magnitude > 0.5 then
					local endpoint = camera:WorldToViewportPoint(root.Position + root.AssemblyLinearVelocity * 0.3)
					segment(entry.velocity, point, endpoint, color)
					entry.velocityTip.Position, entry.velocityTip.Rotation = UDim2.fromOffset(endpoint.X, endpoint.Y), entry.velocity.Rotation + 90
					entry.velocityTip.TextColor3 = color
				end
				entry.arrow.Visible = es.arrows and not onScreen
				if entry.arrow.Visible then
					local offset = Vector2.new(point.X, point.Y) - center
					if point.Z < 0 then offset = -offset end
					if offset.Magnitude < 0.01 then offset = Vector2.new(0, 1) end
					offset = offset.Unit
					local radius = math.min((center.X-28)/math.max(math.abs(offset.X), 0.001), (center.Y-28)/math.max(math.abs(offset.Y), 0.001))
					local position = center + offset * radius
					entry.arrow.Position, entry.arrow.Rotation = UDim2.fromOffset(position.X, position.Y), math.deg(math.atan2(offset.Y, offset.X)) + 90
					entry.arrow.TextColor3 = color
				end
				entry.radarDot.Visible = es.radar and distance <= es.radarRange
				if entry.radarDot.Visible then
					local flat = root.Position - origin
					local forward = Vector3.new(camera.CFrame.LookVector.X, 0, camera.CFrame.LookVector.Z)
					forward = forward.Magnitude > 0.01 and forward.Unit or Vector3.new(0, 0, -1)
					local right = forward:Cross(Vector3.yAxis)
					local scale = (es.radarSize / 2 - 9) / es.radarRange
					entry.radarDot.Position = UDim2.fromOffset(es.radarSize/2 + flat:Dot(right)*scale, es.radarSize/2 - flat:Dot(forward)*scale)
					entry.radarDot.BackgroundColor3 = color
				end
				-- Projected, rounded body panels instead of world adornments: nothing is added to the character.
				if es.chams or es.glow or target or es.hitboxes then
					for _, part in ipairs(character:GetChildren()) do
						if part:IsA("BasePart") and part ~= root then
							local panel = entry.hitboxes[part]
							if not panel then
								panel = mk("Frame", { BorderSizePixel = 0, BackgroundTransparency = 1, ZIndex = 2 }, entry.group)
								mk("UICorner", { CornerRadius = UDim.new(0, 3) }, panel)
								mk("UIStroke", { Name = "Edge", Thickness = 1 }, panel)
								entry.hitboxes[part] = panel
							end
							local partLow, partHigh = Vector2.new(math.huge, math.huge), Vector2.new(-math.huge, -math.huge)
							local partFront = true
							for _, x in ipairs({ -1, 1 }) do for _, y in ipairs({ -1, 1 }) do for _, z in ipairs({ -1, 1 }) do
								local p = camera:WorldToViewportPoint(part.CFrame:PointToWorldSpace(Vector3.new(x, y, z) * part.Size / 2))
								partFront = partFront and p.Z > 0.1
								partLow = partLow:Min(Vector2.new(p.X, p.Y))
								partHigh = partHigh:Max(Vector2.new(p.X, p.Y))
							end end end
							local unobstructed = true
							if not es.throughWalls then
								local hit = workspace:Raycast(camera.CFrame.Position, part.Position - camera.CFrame.Position, rayParams)
								unobstructed = not hit or hit.Instance:IsDescendantOf(character)
							end
							panel.Visible = partFront and unobstructed
							panel.Position = UDim2.fromOffset(partLow.X, partLow.Y)
							panel.Size = UDim2.fromOffset(partHigh.X - partLow.X, partHigh.Y - partLow.Y)
							panel.BackgroundColor3 = color
							panel.BackgroundTransparency = es.chams and 1 - es.chamsOpacity or 1
							panel.Edge.Color = color
							panel.Edge.Transparency = (es.glow or target or es.hitboxes) and 0.18 or 1
						end
					end
				end
				for part, box in pairs(entry.hitboxes) do if not part.Parent then box:Destroy(); entry.hitboxes[part] = nil end end
			end
		end
	end
	es.cleanup = function()
		for character in pairs(entries) do remove(character) end
		overlay:Destroy(); world:Destroy()
	end
	keep(RunService.RenderStepped:Connect(function()
		local okS, err = pcall(step)
		es.lastError = not okS and tostring(err) or nil
	end))
end

-- ===================== spinbot, air steering =====================
local viewApi: { cycle: (() -> ())?, off: (() -> ())? } = {}
do
	local humanoid, autoRotate, spinYaw
	function sa.stopSpin()
		if humanoid and humanoid.Parent then humanoid.AutoRotate = autoRotate end
		humanoid, autoRotate, spinYaw = nil, nil, nil
	end
	function sa.spinStep(dt)
		local character = lp.Character
		local nextHumanoid = character and character:FindFirstChildOfClass("Humanoid")
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if not alive or not sa.spinOn or sa.lobbyBlocked() or menuOpen() or not nextHumanoid or nextHumanoid.Health <= 0 or not root or root.Anchored or nextHumanoid.Sit then
			sa.stopSpin()
			return
		end
		if humanoid ~= nextHumanoid then
			sa.stopSpin()
			humanoid, autoRotate = nextHumanoid, nextHumanoid.AutoRotate
			local _, yaw = root.CFrame:ToOrientation()
			spinYaw = yaw
		end
		humanoid.AutoRotate = false
		spinYaw = (spinYaw + math.rad(sa.spinSpeed) * math.min(dt, 0.1)) % (2 * math.pi)
		root.CFrame = CFrame.new(root.Position) * CFrame.Angles(0, spinYaw, 0)
	end
	function sa.airVelocity(velocity, direction, speed, dt)
		local horizontal = Vector3.new(velocity.X, 0, velocity.Z)
		local input = Vector3.new(direction.X, 0, direction.Z)
		if input.Magnitude < 0.01 then return velocity end
		local alpha = 1 - math.exp(-sa.airResponse * math.max(0, dt))
		local magnitude = horizontal.Magnitude
		local targetAngle = math.atan2(input.X, input.Z)
		local currentAngle = magnitude > 0.001 and math.atan2(horizontal.X, horizontal.Z) or targetAngle
		local difference = math.atan2(math.sin(targetAngle - currentAngle), math.cos(targetAngle - currentAngle))
		local angle = currentAngle + difference * alpha
		-- Rotate direction separately so opposite inputs cannot cancel velocity.
		local nextSpeed = magnitude + (math.max(magnitude, speed) - magnitude) * alpha
		return Vector3.new(math.sin(angle) * nextSpeed, velocity.Y, math.cos(angle) * nextSpeed)
	end
	function sa.airStep(dt)
		if not alive or not sa.airOn or sa.lobbyBlocked() or menuOpen() or UIS:GetFocusedTextBox() then return end
		local character = lp.Character
		local hum = character and character:FindFirstChildOfClass("Humanoid")
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if not hum or hum.Health <= 0 or hum.Sit or not root or root.Anchored then return end
		local state = hum:GetState()
		if state ~= Enum.HumanoidStateType.Jumping and state ~= Enum.HumanoidStateType.Freefall then return end
		root.AssemblyLinearVelocity = sa.airVelocity(root.AssemblyLinearVelocity, hum.MoveDirection, hum.WalkSpeed, dt)
	end
	keep(RunService.PreSimulation:Connect(function(dt)
		local okS, e = pcall(function() sa.spinStep(dt) end)
		if not okS then warn("[SkinChanger] character spin error: " .. tostring(e)) end
		pcall(function() sa.airStep(dt) end)
	end))
end

-- ===================== third-person view =====================
-- The view key toggles the camera behind the character. Spectating uses the game camera.
do
	local OVER = { Result = true, MatchResult = true }
	local view = 0      -- 0 first person, 1 behind you
	local saved
	local hidden = {}
	local combat, nextFind = nil, 0
	local function combatCtl()
		if not combat and type(getgc) == "function" and os.clock() > nextFind then
			nextFind = os.clock() + 5
			for _, v in ipairs(getgc(true)) do
				if type(v) == "table" and rawget(v, "duels") ~= nil and rawget(v, "state") ~= nil and rawget(v, "movement") ~= nil then combat = v; break end
			end
		end
		return combat
	end
	local function where()
		local c = combatCtl()
		local s = c and rawget(c, "state")
		if type(s) ~= "table" then return nil end
		local duels = rawget(c, "duels")
		if duels and duels.spectator and duels.spectator.active then return nil end
		if s.mode == "Practice" or s.mode == "Lobby" or (s.mode == "Duel" and not s.eliminated and not s.watching) then return s.mode end
		local round = duels and duels.round
		if s.mode == "Duel" and round and round.matchId == s.match and OVER[round.phase] then return "Over" end
		return nil
	end
	local function hideFirstPerson()
		local cam = workspace.CurrentCamera
		for _, c in ipairs(cam:GetChildren()) do
			if c:IsA("Model") and (string.find(c.Name, "^PD_") or c.Name == "AvatarArms") then
				for _, p in ipairs(c:GetDescendants()) do
					if p:IsA("BasePart") and p.LocalTransparencyModifier ~= 1 then hidden[p] = true; p.LocalTransparencyModifier = 1 end
				end
			end
		end
	end
	local function showFirstPerson()
		for p in pairs(hidden) do if p.Parent then p.LocalTransparencyModifier = 0 end end
		table.clear(hidden)
	end
	local function viewOff()
		local was = saved
		view, saved = 0, nil
		sa.thirdPerson = false
		if sa.syncThird then sa.syncThird() end
		showFirstPerson()
		if was then
			lp.CameraMinZoomDistance, lp.CameraMaxZoomDistance = was.min, was.max
			-- the camera mode the game itself picks: free in the lobby, locked to first person everywhere else
			lp.CameraMode = was.mode
		end
	end
	viewApi.off = viewOff
	function viewApi.cycle()
		local at = where()
		if not at then
			setStatus("Third-person view is unavailable while spectating or outside a loaded character.")
			return
		end
		if view ~= 0 then viewOff()
		else
			if not saved then saved = { mode = lp.CameraMode, min = lp.CameraMinZoomDistance, max = lp.CameraMaxZoomDistance } end
			view = 1
			sa.thirdPerson = true
			if sa.syncThird then sa.syncThird() end
		end
		setStatus(view == 0 and "First person." or "Third person (behind you).")
	end
	local function before()
		if sa.lobbyBlocked() then
			if view ~= 0 then
				local requested = sa.thirdPerson
				viewOff()
				sa.thirdPerson = requested
			end
			return
		end
		if sa.thirdPerson and view == 0 then
			saved = { mode = lp.CameraMode, min = lp.CameraMinZoomDistance, max = lp.CameraMaxZoomDistance }
			view = 1
		elseif not sa.thirdPerson and view ~= 0 then viewOff() end
		if view == 0 then return end
		local at = alive and where()
		if not at then viewOff(); return end
		lp.CameraMode = Enum.CameraMode.Classic
		if lp.CameraMaxZoomDistance ~= sa.thirdDistance then lp.CameraMaxZoomDistance = sa.thirdDistance end
		if lp.CameraMinZoomDistance ~= sa.thirdDistance then lp.CameraMinZoomDistance = sa.thirdDistance end
	end
	keep(UIS.InputChanged:Connect(function(i, gp)
		if view ~= 0 and not gp and i.UserInputType == Enum.UserInputType.MouseWheel then
			sa.thirdDistance = math.clamp(sa.thirdDistance - i.Position.Z * 1.5, 4, 24)
			if sa.syncDistance then sa.syncDistance() end
		end
	end))
	local function after()
		if view == 0 then return end
		hideFirstPerson()
		-- Roblox's camera frees the mouse in this camera mode every frame: lock it again so the mouse turns the
		-- camera like in first person, unless a menu or the free cursor needs it
		if lp.CameraMode == Enum.CameraMode.Classic and where() ~= "Lobby" and not (freeCursor or menuOpen() or (combat and rawget(combat, "menu"))) then
			UIS.MouseBehavior = Enum.MouseBehavior.LockCenter
		end
	end
	local okV, eV = pcall(function()
		RunService:BindToRenderStep("PDSkinChangerViewA", Enum.RenderPriority.Camera.Value - 2, before)
		RunService:BindToRenderStep("PDSkinChangerViewB", Enum.RenderPriority.Camera.Value + 3, after)
	end)
	if not okV then warn("[SkinChanger] could not start the third-person view: " .. tostring(eV)) end
end

-- ===================== skins on the weapon others would see =====================
-- A copy of the chosen skin is laid over the weapon on your own body, so the skin shows in third person too.
do
	local entries = {}
	sa.bodySkinModels = {}
	local function remove(source)
		local entry = entries[source]
		if not entry then return end
		for part, transparency in pairs(entry.originalParts) do
			if part.Parent then part.LocalTransparencyModifier = transparency end
		end
		sa.bodySkinModels[entry.model] = nil
		if FC and FC.unbind then g(function() FC.unbind(entry.model) end) end
		entry.model:Destroy()
		entries[source] = nil
	end
	function sa.clearBodySkins()
		for source in pairs(entries) do remove(source) end
	end
	local elapsed, scanning = 0, false
	keep(RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if scanning or elapsed < 0.2 then return end
		elapsed, scanning = 0, true
		local okB, err = pcall(function()
			local character = lp.Character
			for source in pairs(entries) do
				if not alive or not character or source.Parent ~= character then remove(source) end
			end
			if not alive or not character then return end
			for _, source in ipairs(character:GetChildren()) do
				if source:IsA("Model") and (source.Name == "PDHeldWeapon" or source.Name == "PDHolsteredWeapon" or source.Name == "PDHolsteredKnife") then
					local weapon = source:GetAttribute("PDPreset")
					local roll = shuffle.on and rolled[weapon]
					local id = roll and roll.id or sel[weapon]
					local pattern = roll and roll.pat or pat[weapon] or 1
					local wearValue = roll and roll.wear or wear[weapon] or 0
					local key = tostring(id) .. ":" .. tostring(pattern) .. ":" .. tostring(wearValue)
					if entries[source] and entries[source].key ~= key then remove(source) end
					if not id then remove(source)
					elseif not entries[source] then
						local created, model = g(function()
							return WM.createBody(weapon, id)
						end)
						if created and typeof(model) == "Instance" and model:IsA("Model") then
							local prepared, prepareError = pcall(function()
								model.Name = "PDSkinBodyOverride"
								model:ScaleTo(source:GetScale())
								local parts = model:QueryDescendants("BasePart")
								for _, joint in ipairs(model:QueryDescendants("JointInstance, WeldConstraint")) do joint:Destroy() end
								for _, part in ipairs(parts) do
									part.Anchored = true
									part.CanCollide, part.CanTouch, part.CanQuery = false, false, false
								end
								if FC then
									local bound, bindError = g(function()
										FC.bind(model, { skinId = id, pattern = pattern, wear = wearValue }, 0, { fullDetail = true, transient = false })
									end)
									if not bound then error(bindError, 0) end
								end
								if not alive or source.Parent ~= lp.Character then error("Body weapon changed during rebuild", 0) end
								model:PivotTo(source:GetPivot())
								model.Parent = character
								local originalParts = {}
								for _, part in ipairs(source:QueryDescendants("BasePart")) do originalParts[part] = part.LocalTransparencyModifier end
								entries[source] = { model = model, parts = parts, originalParts = originalParts, key = key }
								sa.bodySkinModels[model] = weapon
							end)
							if not prepared then
								if FC and FC.unbind then g(function() FC.unbind(model) end) end
								model:Destroy()
								error(prepareError, 0)
							end
						elseif not created then error(model, 0) end
					end
				end
			end
		end)
		scanning = false
		sa.bodySkinError = not okB and tostring(err) or nil
	end))
	keep(RunService.RenderStepped:Connect(function()
		local camera = workspace.CurrentCamera
		local head = lp.Character and lp.Character:FindFirstChild("Head")
		local visible = camera and head and (camera.CFrame.Position - head.Position).Magnitude > 2
		for source, entry in pairs(entries) do
			if source.Parent and entry.model.Parent then
				entry.model:PivotTo(source:GetPivot())
				for part in pairs(entry.originalParts) do if part.Parent then part.LocalTransparencyModifier = 1 end end
				for _, part in ipairs(entry.parts) do part.LocalTransparencyModifier = visible and 0 or 1 end
			end
		end
	end))
end

-- ===================== auto slide on jump =====================
-- After each jump the slide key is pressed for you just before you land, so you land straight into a slide.
do
	local VIM = game:GetService("VirtualInputManager")
	local MoveCfg
	g(function() MoveCfg = requireGame(RS.Combat.Config) end)
	local BUFFER = MoveCfg and MoveCfg.Slide and tonumber(MoveCfg.Slide.LandingBuffer) or 0.15
	local LEAD = math.clamp(BUFFER * 0.5, 0.03, 0.12)
	local function fastEnough(hum, root)
		local walk = (MoveCfg and MoveCfg.Prototype and tonumber(MoveCfg.Prototype.WalkSpeed) or 16) + 2
		local min = MoveCfg and MoveCfg.Slide and tonumber(MoveCfg.Slide.MinSpeed) or 0
		return hum.MoveDirection.Magnitude > 0.1 and (root.AssemblyLinearVelocity * Vector3.new(1, 0, 1)).Magnitude > math.max(walk, min)
	end
	local ctl, nextFind = nil, 0
	local function sliding()
		if not ctl and type(getgc) == "function" and os.clock() > nextFind then
			nextFind = os.clock() + 5
			for _, v in ipairs(getgc(true)) do
				if type(v) == "table" and rawget(v, "readyAt") ~= nil and rawget(v, "combat") ~= nil then ctl = v; break end
			end
		end
		return ctl ~= nil and rawget(ctl, "active") ~= nil and rawget(ctl, "active") ~= false
	end
	local function pressSlide()
		pcall(function() VIM:SendKeyEvent(true, Enum.KeyCode.C, false, game) end)
		task.delay(0.05, function() pcall(function() VIM:SendKeyEvent(false, Enum.KeyCode.C, false, game) end) end)
	end
	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	local armed = false
	local hum, root, ch
	local function okNow() return alive and slideJump.on and not sa.lobbyBlocked() and hum and root and not UIS:GetFocusedTextBox() end
	local function hook(c)
		ch = c
		hum = c and c:WaitForChild("Humanoid", 5)
		root = c and c:WaitForChild("HumanoidRootPart", 5)
		armed = false
		if not (alive and hum) then return end
		keep(hum.StateChanged:Connect(function(_, new)
			if new == Enum.HumanoidStateType.Jumping then
				armed = true
			elseif new == Enum.HumanoidStateType.Landed and armed then   -- landed before the press: press now
				armed = false
				if okNow() and fastEnough(hum, root) and not sliding() then pressSlide() end
			end
		end))
	end
	keep(lp.CharacterAdded:Connect(hook))
	if lp.Character then task.spawn(hook, lp.Character) end
	keep(RunService.Heartbeat:Connect(function()
		if not (armed and okNow()) or hum.Parent ~= ch then return end
		local vy = root.AssemblyLinearVelocity.Y
		if vy >= 0 then return end   -- still going up
		-- how long until the feet touch the ground at this fall speed
		rayParams.FilterDescendantsInstances = { ch, workspace.CurrentCamera }
		local hit = workspace:Raycast(root.Position, Vector3.new(0, -40, 0), rayParams)
		if not hit then return end
		local gap = (root.Position.Y - hit.Position.Y) - (hum.HipHeight + root.Size.Y / 2)
		local fall, gravity = -vy, workspace.Gravity
		local t = gap <= 0 and 0 or (-fall + math.sqrt(fall * fall + 2 * gravity * gap)) / gravity
		if t <= LEAD then
			armed = false
			if fastEnough(hum, root) and not sliding() then pressSlide() end
		end
	end))
end

-- ===================== incognito =====================
-- Local display layer only. Never edits player stats or network payloads.
do
	local watched, hidden, proxies = {}, {}, {}
	local maskedText = {}
	local model, character
	local loading, generation, retryAt = false, 0, 0
	local accessoryWelds = {}
	local function escaped(value) return (value:gsub("(%W)", "%%%1")) end
	local function replaceName(value, name, replacement)
		if name == "" then return value end
		return (value:gsub(escaped(name), function() return replacement end))
	end
	function sa.privacyMask(value, path)
		local values = privacy.values
		local function number(key) return string.format("%.0f", values[key]) end
		local key = path:lower()
		local preferred = key:find("displayname", 1, true) and values.displayName or values.username
		local result = replaceName(value, lp.Name, preferred)
		if lp.DisplayName ~= lp.Name then result = replaceName(result, lp.DisplayName, values.displayName) end
		if game.JobId ~= "" then result = result:gsub(escaped(game.JobId), function() return values.serverId end) end
		if key:find(".playerlist.", 1, true) and not key:find("playerentry_" .. tostring(lp.UserId) .. ".", 1, true) then return result end
		if key:find("serverid", 1, true) then return values.serverId end
		if key:find("servername", 1, true) then return "SERVER " .. number("server") end
		if key:find(".servers.", 1, true) and key:find(".info.", 1, true) and key:find("region", 1, true) then return "Region: " .. values.region end
		if key:find(".progression.account.level", 1, true) or key:find(".account.pdtextshadows.level", 1, true) then
			return "Level " .. number("level") .. " · " .. number("xp") .. " / " .. number("xpTotal") .. " XP"
		end
		if key:find("balances", 1, true) and key:find(".progression.", 1, true) then return "Coins " .. number("coins") .. " · Cash " .. number("cash") end
		if (key:find(".wallet.", 1, true) and key:find("coins", 1, true)) or key:find(".currencies.coins.", 1, true) then return number("coins") end
		if (key:find(".wallet.", 1, true) and key:find("cash", 1, true)) or key:find(".currencies.cash.", 1, true) then return number("cash") end
		if key:find(".ping", 1, true) and result:find("%d") then return "Ping: " .. number("ping") .. " ms" end
		if key:find("streak", 1, true) and result:find("%d") then result = result:gsub("%d[%d,%.]*", function() return number("streak") end) end
		if key:find("level", 1, true) and result:find("%d") then result = result:gsub("%d[%d,%.]*", function() return number("level") end) end
		result = result:gsub("([Ss][Ee][Rr][Vv][Ee][Rr]%s*#?%s*)%d+", function(prefix) return prefix .. number("server") end)
		result = result:gsub("%d+%s*[mM][sS]%f[%W]", function() return number("ping") .. " ms" end)
		return result
	end

	local textProperties = {
		"FontFace", "TextSize", "TextColor3", "TextStrokeColor3", "TextScaled",
		"TextWrapped", "TextXAlignment", "TextYAlignment", "RichText",
		"TextTruncate", "LineHeight", "MaxVisibleGraphemes",
	}
	local function watchText(object, transform)
		local entry = {
			outlines = {},
			property = "Text", transparency = object.TextTransparency,
			stroke = object.TextStrokeTransparency,
		}
		watched[object] = entry
		local function restoreOutlines()
			for source, data in pairs(entry.outlines) do
				if source.Parent and source.Transparency == 1 then source.Transparency = data.transparency end
				if data.copy then data.copy:Destroy() end
			end
			table.clear(entry.outlines)
		end
		entry.syncOutlines = function()
			if not entry.overlay then return end
			for _, source in ipairs(object:GetChildren()) do
				if source:IsA("UIStroke") and source.ApplyStrokeMode == Enum.ApplyStrokeMode.Contextual then
					local data = entry.outlines[source]
					if not data then
						local copy = source:Clone()
						copy.Name = "PDPrivacyOutline"
						copy.Parent = entry.overlay
						data = { copy = copy, transparency = source.Transparency }
						entry.outlines[source] = data
					elseif source.Transparency ~= 1 then data.transparency = source.Transparency end
					local copy = data.copy
					copy.Color, copy.Thickness = source.Color, source.Thickness
					copy.Enabled, copy.LineJoinMode = source.Enabled, source.LineJoinMode
					copy.Transparency = data.transparency
					source.Transparency = 1
				end
			end
			for source, data in pairs(entry.outlines) do
				if source.Parent ~= object or source.ApplyStrokeMode ~= Enum.ApplyStrokeMode.Contextual then
					if source.Parent and source.Transparency == 1 then source.Transparency = data.transparency end
					data.copy:Destroy()
					entry.outlines[source] = nil
				end
			end
		end
		local function syncStyle()
			if not entry.overlay then return end
			for _, property in ipairs(textProperties) do entry.overlay[property] = object[property] end
			entry.overlay.TextTransparency = entry.transparency
			entry.overlay.TextStrokeTransparency = entry.stroke
			entry.overlay.ZIndex = object.ZIndex + 1
		end
		entry.apply = function()
			if not object.Parent then return end
			local real = object.Text
			local replacement = privacy.on and transform(real) or real
			if privacy.on and (replacement ~= real or entry.overlay) then
				if not entry.overlay then
					local ov = Instance.new("TextLabel")
					ov.Name = "PDPrivacyText"
					ov:SetAttribute("PDPrivacyOverlay", true)
					ov.BackgroundTransparency = 1
					ov.BorderSizePixel = 0
					ov.Active, ov.Selectable = false, false
					ov.Size = UDim2.fromScale(1, 1)
					entry.overlay = ov
					syncStyle()
					ov.Text = replacement
					ov.Parent = object
				else entry.overlay.Text = replacement end
				maskedText[object] = entry
				entry.syncOutlines()
				object.TextTransparency, object.TextStrokeTransparency = 1, 1
			else
				maskedText[object] = nil
				restoreOutlines()
				if entry.overlay then
					entry.overlay:Destroy()
					entry.overlay = nil
					object.TextTransparency, object.TextStrokeTransparency = entry.transparency, entry.stroke
				end
			end
		end
		entry.connection = object.Changed:Connect(function(property)
			if property == "Text" then entry.apply()
			elseif property == "TextTransparency" then
				if not entry.overlay or object.TextTransparency ~= 1 then entry.transparency = object.TextTransparency; syncStyle() end
			elseif property == "TextStrokeTransparency" then
				if not entry.overlay or object.TextStrokeTransparency ~= 1 then entry.stroke = object.TextStrokeTransparency; syncStyle() end
			elseif property == "ZIndex" or table.find(textProperties, property) then syncStyle() end
		end)
		entry.destroying = object.Destroying:Connect(function()
			entry.connection:Disconnect()
			watched[object], maskedText[object] = nil, nil
		end)
		entry.apply()
	end

	local function watch(object, property, transform)
		if watched[object] then return end
		if property == "Text" then watchText(object, transform); return end
		local entry = { property = property, original = object[property], transform = transform }
		watched[object] = entry
		local function update()
			if not object.Parent then return end
			local value = object[property]
			if value == entry.applied then return end
			entry.original = value
			if privacy.on then
				local changed = transform(value)
				entry.applied = changed
				if changed ~= value then object[property] = changed end
			else entry.applied = nil end
		end
		entry.apply = function()
			if not object.Parent then return end
			local changed = privacy.on and transform(entry.original) or entry.original
			entry.applied = changed
			object[property] = changed
			if not privacy.on then entry.applied = nil end
		end
		entry.connection = object:GetPropertyChangedSignal(property):Connect(update)
		entry.destroying = object.Destroying:Connect(function()
			entry.connection:Disconnect()
			watched[object] = nil
		end)
		update()
	end
	local function inspect(object)
		if object:GetAttribute("PDPrivacyOverlay") then return end
		if object:IsA("TextLabel") or object:IsA("TextButton") then
			watch(object, "Text", function(value) return sa.privacyMask(value, object:GetFullName()) end)
		elseif object:IsA("ImageLabel") or object:IsA("ImageButton") then
			watch(object, "Image", function(value)
				if value:find(tostring(lp.UserId), 1, true) then return "rbxthumb://type=AvatarHeadShot&id=" .. string.format("%.0f", privacy.values.avatarId) .. "&w=150&h=150" end
				return value
			end)
		end
	end
	local function root(rootObject)
		for _, object in ipairs(rootObject:GetDescendants()) do inspect(object) end
		keep(rootObject.DescendantAdded:Connect(inspect))
	end
	root(lp:WaitForChild("PlayerGui"))
	local core = game:GetService("CoreGui")
	local leaderboard = core:FindFirstChild("PlayerList")
	if leaderboard then root(leaderboard) end
	keep(core.ChildAdded:Connect(function(child) if child.Name == "PlayerList" then root(child) end end))
	local function hide(part)
		if hidden[part] == nil then hidden[part] = part.LocalTransparencyModifier end
		part.LocalTransparencyModifier = 1
	end
	local function restoreAvatar()
		for part, value in pairs(hidden) do
			if part.Parent and part.LocalTransparencyModifier == 1 then part.LocalTransparencyModifier = value end
		end
		table.clear(hidden)
		for _, part in pairs(proxies) do part:Destroy() end
		table.clear(proxies)
		if model then model:Destroy(); model = nil end
		character = nil
		generation += 1
		loading, retryAt = false, 0
		table.clear(accessoryWelds)
	end
	local function requestAvatar(humanoid)
		if loading or os.clock() < retryAt then return end
		loading = true
		local token, sourceCharacter = generation, character
		task.spawn(function()
			local okA, result = pcall(function()
				local description = Players:GetHumanoidDescriptionFromUserIdAsync(privacy.values.avatarId)
				local built, avatar = pcall(function()
					return Players:CreateHumanoidModelFromDescriptionAsync(description, humanoid.RigType)
				end)
				description:Destroy()
				if not built then error(avatar, 0) end
				return avatar
			end)
			if token ~= generation or not alive or not privacy.on or sourceCharacter ~= lp.Character then
				if okA then result:Destroy() end
				return
			end
			loading = false
			if not okA then
				retryAt = os.clock() + 10
				warn("[Incognito] Roblox avatar could not load: " .. tostring(result))
				return
			end
			model = result
			model.Name = "PDIncognitoAvatar"
			for _, object in ipairs(model:GetDescendants()) do
				if object:IsA("BasePart") then
					object.Anchored, object.CanCollide, object.CanTouch, object.CanQuery = true, false, false, false
					object.CastShadow = false
					object.LocalTransparencyModifier = 1
				elseif object:IsA("Script") or object:IsA("LocalScript") or object:IsA("Motor6D") then object:Destroy()
				elseif object:IsA("Weld") and object.Name == "AccessoryWeld" then accessoryWelds[#accessoryWelds+1] = object end
			end
			local avatarHumanoid = model:FindFirstChildOfClass("Humanoid")
			if avatarHumanoid then
				-- A display rig must not run character physics: Humanoids otherwise turn torso and head collision
				-- back on even after CanCollide = false.
				avatarHumanoid.EvaluateStateMachine = false
				avatarHumanoid.AutoRotate = false
				avatarHumanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
			end
			for _, source in ipairs(character:GetChildren()) do
				if source:IsA("BasePart") and source.Name ~= "HumanoidRootPart" then
					local replica = model:FindFirstChild(source.Name)
					if replica and replica:IsA("BasePart") then proxies[source] = replica end
				end
			end
			model.Parent = workspace.CurrentCamera
		end)
	end
	local function scanAvatar()
		if not privacy.on then return end
		if character ~= lp.Character then restoreAvatar(); character = lp.Character end
		if not character then return end
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid then watch(humanoid, "DisplayName", function() return privacy.values.displayName end) end
		if not model then
			if humanoid then requestAvatar(humanoid) end
			return
		end
		for _, object in ipairs(character:GetDescendants()) do
			if object:IsA("BasePart") then
				if object.Parent == character and object.Name ~= "HumanoidRootPart" then
					hide(object)
				elseif object:FindFirstAncestorOfClass("Accessory") then hide(object) end
			end
		end
		local camera = workspace.CurrentCamera
		local arms = camera and camera:FindFirstChild("AvatarArms")
		if arms then
			for _, part in ipairs(arms:GetDescendants()) do if part:IsA("BasePart") then hide(part) end end
		end
	end
	local function setEnabled(enabled)
		privacy.on, sa.incognito = enabled, enabled
		if enabled then
			onlineGone()
		else
			restoreAvatar()
		end
		for _, entry in pairs(watched) do entry.apply() end
		if enabled then scanAvatar() end
	end
	sa.setIncognito = setEnabled
	sa.refreshIncognito = function(avatarChanged)
		for _, entry in pairs(watched) do entry.apply() end
		if avatarChanged then restoreAvatar(); if privacy.on then scanAvatar() end end
	end
	local elapsed = 0
	keep(RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed >= 0.25 then elapsed = 0; scanAvatar() end
	end))
	keep(RunService.PreSimulation:Connect(function()
		if not privacy.on or not model then return end
		for _, part in ipairs(model:GetDescendants()) do
			if part:IsA("BasePart") then
				part.CanCollide, part.CanTouch, part.CanQuery = false, false, false
			end
		end
	end))
	RunService:BindToRenderStep("PDIncognitoAvatar", Enum.RenderPriority.Camera.Value + 20, function()
		if not alive or not privacy.on then return end
		for object, entry in pairs(maskedText) do
			if object.Parent and entry.overlay then
				entry.syncOutlines()
				object.TextTransparency, object.TextStrokeTransparency = 1, 1
			end
		end
		local camera = workspace.CurrentCamera
		if model and camera and model.Parent ~= camera then model.Parent = camera end
		local head = character and character:FindFirstChild("Head")
		local visible = camera and head and (camera.CFrame.Position - head.Position).Magnitude > 2
		for source, part in pairs(proxies) do
			if source.Parent then
				part.CFrame = source.CFrame
			else part:Destroy(); proxies[source] = nil end
		end
		if model then
			local sourceRoot = character and character:FindFirstChild("HumanoidRootPart")
			local replicaRoot = model:FindFirstChild("HumanoidRootPart")
			if sourceRoot and replicaRoot then replicaRoot.CFrame = sourceRoot.CFrame end
			for _, weld in ipairs(accessoryWelds) do
				if weld.Parent and weld.Part0 and weld.Part1 then
					weld.Part0.CFrame = weld.Part1.CFrame * weld.C1 * weld.C0:Inverse()
				end
			end
			for _, part in ipairs(model:GetDescendants()) do
				if part:IsA("BasePart") then part.LocalTransparencyModifier = visible and 0 or 1 end
			end
		end
		for part in pairs(hidden) do
			if part.Parent then part.LocalTransparencyModifier = 1 else hidden[part] = nil end
		end
	end)
	sa.privacyCleanup = function()
		setEnabled(false)
		RunService:UnbindFromRenderStep("PDIncognitoAvatar")
		for _, entry in pairs(watched) do entry.connection:Disconnect(); entry.destroying:Disconnect() end
		table.clear(watched)
	end
end

-- ===================== the window =====================
privacy.ready = true
ui = Lib.new("Pistol Duels", { key = "RightShift", theme = "Midnight", intro = "Pistol Duels" })

local function applyNow(w)
	if not (ui and ui._started) then return end   -- the first run of every callback is the saved profile loading
	local _, held = heldModel()
	if held == w then task.spawn(reEquip) end
end
local function withDefault(list, extra)
	local o = table.clone(list)
	for k, v in pairs(extra or {}) do o[k] = v end
	return o
end

-- Skins: one box per weapon
do
	local skins = ui:Category("Skins")
	local box = skins:Group("All weapons")
	box:Toggle("Shuffle", { tip = "A random skin every time you equip" }, function(v)
		shuffle.on = v
		table.clear(rolled)
		if ui._started then
			local _, held = heldModel()
			if held then task.spawn(reEquip) end
		end
	end)
	box:Toggle("Hide arms", { tip = "Hides your viewmodel's arms so they don't cover the skin" }, function(v)
		hideArms = v
		if v then enforceArms() else restoreArms() end
	end)
	box:Button("Re-equip now", function()
		task.spawn(function()
			local okR = reEquip()
			if alive then setStatus(okR and "Re-equipped. Your skins are rebuilt." or "Couldn't switch weapons from here. Press your weapon keys yourself.") end
		end)
	end)
	for _, w in ipairs(weapons) do
		local labels, byLabel = { "Default" }, {}
		for _, s in ipairs(skinsOf[w] or {}) do
			local label = s.display .. (s.staff and "  (Staff)" or "")
			while byLabel[label] do label = label .. " " end   -- a dropdown needs one row per name
			byLabel[label] = s.id
			labels[#labels + 1] = label
		end
		local wb = skins:Group(displayOf[w])
		local skinOpt
		skinOpt = wb:Dropdown("Skin", withDefault(labels, { default = "Default", tip = "Only you see it. A skin only shows on a weapon in your loadout." }), function(v)
			sel[w] = byLabel[v]
			applyNow(w)
		end)
		local function patterned()
			local id = skinOpt.Value and byLabel[skinOpt.Value]
			return id ~= nil and byId[id] ~= nil and byId[id].patterned == true
		end
		wb:Number("Pattern", { min = 1, max = 1000, step = 1, default = 1, showIf = patterned }, function(v)
			pat[w] = clampPat(v)
			applyNow(w)
		end)
		wb:Slider("Wear", { min = 0, max = 1, step = 0.01, default = 0, showIf = patterned }, function(v)
			wear[w] = clampWear(v)
			applyNow(w)
		end)
		wb:Dropdown("Ammo FX", withDefault({ "Game", "None", table.unpack(fxApi.order) }, { default = "Game", tip = "Tracer, sparks, muzzle flash, impacts and kill effect. Only you see it." }), function(v)
			ammoFx[w] = v ~= "Game" and v or nil
			applyNow(w)
		end)
		local tintOn = wb:Toggle("Tint", { tip = "Paints over the skin's own texture" }, function(v) tintOf(w).on = v end)
		wb:Dropdown("Tint color", withDefault(COLOR_ORDER, { default = "Cyan", showIf = tintOn }), function(v) tintOf(w).color = v end)
		wb:Slider("Tint strength", { min = 5, max = 100, step = 5, default = 45, suffix = " %", showIf = tintOn }, function(v) tintOf(w).strength = v / 100 end)
	end
end

-- Effects
do
	local fx = ui:Category("Effects")
	local trm = fx:Module("Bullet tracers", { tip = "Only your own shots" }, function(on) tr.on = on end)
	trm:Dropdown("Color", withDefault(COLOR_ORDER, { default = "Cyan" }), function(v) tr.color = v end)
	trm:Slider("Thickness", { min = 0.02, max = 0.5, step = 0.01, default = 0.12 }, function(v) tr.thick = v end)
	trm:Slider("Lifetime", { min = 0.1, max = 2.5, step = 0.05, default = 0.6, suffix = " s" }, function(v) tr.life = v end)
	trm:Toggle("Glow", { default = true }, function(v) tr.glow = v end)
	trm:Toggle("Moving streak", function(v) tr.streak = v end)
	trm:Toggle("Replace the game's tracer", { default = true }, function(v) tr.replace = v end)

	local sp = fx:Module("Weapon spin", { tip = "Turns only the gun in your own view" }, function(on) spin.on = on end)
	sp:Slider("Speed", { min = 20, max = 720, step = 10, default = 180, suffix = " deg/s" }, function(v) spin.speed = v end)
	sp:Dropdown("Direction", { "Clockwise", "Counter", default = "Clockwise" }, function(v) spin.dir = v == "Clockwise" and 1 or -1 end)
	sp:Dropdown("Axis", { "Y turn", "X tilt", "Z roll", default = "Y turn" }, function(v) spin.axis = string.sub(v, 1, 1) end)
	sp:Dropdown("Behavior", { "Continuous", "Swing", "On equip", default = "Continuous" }, function(v) spin.mode = v end)
end

-- Boost
do
	local boost = ui:Category("Boost")
	local bm = boost:Module("FPS boost", { tip = "Only your own screen changes" }, function(on) opt.on = on; applyOpt() end)
	bm:Dropdown("FPS cap", { "60", "144", "240", "Max", default = "240" }, function(v)
		opt.cap = v == "Max" and 0 or (tonumber(v) or 240)
		applyOpt()
	end)
	bm:Slider("Graphics quality", { min = 1, max = 21, step = 1, default = 3, suffix = " / 21" }, function(v) opt.quality = v; applyOpt() end)
	bm:Section("Lighter world")
	bm:Toggle("No post effects", { default = true }, function(v) opt.post = v; applyOpt() end)
	bm:Toggle("No particles, smoke and fire", { default = true }, function(v) opt.particles = v; applyOpt() end)
	bm:Toggle("Hide decals and textures", function(v) opt.textures = v; applyOpt() end)
	bm:Toggle("Plain materials", function(v) opt.plain = v; applyOpt() end)
end

-- Display
do
	local disp = ui:Category("Display")
	local stm = disp:Module("Stretched resolution", { tip = "Flattens your view so everything looks wider" }, function(on) st.on = on end)
	stm:Slider("Stretch", { min = 0, max = 70, step = 1, default = 35, suffix = " %" }, function(v) st.amount = v / 100 end)
	local frames = 60
	keep(RunService.RenderStepped:Connect(function(dt) frames += (1 / math.max(dt, 1 / 1000) - frames) * 0.05 end))
	disp:Module("FPS and ping", { tip = "On-screen counter" }):Widget(function()
		local okP, ms = pcall(function()
			return (game:GetService("Stats").Network.ServerStatsItem["Data Ping"] :: StatsItem):GetValue()
		end)
		return math.round(frames) .. " FPS  ·  " .. (okP and math.round(ms) or 0) .. " ms"
	end)
	disp:KeyViewer()
	disp:Watermark()
	disp:ActiveList()
end

-- World
do
	local world = ui:Category("World")
	local wm = world:Module("World look", { tip = "Your own color grade. Brightness can only be lowered." }, function(on) wd.on = on; applyWorld() end)
	local names = {}
	for _, p in ipairs(PRESETS) do names[#names + 1] = p.id end
	local sliders = {}
	local function fine(label, key, min, max)
		sliders[key] = wm:Slider(label, { min = min, max = max, step = 1, default = math.round(wd[key] * 100), suffix = " %" }, function(v)
			wd[key] = v / 100
			applyWorld()
		end)
	end
	wm:Dropdown("Preset", withDefault(names, { default = "Natural" }), function(v)
		setPreset(v)
		for key, o in pairs(sliders) do o:Set(math.round(wd[key] * 100)) end
	end)
	fine("Color strength", "tint", 0, 100)
	fine("Saturation", "sat", -100, 100)
	fine("Contrast", "con", 0, 50)
	fine("Darkness", "dark", 0, 40)
	fine("Glow", "bloom", 0, 200)
	fine("Sun rays", "rays", 0, 50)
end

-- Camera
do
	local cam = ui:Category("Camera")
	local mbm = cam:Module("Motion blur", { tip = "Blurs while you turn fast" }, function(on) mb.on = on end)
	mbm:Slider("Strength", { min = 2, max = 24, step = 1, default = 12 }, function(v) mb.strength = v end)
	mbm:Slider("Starts at", { min = 30, max = 360, step = 10, default = 120, suffix = " deg/s" }, function(v) mb.threshold = v end)
	mbm:Slider("Fade", { min = 0.03, max = 0.4, step = 0.01, default = 0.12, suffix = " s" }, function(v) mb.smooth = v end)

	local vmm = cam:Module("View", { tip = "Field of view is added on top of the game's own, so zooming still works" }, function(on) vm.on = on end)
	vmm:Slider("Field of view", { min = -20, max = 40, step = 1, default = 0, suffix = "°" }, function(v) vm.fov = v end)
	vmm:Slider("Weapon size", { min = 50, max = 200, step = 5, default = 100, suffix = " %" }, function(v) vm.size = v / 100 end)
	vmm:Section("Gun position")
	vmm:Slider("Left / right", { min = -100, max = 100, step = 5, default = 0 }, function(v) vm.x = v / 100 end)
	vmm:Slider("Down / up", { min = -100, max = 100, step = 5, default = 0 }, function(v) vm.y = v / 100 end)
	vmm:Slider("Near / far", { min = -100, max = 150, step = 5, default = 0 }, function(v) vm.z = v / 100 end)
end

-- Legit
local function needsCombat(on)
	if on and not sa.ready then setStatus("Combat controller unavailable. Re-run after loading into the game.") end
	return on and sa.ready == true
end
do
	local legit = ui:Category("Legit")
	local sam = legit:Module("Silent aim", { tip = "Uses the game's own hit calculation. Close the menu to shoot." }, function(on) sa.on = needsCombat(on) end)
	sam:Slider("FOV radius", { min = 10, max = 600, step = 1, default = 120, suffix = " px" }, function(v) sa.radius = v end)
	sam:Slider("Maximum range", { min = 10, max = 1000, step = 10, default = 250, suffix = " studs" }, function(v) sa.range = v end)
	sam:Dropdown("Target", { "Head", "Body", "Closest Part", "Weighted Random", default = "Closest Part" }, function(v) sa.targetMode = v end)
	sam:Toggle("Show FOV circle", { default = true }, function(v) sa.showFov = v end)
	sam:Toggle("Players", { default = true }, function(v) sa.players = v end)
	sam:Toggle("Practice targets", { default = true }, function(v) sa.npcs = v end)
	sam:Section("Weighted random", { collapsed = true })
	sam:Slider("Head weight", { min = 0, max = 100, step = 1, default = 20 }, function(v) sa.headWeight = v end)
	sam:Slider("Torso weight", { min = 0, max = 100, step = 1, default = 50 }, function(v) sa.bodyWeight = v end)
	sam:Slider("Limb weight", { min = 0, max = 100, step = 1, default = 30 }, function(v) sa.limbWeight = v end)

	local trig = legit:Module("Triggerbot", { tip = "Tec-9 holds fire on target; other guns fire single shots" }, function(on)
		sa.triggerbot = needsCombat(on)
		if not sa.triggerbot and sa.releaseTriggerHold then sa.releaseTriggerHold() end
	end)
	trig:Slider("Cooldown", { min = 0, max = 2, step = 0.05, default = 0.15, suffix = " s" }, function(v) sa.triggerCooldown = v end)

	legit:Module("No recoil", function(on) sa.noRecoil = needsCombat(on) end)

	local aa = legit:Module("Aim assist", { tip = "Moves the camera while you hold the aim key. It does not fire for you." }, function(on) sa.cameraOn = needsCombat(on) end)
	local hold = aa:Keybind("Hold to aim", { default = "MouseButton2" })
	sa.holdActive = function() return hold:IsDown() end
	aa:Toggle("Smooth", { default = true }, function(v) sa.cameraSmooth = v end)
	aa:Slider("Response speed", { min = 1, max = 30, step = 1, default = 8 }, function(v) sa.cameraSpeed = v end)
	aa:Slider("FOV radius", { min = 10, max = 600, step = 1, default = 80, suffix = " px" }, function(v) sa.cameraRadius = v end)
	aa:Toggle("Show FOV circle", { default = true }, function(v) sa.cameraShowFov = v end)
	aa:Toggle("Aim at head", { tip = "Off aims at the torso" }, function(v) sa.cameraHead = v end)
end

-- Rage
do
	local rage = ui:Category("Rage")
	rage:Module("Ragebot", { tip = "Fires at anyone in range, through the FOV circle" }, function(on) sa.ragebot = needsCombat(on) end)
	rage:Module("Rapid fire", { tip = "Hold the mouse" }, function(on) sa.rapidFire = needsCombat(on) end)

	local spb = rage:Module("Spinbot", function(on)
		sa.spinOn = on
		if not on then sa.stopSpin() end
	end)
	spb:Slider("Spin speed", { min = 90, max = 7200, step = 90, default = 1440, suffix = " deg/s" }, function(v) sa.spinSpeed = v end)

	local tp = rage:Module("Third person", { tip = "Mouse wheel changes the distance while it is on" }, function(on) sa.thirdPerson = on end)
	local tpd = tp:Slider("Camera distance", { min = 4, max = 24, step = 1, default = 10, suffix = " studs" }, function(v) sa.thirdDistance = v end)
	tp:Keybind("Cycle view", { default = "X" }, function() viewApi.cycle() end)
	sa.syncThird = function() if tp.On ~= sa.thirdPerson then tp:Set(sa.thirdPerson) end end
	sa.syncDistance = function() tpd:Set(sa.thirdDistance) end

	local air = rage:Module("Air steering", { tip = "Steers your jump with WASD" }, function(on) sa.airOn = on end)
	air:Slider("Response", { min = 1, max = 30, step = 1, default = 8 }, function(v) sa.airResponse = v end)

	rage:Group("Lobby"):Toggle("Disable in lobby", { default = true, tip = "Pauses aim, spin, air steering, third person and auto slide in the lobby" },
		function(v) sa.disableInLobby = v end)
end

-- ESP
do
	local es = sa.esp
	local esp = ui:Category("ESP")
	local m = esp:Module("Player ESP", { tip = "Drawn on your own screen only" }, function(on) es.enabled = on end)
	local function flag(label, key, tip)
		m:Toggle(label, { default = es[key] == true, tip = tip }, function(v) es[key] = v end)
	end
	m:Section("Body")
	flag("Boxes", "box")
	flag("Skeleton", "skeleton")
	flag("Head dot", "headDot")
	flag("Chams", "chams")
	flag("Glow", "glow")
	flag("Hitbox bounds", "hitboxes")
	m:Section("Labels", { collapsed = true })
	flag("Names", "names")
	flag("Distance", "distance")
	flag("Health", "health")
	flag("Weapon", "weapon")
	flag("Status", "status")
	m:Section("Direction", { collapsed = true })
	flag("Tracers", "tracers")
	flag("Snaplines", "snaplines")
	flag("Offscreen arrows", "arrows")
	flag("Velocity", "velocity")
	flag("Radar", "radar")
	flag("FOV circle", "fov")
	m:Section("Context", { collapsed = true })
	flag("Team colors", "teamColor")
	flag("Visibility check", "visibility")
	flag("Target highlight", "target")
	m:Section("Style", { collapsed = true })
	m:Dropdown("Box style", { "2D", "Corners", "3D", default = "2D" }, function(v) es.boxMode = v end)
	m:Dropdown("Health style", { "Bar", "Number", "Both", default = "Both" }, function(v) es.healthMode = v end)
	m:Dropdown("Tracer origin", { "Bottom", "Center", "Top", "Mouse", default = "Bottom" }, function(v) es.tracerOrigin = v end)
	m:Dropdown("Snapline origin", { "Center", "Bottom", "Top", "Mouse", default = "Center" }, function(v) es.snapOrigin = v end)
	m:Dropdown("Color", { "Accent", "White", "Cyan", "Green", "Gold", "Pink", "Red", "Orange", "Purple", default = "Accent" }, function(v) es.color = v end)
	m:Dropdown("Obstructed color", { "Red", "Orange", "White", "Purple", default = "Red" }, function(v) es.hiddenColor = v end)
	m:Dropdown("Font", { "Gotham", "Mono", default = "Gotham" }, function(v) es.font = v end)
	m:Toggle("One color for the whole ESP", { default = true }, function(v) es.unifiedColor = v end)
	m:Toggle("Text backplates", { default = true }, function(v) es.backplates = v end)
	m:Slider("Line thickness", { min = 1, max = 4, step = 0.5, default = 1.5 }, function(v) es.thickness = v end)
	m:Slider("Head dot radius", { min = 2, max = 10, step = 1, default = 3 }, function(v) es.dotRadius = v end)
	m:Slider("Text size", { min = 10, max = 20, step = 1, default = 13 }, function(v) es.textSize = v end)
	m:Slider("Chams opacity", { min = 0.1, max = 1, step = 0.05, default = 0.45 }, function(v) es.chamsOpacity = v end)
	m:Slider("FOV radius", { min = 10, max = 600, step = 1, default = 150, suffix = " px" }, function(v) es.fovRadius = v end)
	m:Slider("Radar size", { min = 120, max = 300, step = 10, default = 180, suffix = " px" }, function(v) es.radarSize = v end)
	m:Section("Filters", { collapsed = true })
	flag("Hide teammates", "hideTeam")
	flag("Practice targets", "practice")
	flag("Highlights through walls", "throughWalls")
	m:Slider("Maximum distance", { min = 50, max = 5000, step = 50, default = 1500, suffix = " studs" }, function(v) es.maxDistance = v end)
	m:Slider("Radar range", { min = 25, max = 1000, step = 25, default = 200, suffix = " studs" }, function(v) es.radarRange = v end)
	local pick = m:PlayerDropdown("Highlight", { tip = "Empty follows your current aim target" })
	m:Toggle("Follow my aim target", { default = true }, function(v) es.followAim = v end)
	keep(RunService.Heartbeat:Connect(function()
		if es.followAim then es.targetUserId = 0; return end
		local who = pick.Value and Players:FindFirstChild(pick.Value)
		es.targetUserId = who and who.UserId or 0
	end))
end

-- Incognito
do
	local inc = ui:Category("Incognito")
	local m = inc:Module("Incognito", { tip = "Changes what YOUR screen shows. Other players see your real account." },
		function(on) if sa.setIncognito then sa.setIncognito(on) end end)
	local function word(label, key)
		m:TextBox(label, { default = privacy.values[key], max = 64 }, function(v)
			local cleaned = string.gsub(v, "[%c<>]", "")
			cleaned = string.sub(string.match(cleaned, "^%s*(.-)%s*$") or "", 1, 64)
			privacy.values[key] = cleaned ~= "" and cleaned or "Hidden"
			if sa.refreshIncognito then sa.refreshIncognito(false) end
		end)
	end
	local function count(label, key, min)
		m:Number(label, { min = min or 0, max = 1e12, step = 1, default = privacy.values[key] }, function(v)
			privacy.values[key] = math.floor(v)
			if sa.refreshIncognito then sa.refreshIncognito(key == "avatarId") end
		end)
	end
	m:Section("Identity")
	word("Username", "username")
	word("Display name", "displayName")
	count("Avatar user ID", "avatarId", 1)
	m:Section("Server")
	count("Server number", "server")
	word("Server ID", "serverId")
	word("Server region", "region")
	m:Section("Stats", { collapsed = true })
	count("Winstreak", "streak")
	count("Level", "level", 1)
	count("Coins", "coins")
	count("Cash", "cash")
	count("Ping (ms)", "ping")
	count("Current XP", "xp")
	count("XP required", "xpTotal")
end

-- Misc
local unload
do
	local misc = ui:Category("Misc")
	misc:Module("Auto slide on jump", { tip = "Each jump presses slide for you as you land. Hold jump to keep slide-jumping." },
		function(on) slideJump.on = on end)
	misc:Module("Free cursor", { key = "RightControl", tip = "Keeps your mouse unlocked in first person" }, function(on)
		freeCursor = on
		if on then enforceCursor() end
	end)
	local hop = misc:Group("Server")
	local number = hop:TextBox("Server number", { placeholder = "12", max = 8 })
	local busy = false
	hop:Button("Join that server", function()
		if busy then return end
		local n = tonumber(string.match(number.Value or "", "^%s*#?(%d+)%s*$"))
		if not n or n < 1 then setStatus("Enter a server number first."); return end
		if not serverHop then setStatus("Server hopping is unavailable in this executor."); return end
		busy = true
		setStatus("Looking up server...")
		local okH, message = pcall(serverHop, n)
		setStatus(okH and message or "Could not join that server.")
		busy = false
	end)
	local queue = queue_on_teleport or queueonteleport or (type(syn) == "table" and syn.queue_on_teleport)
	if type(queue) == "function" then
		hop:Toggle("Auto load on server change", function(v) autoLoad.on = v end)
		keep(lp.OnTeleport:Connect(function(state, placeId)
			if state ~= Enum.TeleportState.InProgress or not autoLoad.on or placeId ~= game.PlaceId then return end
			pcall(queue, string.format("if not game:IsLoaded() then game.Loaded:Wait() end; if game.PlaceId == %d then loadstring(game:HttpGet(%q))() end", placeId, "https://pd-online.meowthjr.workers.dev/pd"))
		end))
	else
		hop:Label("Auto load is unavailable in this executor.")
	end
	misc:Group("Script"):Button("Unload everything", function() unload() end)
end

-- ===================== unload =====================
function unload()
	if not alive then return end
	alive = false
	if sa.releaseTriggerHold then pcall(sa.releaseTriggerHold, true) end
	pcall(sa.privacyCleanup)
	pcall(sa.noRecoilCleanup); pcall(sa.cleanup); pcall(sa.esp.cleanup); pcall(sa.stopSpin); pcall(sa.clearBodySkins)
	for _, name in ipairs({ "PDSkinChangerArms", "PDSkinChangerCursor", "PDSkinChangerFx", "PDSkinChangerBlur", "PDSkinChangerTint",
		"PDSkinChangerStretchB", "PDSkinChangerStretchA", "PDSkinChangerViewA", "PDSkinChangerViewB" }) do
		pcall(function() RunService:UnbindFromRenderStep(name) end)
	end
	if viewApi.off then pcall(viewApi.off) end
	pcall(onlineGone)
	pcall(function() if mbBlur then mbBlur:Destroy() end end)
	pcall(restoreOpt)   -- graphics quality, FPS cap and every changed map property go back
	pcall(untint)
	pcall(function() local m = heldModel(); if m and math.abs(m:GetScale() - 1) > 1e-3 then m:ScaleTo(1) end end)
	pcall(unFov)
	for _, i in ipairs({ wGrade, wBloom, wRays }) do pcall(function() i:Destroy() end) end
	st.on = false; pcall(unstretch)
	for _, t in ipairs(active) do pcall(function() t.core:Destroy(); t.glow:Destroy(); t.a0:Destroy(); t.a1:Destroy() end) end
	for _, t in ipairs(pool) do pcall(function() t.core:Destroy(); t.glow:Destroy(); t.a0:Destroy(); t.a1:Destroy() end) end
	table.clear(active); table.clear(pool)
	freeCursor = false
	restoreArms()
	g(function()
		if WM.createAnimated == wrapCA then WM.createAnimated = origCreateAnimated end
		if WM.create == wrapC then WM.create = origCreate end
		if FC and FC.bind == wrapBind then FC.bind = origBind end
		fxApi.unshot()
	end)
	pcall(fxApi.unhook)
	for _, c in ipairs(conns) do pcall(function() c:Disconnect() end) end
	pcall(function() overlayGui:Destroy() end)
	_G.PistolDuelsSkinChanger = nil
	if ui and not ui.Dead then pcall(function() ui:Destroy() end) end
end
ui:OnUnload(unload)   -- the window's own close, or this script being run again, cleans up too

ui:Start()

_G.PistolDuelsSkinChanger = {
	unload = unload, ui = ui, sa = sa, sel = sel, pat = pat, wear = wear, hits = function() return hits end, reEquip = reEquip,
	tr = tr, spin = spin, st = st, wd = wd, mb = mb, vm = vm, opt = opt, applyOpt = applyOpt, applyWorld = applyWorld,
	tints = tints, ammoFx = ammoFx, shuffle = shuffle, tracer = spawnTracer,
	hideArms = function() return hideArms end, freeCursor = function() return freeCursor end,
}
print(("[SkinChanger] ready on Meowthjrlib: %d weapons, %d skins"):format(#weapons, (function() local n = 0 for _, l in pairs(skinsOf) do n += #l end return n end)()))
