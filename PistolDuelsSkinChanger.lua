pcall(function() game:GetService("RunService"):UnbindFromRenderStep("PDSkinChangerPlayers") end)
-- PISTOL DUELS | Skin Changer (local only)  |  made by meowthjr & Claude
--
-- WHAT IT DOES
--   Pick any Glock, Tec-9, Deagle or Knife skin and your own gun shows it, even skins you don't own.
--   Only YOU see the change. Other players, your inventory, trades and purchases are not touched.
--   Skins that only staff can give out are listed too, marked Staff at the end of each weapon's list.
--
-- HOW TO USE
--   1. Run the script. A window opens. RightShift hides or shows it.
--   2. Pick a weapon on the left, then click a skin on the right (click it again to turn it off).
--   3. If you are holding that weapon it updates by itself. Otherwise it shows the next time you equip it.
--   4. Patterned skins (the ones with a Pattern box) also let you choose the pattern number and wear.
--   5. Effects tab: bullet tracers on your own shots (color, thickness, lifetime, glow, streak) and a spin on your own
--      weapon model (speed, direction, axis, behavior). Header: Hide arms, Free cursor (RightCtrl).
--   6. Display tab: stretched resolution, a keystrokes/FPS overlay and a highlight on your own character.
--      World tab: color looks, glow and sun rays on your own screen.
--      Camera tab: motion blur, field of view and gun position.
--      Boost tab: more FPS (lower graphics quality, FPS cap, no post effects / particles / decals, plain materials).
--      Settings tab: hotkeys, window size, accent color, and Auto slide on jump (each jump presses slide for you,
--      so you land in a slide; hold jump to keep slide-jumping).
--   7. The panel right of the window shows a turning 3D preview of the skin under your mouse, can tint your gun, and
--      gives each weapon any ammo FX (tracer, sparks, muzzle flash, impacts, shot sound and kill effect).
--   8. Star skins to favorite them, save whole skin sets in Loadouts, or turn on Shuffle for a random skin per equip.
--   Your choices are saved and come back the next time you run the script.
--   Note: a skin only shows up on a weapon that is in your loadout (the pistol slot or the knife slot).

if _G.PistolDuelsSkinChanger and _G.PistolDuelsSkinChanger.unload then pcall(_G.PistolDuelsSkinChanger.unload) end

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local UIS = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local lp = Players.LocalPlayer
local function requireGame(module: Instance): any
    assert(module:IsA("ModuleScript"), "Expected a game ModuleScript")
    return require(module)
end

local SAVE_FILE = "pistol_duels_skin_changer.json"
local alive = true
local conns = {}
local function keep(c) conns[#conns + 1] = c; return c end

-- online counter: while the script runs it pings the counter every 30 seconds with a random id made up for
-- this run, a random id kept on this PC (so switching servers doesn't count you twice) and the number of the server
-- you're in (SERVER #n in the game's server list) with its region. Active pings also share your Roblox username on the public counter. The
-- counts show on the counter's page.
local onlineGone = function() end
do
	local ONLINE_URL = "https://pd-online.meowthjr.workers.dev"   -- the counter's address, empty = off
	local ID_FILE = "pistol_duels_online_id.txt"
	local send = (type(request) == "function" and request)
		or (type(http_request) == "function" and http_request)
		or (type(syn) == "table" and type(syn.request) == "function" and syn.request)
		or (type(http) == "table" and type(http.request) == "function" and http.request)
	if send and ONLINE_URL ~= "" then
		local runId = HttpService:GenerateGUID(false)
		local userId   -- made up the first time and kept in the executor's workspace; nil if the executor has no files
		pcall(function()
			if type(isfile) == "function" and isfile(ID_FILE) then userId = string.match(readfile(ID_FILE), "%x+%-%x+%-%x+%-%x+%-%x+") end
			if not userId and type(writefile) == "function" then userId = HttpService:GenerateGUID(false); writefile(ID_FILE, userId) end
		end)
		-- the server number comes from the game's own server list (what its server browser asks for every 10 s while
		-- it's open): asked once at the start and every 10 minutes, and also read whenever the browser gets a list
		local server, region, lobby
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
						for _, s in ipairs(msg.servers) do
							if type(s) == "table" and (s.current == true or s.id == game.JobId) then
								server, region = tonumber(s.number), type(s.region) == "string" and s.region or nil
							end
						end
					end))
				end
			end
			if lobby then pcall(function() lobby:FireServer({ kind = "Servers" }) end) end
		end
		local function ping(gone)
			pcall(send, {
				Url = ONLINE_URL .. "/ping", Method = "POST", Headers = { ["Content-Type"] = "application/json" },
				Body = HttpService:JSONEncode({ id = runId, user = userId, gone = gone or nil, server = server, region = region, username = not gone and lp.Name or nil }),
			})
		end
		task.spawn(function()
			local beats = 0
			while alive do
				if beats % 20 == 0 then   -- every 10 minutes
					pcall(askServer)
					local t0 = os.clock()
					while alive and not server and os.clock() - t0 < 5 do task.wait(0.2) end   -- the list takes a moment
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
	pcall(function()
		FC = requireGame(lp.PlayerScripts.Client.Cosmetics.FinishClient)
	end)
	pcall(function()
		CE = requireGame(lp.PlayerScripts.Client.Effects.CosmeticEffects)
	end)
end)
if not (SkinCatalog and WM) then
	local cos = RS:FindFirstChild("Cosmetics")
	if cos and cos:FindFirstChild("SkinCatalog") then
		warn("[SkinChanger] Your executor can't run the game's own scripts" .. (setIdentity and "" or " (it has no setthreadidentity)")
			.. ", which this script needs. Try an executor that supports setthreadidentity / require on game modules. Nothing was changed.")
	else
		warn("[SkinChanger] This doesn't look like Pistol Duels (its skin scripts were not found), so nothing was changed.")
	end
	return
end

-- ===================== saved choices =====================
local sel, pat, wear = {}, {}, {}   -- weapon -> skin id / pattern number / wear
local sa = { binds = {}, cameraHold = "MouseButton2", esp = { page = nil :: Frame?, cleanup = nil :: (() -> ())?, skeleton = true, headDot = true, hideTeam = true, practice = true, thickness = 1.5, dotRadius = 3 }, targetMode = "Closest Part", headWeight = 20, bodyWeight = 50, limbWeight = 30, cameraHead = false, cameraRadius = 80, cameraShowFov = true, cameraOn = false, cameraSmooth = true, cameraSpeed = 8, menuOpen = true, showFov = true, radius = 120, on = false, fov = 20, range = 250, players = true, npcs = true, head = false }
local seenHelp = false
local hideArms = false
-- effect settings (the Effects tab): bullet tracers on your own shots, and a spin on your own weapon model
local tr = { on = false, color = "Cyan", thick = 0.12, life = 0.6, glow = true, streak = false, replace = true }
local spin = { on = false, speed = 180, dir = 1, axis = "Y", mode = "Continuous" }
local st = { on = false, amount = 0.35 }   -- stretched resolution (Display tab)
local hud = { on = false, keys = true, stats = true, px = 24, py = 240 }   -- keystrokes + FPS/ping overlay (Display tab)
local wd = { on = false, preset = "Natural", tint = 1, sat = 0, con = 0, dark = 0, bloom = 0, rays = 0 }   -- World look (World tab)
local mb = { on = false, strength = 12, threshold = 120, smooth = 0.12 }   -- motion blur when turning fast (Camera tab)
local vm = { on = false, fov = 0, size = 1, x = 0, y = 0, z = 0 }   -- field of view, gun size and position (Camera tab)
local opt = { on = false, cap = 240, quality = 3, post = true, particles = true, textures = false, plain = false }   -- FPS boost (Boost tab)
local tints = {}   -- weapon -> { on, color, strength }: each weapon's own tint (Skins tab, next to the preview)
local ammoFx = {}  -- weapon -> ammo FX id ("Red", "Prism", "Bloxxed", or "None" for no FX); missing = the game's own
local function tintOf(w)
	if not tints[w] then tints[w] = { on = false, color = "Cyan", strength = 0.45 } end
	return tints[w]
end
local ui = { scale = 1, accent = "Blue", keyMenu = "RightShift", keyCursor = "RightControl", keyView = "X", slideJump = false }   -- window size, accent, hotkeys, auto slide on jump (Settings tab)
local shuffle = { on = false }   -- random skin each time you equip (Skins tab)
local fav = {}        -- skin id -> true (starred skins sort first)
local loadouts = {}   -- "1".."3" -> { sel = {}, pat = {}, wear = {} }
pcall(function()
	local function mergeInto(dst, src)
		if type(src) ~= "table" then return end
		for k, v in pairs(dst) do if type(src[k]) == type(v) then dst[k] = src[k] end end
	end
	if type(readfile) == "function" and type(isfile) == "function" and isfile(SAVE_FILE) then
		local d = HttpService:JSONDecode(readfile(SAVE_FILE))
		if type(d) == "table" then
			for k, v in pairs(type(d.sel) == "table" and d.sel or {}) do if type(v) == "string" then sel[k] = v end end
			for k, v in pairs(type(d.pat) == "table" and d.pat or {}) do if type(v) == "number" then pat[k] = v end end
			for k, v in pairs(type(d.wear) == "table" and d.wear or {}) do if type(v) == "number" then wear[k] = v end end
			seenHelp = d.seenHelp == true
			hideArms = d.hideArms == true
			mergeInto(sa.esp, d.esp); mergeInto(sa, d.sa); mergeInto(tr, d.tr); mergeInto(spin, d.spin); mergeInto(st, d.st); mergeInto(hud, d.hud); mergeInto(wd, d.wd); mergeInto(mb, d.mb)
			mergeInto(vm, d.vm); mergeInto(opt, d.opt); mergeInto(ui, d.ui)
			for w, v in pairs(type(d.tints) == "table" and d.tints or {}) do
				if type(v) == "table" then
					tints[w] = { on = v.on == true, color = type(v.color) == "string" and v.color or "Cyan", strength = type(v.strength) == "number" and v.strength or 0.45 }
				end
			end; mergeInto(shuffle, d.shuffle)
			for w, v in pairs(type(d.ammoFx) == "table" and d.ammoFx or {}) do if type(v) == "string" then ammoFx[w] = v end end
			for k, v in pairs(type(d.fav) == "table" and d.fav or {}) do if v == true then fav[k] = true end end
			for k, v in pairs(type(d.loadouts) == "table" and d.loadouts or {}) do
				if type(v) == "table" and type(v.sel) == "table" then
					local lo = { sel = {}, pat = {}, wear = {} }
					for w, id in pairs(v.sel) do if type(id) == "string" then lo.sel[w] = id end end
					for w, n in pairs(type(v.pat) == "table" and v.pat or {}) do if type(n) == "number" then lo.pat[w] = n end end
					for w, n in pairs(type(v.wear) == "table" and v.wear or {}) do if type(n) == "number" then lo.wear[w] = n end end
					loadouts[tostring(k)] = lo
				end
			end
		end
	end
end)
local function save()
	pcall(function()
		if type(writefile) == "function" then
			writefile(SAVE_FILE, HttpService:JSONEncode({ esp = { skeleton = sa.esp.skeleton, headDot = sa.esp.headDot, hideTeam = sa.esp.hideTeam, practice = sa.esp.practice, thickness = sa.esp.thickness, dotRadius = sa.esp.dotRadius }, sa = { binds = sa.binds, cameraHold = sa.cameraHold, on = sa.on, cameraOn = sa.cameraOn, targetMode = sa.targetMode, headWeight = sa.headWeight, bodyWeight = sa.bodyWeight, limbWeight = sa.limbWeight, cameraHead = sa.cameraHead, cameraRadius = sa.cameraRadius, cameraShowFov = sa.cameraShowFov, cameraSmooth = sa.cameraSmooth, cameraSpeed = sa.cameraSpeed, radius = sa.radius, showFov = sa.showFov, fov = sa.fov, range = sa.range, players = sa.players, npcs = sa.npcs, head = sa.head }, sel = sel, pat = pat, wear = wear, seenHelp = seenHelp, hideArms = hideArms, tr = tr, spin = spin, st = st, hud = hud, wd = wd, mb = mb,
				vm = vm, opt = opt, tints = tints, ammoFx = ammoFx, ui = ui, shuffle = shuffle, fav = fav, loadouts = loadouts }))
		end
	end)
end

for _, key in ipairs({ "headWeight", "bodyWeight", "limbWeight" }) do sa[key] = math.clamp(sa[key], 0, 100) end; if not table.find({ "Head", "Body", "Closest Part", "Weighted Random" }, sa.targetMode) then sa.targetMode = "Closest Part" end; sa.cameraRadius = math.clamp(sa.cameraRadius, 10, 600); sa.cameraSpeed = math.clamp(sa.cameraSpeed, 1, 30); sa.radius = math.clamp(sa.radius, 10, 600); sa.fov = math.clamp(sa.fov, 1, 120); sa.range = math.clamp(sa.range, 10, 1000)
local function keyOf(name)
	local ok, k = pcall(function() return Enum.KeyCode[name] end)
	return ok and k or nil
end
if not keyOf(ui.keyMenu) then ui.keyMenu = "RightShift" end
if not keyOf(ui.keyCursor) then ui.keyCursor = "RightControl" end
if not keyOf(ui.keyView) then ui.keyView = "X" end
ui.scale = math.clamp(ui.scale, 0.6, 1.4)

-- ===================== skin lists =====================
local weapons, skinsOf, displayOf, byId = {}, {}, {}, {}
g(function()
	local RANK = { Secret = 1, Exclusive = 2, Knife = 3, Legendary = 4, Epic = 5, Rare = 6, Uncommon = 7 }
	local order = type(SkinCatalog.WeaponOrder) == "table" and SkinCatalog.WeaponOrder or { "Glock", "Tec9", "Deagle", "Knife" }
	local names = type(SkinCatalog.WeaponNames) == "table" and SkinCatalog.WeaponNames or {}
	local colors = type(SkinCatalog.RarityColors) == "table" and SkinCatalog.RarityColors or {}
	for _, w in ipairs(order) do
		local list = {}
		for id, it in pairs(SkinCatalog.Items) do
			if it.weapon == w and not it.standard then
				-- skins only staff can be given are listed too, marked Staff and kept at the end of the list
				local staff = it.adminOnly == true or string.find(tostring(id), "^admin_") ~= nil
				local c = colors[it.rarity]
				local s = {
					id = id, display = it.name or id, rarity = staff and "Staff" or tostring(it.rarity or ""),
					color = typeof(c) == "Color3" and c or nil, patterned = it.procedural ~= nil, weapon = w, staff = staff,
					exclusiveFx = type(it.exclusiveFx) == "string" and it.exclusiveFx or nil,   -- FX that comes with the skin
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
for w, id in pairs(sel) do if not (byId[id] and byId[id].weapon == w) then sel[w] = nil end end

local function clampPat(n) return math.clamp(math.floor((tonumber(n) or 1) + 0.5), 1, 1000) end
local function clampWear(n) return math.clamp(tonumber(n) or 0, 0, 1) end

-- ===================== the hooks =====================
-- The game builds your gun in one place (CombatController's "model" function). We only swap the skin there, so the
-- inventory, the inspect screen, trades and the final-kill replay keep showing the real thing.
local hits = 0
local function fromCombat()
	local tb = debug.traceback("", 3)
	return string.find(tb, "CombatController:%d+ function model") ~= nil
end

local origCreateAnimated, origCreate, origBind = WM.createAnimated, WM.create, FC and FC.bind
local wrapCA, wrapC, wrapBind

-- Shuffle: each time the game builds your weapon a random skin is rolled (from your starred skins for that weapon, or
-- all of them if none are starred). The game makes a few calls per build, so calls close together share one roll.
local rolled, rollAt = {}, {}
local function pickFor(w)
	if not shuffle.on then return sel[w], pat[w], wear[w] end
	local now = os.clock()
	if not rolled[w] or now - (rollAt[w] or 0) > 0.5 then
		local favs, rest = {}, {}
		for _, s in ipairs(skinsOf[w] or {}) do
			if fav[s.id] then favs[#favs + 1] = s elseif not s.staff then rest[#rest + 1] = s end   -- Staff skins only when starred
		end
		local from = #favs > 0 and favs or rest
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
local function showingNow(weapon)   -- true when the weapon in your hands is the chosen skin
	local m, w = heldModel()
	local want = (shuffle.on and rolled[weapon] and rolled[weapon].id) or sel[weapon]
	return m ~= nil and w == weapon and m:GetAttribute("PDSkinId") == want
end

-- ===================== invisible arms =====================
-- Hides the arms/hands of your viewmodel so they don't cover the skin. Done every frame (after the game's own update)
-- because the game keeps setting the arm transparency itself.
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local armOrig = setmetatable({}, { __mode = "k" })       -- arm part -> its own transparency (to put back)
local trackedModels = setmetatable({}, { __mode = "k" }) -- model -> { parts = { [part] = true } }
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
local freeCursor = false
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
local spawnTracer, stepTracers
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
local function recycle(t)
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

local fxApi = {}   -- unshot() puts the game's shot effect back; the ammo FX block below adds order, name, color, prism, unhook
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
-- Ammo FX is what a skin copy can carry on top of its finish: a color (or Prism) for your bullets, tracer, sparks,
-- muzzle flash, impacts and shot sound, and its own kill effect (Bloxxed is a kill effect only). The game asks its
-- inventory which FX the weapon in your hands has, and uses the answer only for the effects on your own screen (the
-- shot it sends the server has no FX in it). Answering with the one picked here changes how your shots look to you,
-- and nothing else. Other players keep seeing your real FX.
do
local FXC
g(function() FXC = requireGame(RS.Cosmetics.AmmoFXCatalog) end)
fxApi.color = function(id) return FXC and FXC.color(id) end
fxApi.prism = FXC and FXC.Prism
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
local function hookFx()   -- answer the game's "which FX does this weapon have?" with the pick (found once, read only)
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
-- kills by your own shots: the server sends the FX of the weapon that hit, so the kill effect follows the pick too
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
-- Resizes and moves the gun (and arms) in YOUR view after the game has placed it. The game puts it back every frame,
-- so the offset never adds up. Size: ScaleTo grows the model around its root, which sits at your eye, so on its own a
-- bigger gun would just be pushed further away and look the same. It is slid back so its middle stays where the
-- game put it, which makes it show bigger in the same spot.
do
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
end

local fxWarned = {}
local function guarded(name, fn)
	local ok, e = pcall(fn)
	if not ok and not fxWarned[name] then fxWarned[name] = true; warn("[SkinChanger] " .. name .. " error: " .. tostring(e)) end
end
-- the game's ammo FX coats (the glowing layer on your rounds) were put on them before the gun is moved or spun here:
-- move the ones on the gun along with it, so they don't stay behind where the game had put the gun
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

-- ===================== stretched resolution =====================
-- Flattens your camera vertically (the usual stretched-res trick) so everything looks wider, like a stretched resolution. Only your own screen changes.
-- The stretch is taken off again right before the game's camera code runs each frame, so the game never sees it.
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
-- Field of view works the same way: added on top of the game's own value (so zooming in still works) and taken off
-- again before the game's camera code runs.
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
-- Blurs your screen while you turn the camera fast and fades back to sharp when you stop. Measures how fast the
-- camera turns each frame (right after the game's camera code, before the stretch is put on) and sizes a blur to match.
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

-- ===================== window =====================
local ACCENTS = {
	{ id = "Blue", color = Color3.fromRGB(94, 138, 255) }, { id = "Purple", color = Color3.fromRGB(150, 105, 255) },
	{ id = "Pink", color = Color3.fromRGB(236, 92, 170) }, { id = "Red", color = Color3.fromRGB(230, 80, 80) },
	{ id = "Orange", color = Color3.fromRGB(240, 145, 60) }, { id = "Green", color = Color3.fromRGB(70, 185, 120) },
	{ id = "Teal", color = Color3.fromRGB(40, 170, 190) },
}
local function accentOf(id)
	for _, a in ipairs(ACCENTS) do if a.id == id then return a.color end end
	return ACCENTS[1].color
end
local C = {
	bg = Color3.fromRGB(13, 14, 19), white = Color3.fromRGB(255, 255, 255), accent = accentOf(ui.accent),
	text = Color3.fromRGB(240, 241, 246), dim = Color3.fromRGB(158, 163, 181),
	good = Color3.fromRGB(110, 214, 144), warn = Color3.fromRGB(243, 186, 98),
}
local accentObjs = {}   -- { instance, property } drawn in the accent color, recolored when it changes
local gui = Instance.new("ScreenGui")
gui.Name = "PistolDuelsSkinChanger"; gui.ResetOnSpawn = false; gui.DisplayOrder = 50; gui.IgnoreGuiInset = true
pcall(function() if type(syn) == "table" and syn.protect_gui then syn.protect_gui(gui) end end)
do   -- gethui can throw on some executors, so every parent is tried in turn
	local parents = {
		function() return type(gethui) == "function" and gethui() or nil end,
		function() return game:GetService("CoreGui") end,
		function() return lp:WaitForChild("PlayerGui", 5) end,
	}
	for _, get in ipairs(parents) do
		local ok, p = pcall(get)
		if ok and typeof(p) == "Instance" then
			local okP = pcall(function() gui.Parent = p end)
			if okP and gui.Parent == p then break end
		end
	end
	if not gui.Parent then warn("[SkinChanger] Couldn't place the window anywhere."); return end
end

local function corner(o, r) local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, r or 8); c.Parent = o end
local make
local function stroke(o, transparency, color, thickness)
	return make("UIStroke", { Color = color or C.white, Transparency = transparency or 0.88, Thickness = thickness or 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, o)
end
make = function(class, props, parent)
	local o = Instance.new(class)
	for k, v in pairs(props) do o[k] = v end
	o.Parent = parent
	return o
end
local function text(parent, str, size, color, pos, sz, align, font)
	return make("TextLabel", {
		BackgroundTransparency = 1, Text = str, TextSize = size, Font = font or Enum.Font.BuilderSans, TextColor3 = color or C.text,
		Position = pos, Size = sz, TextXAlignment = align or Enum.TextXAlignment.Left, TextWrapped = true,
	}, parent)
end
-- soft "glass" button: see-through, brightens on hover
local function button(parent, str, pos, sz, accent)
	local base = accent and 0.15 or 0.92
	local b = make("TextButton", {
		Text = str, Position = pos, Size = sz, BackgroundColor3 = accent and C.accent or C.white, BackgroundTransparency = base,
		TextColor3 = C.text, Font = Enum.Font.BuilderSansMedium, TextSize = 13, AutoButtonColor = false,
	}, parent)
	corner(b, 8)
	if accent then accentObjs[#accentObjs + 1] = { b, "BackgroundColor3" } end
	b.MouseEnter:Connect(function() b.BackgroundTransparency = accent and 0.05 or 0.84 end)
	b.MouseLeave:Connect(function() b.BackgroundTransparency = base end)
	return b
end
local function inputBox(parent, pos, sz, placeholder)
	local t = make("TextBox", {
		Position = pos, Size = sz, BackgroundColor3 = C.white, BackgroundTransparency = 0.92, TextColor3 = C.text,
		PlaceholderText = placeholder, PlaceholderColor3 = C.dim, Text = "", Font = Enum.Font.BuilderSans, TextSize = 13, ClearTextOnFocus = false,
	}, parent)
	corner(t, 8)
	return t
end

local applyHud
local SIDE = 146   -- width of the menu on the left; every page sits to the right of it
local win = make("Frame", {
	Size = UDim2.fromOffset(640 + SIDE, 556), Position = UDim2.new(0.5, -(640 + SIDE) / 2, 0.5, -278), BackgroundColor3 = C.bg,
	BackgroundTransparency = 0.2, BorderSizePixel = 0,
}, gui)
corner(win, 14)
stroke(win, 0.86)

-- no on-screen tab when hidden (so nobody can see you use it): RightShift brings the window back
local function setOpen(open) sa.menuOpen = open; win.Visible = open end

-- header: title on the left, arms switch + small buttons on the right
local top = make("Frame", { Size = UDim2.new(1, 0, 0, 52), BackgroundTransparency = 1 }, win)
do   -- logo mark + title
	local mark = make("Frame", { Position = UDim2.fromOffset(16, 11), Size = UDim2.fromOffset(30, 30), BackgroundColor3 = C.accent, BorderSizePixel = 0 }, top)
	corner(mark, 9)
	accentObjs[#accentObjs + 1] = { mark, "BackgroundColor3" }
	make("UIGradient", { Rotation = 45, Transparency = NumberSequence.new(0, 0.35) }, mark)
	text(mark, "PD", 13, C.white, UDim2.new(), UDim2.fromScale(1, 1), Enum.TextXAlignment.Center, Enum.Font.BuilderSansBold)
	text(top, "Meowthjr's legit menu", 17, C.text, UDim2.fromOffset(56, 9), UDim2.fromOffset(220, 20), nil, Enum.Font.BuilderSansBold)
	text(top, "Pistol Duels  ·  made by meowthjr & Claude", 11, C.dim, UDim2.fromOffset(56, 28), UDim2.fromOffset(260, 14))
end
local closeBtn = button(top, "×", UDim2.new(1, -44, 0, 12), UDim2.fromOffset(30, 28))
local hideBtn = button(top, "–", UDim2.new(1, -78, 0, 12), UDim2.fromOffset(30, 28))
local helpBtn = button(top, "?", UDim2.new(1, -112, 0, 12), UDim2.fromOffset(30, 28))
closeBtn.TextSize = 18

-- small on/off switches in the header
local setStatus
local function makeSwitch(label, labelX, switchX, labelW, get)
	text(top, label, 12, C.dim, UDim2.new(1, labelX, 0, 0), UDim2.fromOffset(labelW, 52), Enum.TextXAlignment.Right)
	local sw = make("TextButton", {
		Text = "", AutoButtonColor = false, Position = UDim2.new(1, switchX, 0, 16), Size = UDim2.fromOffset(38, 20),
		BackgroundColor3 = C.white, BackgroundTransparency = 0.82,
	}, top)
	corner(sw, 10)
	local knob = make("Frame", { Size = UDim2.fromOffset(16, 16), Position = UDim2.fromOffset(2, 2), BackgroundColor3 = C.text, BorderSizePixel = 0 }, sw)
	corner(knob, 8)
	local function paint(animate)
		local on = get()
		local goal = { BackgroundColor3 = on and C.accent or C.white, BackgroundTransparency = on and 0.1 or 0.82 }
		local kpos = on and UDim2.fromOffset(20, 2) or UDim2.fromOffset(2, 2)
		if animate then
			TweenService:Create(sw, TweenInfo.new(0.15), goal):Play()
			TweenService:Create(knob, TweenInfo.new(0.15), { Position = kpos }):Play()
		else
			for k, v in pairs(goal) do sw[k] = v end
			knob.Position = kpos
		end
	end
	paint(false)
	return sw, paint
end

-- Hide arms
local armsSw, paintArms = makeSwitch("Hide arms", -226, -158, 62, function() return hideArms end)
local function setHideArms(on)
	hideArms = on and true or false
	paintArms(true); save()
	if hideArms then enforceArms() else restoreArms() end
end
armsSw.MouseButton1Click:Connect(function()
	setHideArms(not hideArms)
	setStatus(hideArms and "Arms hidden. They stay hidden when you switch weapons." or "Arms are back.", "good")
end)

-- Free cursor: keeps your mouse unlocked in first person so you can click the window without pressing Esc
local cursorSw, paintCursor = makeSwitch("Free cursor", -334, -260, 70, function() return freeCursor end)
local function setFreeCursor(on)
	freeCursor = on and true or false
	paintCursor(true)
	if freeCursor then enforceCursor() end
end
cursorSw.MouseButton1Click:Connect(function()
	setFreeCursor(not freeCursor)
	setStatus(freeCursor and ("Cursor unlocked. Move the mouse freely. (" .. ui.keyCursor .. " turns it off again.)") or "Cursor is locked to the camera again.", "good")
end)
make("Frame", { Position = UDim2.new(0, 14, 1, -1), Size = UDim2.new(1, -28, 0, 1), BackgroundColor3 = C.white, BackgroundTransparency = 0.9, BorderSizePixel = 0 }, top)

-- dragging by the header
do
	local dragging, startPos, startMouse
	keep(top.InputBegan:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 then dragging = true; startPos = win.Position; startMouse = i.Position end
	end))
	keep(UIS.InputChanged:Connect(function(i)
		if dragging and i.UserInputType == Enum.UserInputType.MouseMovement then
			local d = i.Position - startMouse
			win.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
		end
	end))
	keep(UIS.InputEnded:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end end))
end

-- bottom row: status text on the left, buttons on the right
local bar = make("Frame", { Position = UDim2.new(0, 14, 1, -50), Size = UDim2.new(1, -28, 0, 38), BackgroundTransparency = 1 }, win)
local status = text(bar, "", 12, C.dim, UDim2.fromOffset(2, 0), UDim2.new(1, -334, 1, 0))
local reBtn = button(bar, "Re-equip", UDim2.new(1, -326, 0, 4), UDim2.fromOffset(98, 30))
local resetOne = button(bar, "Reset this one", UDim2.new(1, -222, 0, 4), UDim2.fromOffset(110, 30))
local resetAll = button(bar, "Reset all", UDim2.new(1, -106, 0, 4), UDim2.fromOffset(106, 30))
local resetFx = button(bar, "Reset effects", UDim2.new(1, -126, 0, 4), UDim2.fromOffset(126, 30))
resetFx.Visible = false
setStatus = function(t, kind)
	status.Text = t
	status.TextColor3 = (kind == "good" and C.good) or (kind == "warn" and C.warn) or C.dim
end

-- page tabs
-- menu on the left: one row per page, the open one marked with an accent bar
local tabBtns = {}   -- page name -> menu row
do
	local side = make("Frame", { Position = UDim2.fromOffset(10, 62), Size = UDim2.new(0, SIDE - 18, 1, -72), BackgroundColor3 = C.white, BackgroundTransparency = 0.96, BorderSizePixel = 0 }, win)
	corner(side, 12); stroke(side, 0.94)
	text(side, "MENU", 10, C.dim, UDim2.fromOffset(14, 10), UDim2.new(1, -28, 0, 12), nil, Enum.Font.BuilderSansMedium)
	for i, t in ipairs({ { "skins", "Skins" }, { "fx", "Effects" }, { "boost", "Boost" }, { "display", "Display" }, { "world", "World" }, { "camera", "Camera" }, { "settings", "Settings" }, { "aim", "Not So Legit" } }) do
		local b = make("TextButton", {
			Position = UDim2.fromOffset(6, 28 + (i - 1) * 36), Size = UDim2.new(1, -12, 0, 32), BackgroundColor3 = C.white, BackgroundTransparency = 1,
			Text = t[2], TextColor3 = C.dim, Font = Enum.Font.BuilderSansMedium, TextSize = 14, TextXAlignment = Enum.TextXAlignment.Left, AutoButtonColor = false,
		}, side)
		corner(b, 8)
		make("UIPadding", { PaddingLeft = UDim.new(0, 16) }, b)
		local mark = make("Frame", { Name = "Bar", Position = UDim2.new(0, -10, 0.5, -8), Size = UDim2.fromOffset(3, 16), BackgroundColor3 = C.accent, BorderSizePixel = 0, Visible = false }, b)
		corner(mark, 2)
		b.MouseEnter:Connect(function() if not b:GetAttribute("Active") then b.BackgroundTransparency = 0.93 end end)
		b.MouseLeave:Connect(function() if not b:GetAttribute("Active") then b.BackgroundTransparency = 1 end end)
		tabBtns[t[1]] = b
	end
	text(side, ui.keyMenu .. "  hide\n" .. ui.keyCursor .. "  cursor", 10, C.dim, UDim2.new(0, 14, 1, -36), UDim2.new(1, -28, 0, 28))
end

-- two glass panels: weapons (left) and skins (right)
local function column(title)
	local f = make("Frame", { BackgroundColor3 = C.white, BackgroundTransparency = 0.95, BorderSizePixel = 0 }, win)
	corner(f, 12)
	stroke(f, 0.93)
	local t = text(f, title, 11, C.dim, UDim2.fromOffset(14, 9), UDim2.new(1, -28, 0, 14), nil, Enum.Font.BuilderSansMedium)
	local s = make("ScrollingFrame", {
		BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 3, ScrollBarImageColor3 = C.white,
		ScrollBarImageTransparency = 0.6, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
	}, f)
	make("UIListLayout", { Padding = UDim.new(0, 4) }, s)
	make("UIPadding", { PaddingRight = UDim.new(0, 4) }, s)
	return { frame = f, title = t, scroll = s }
end
local left = column("WEAPONS")
left.frame.Position = UDim2.fromOffset(14, 96); left.frame.Size = UDim2.new(0, 158, 1, -156)
left.scroll.Position = UDim2.fromOffset(6, 30); left.scroll.Size = UDim2.new(1, -12, 0, 144)   -- shuffle + loadouts sit below
local right = column("SKINS")
right.frame.Position = UDim2.fromOffset(180, 96); right.frame.Size = UDim2.new(1, -194, 1, -156)
local search = make("TextBox", {
	Position = UDim2.fromOffset(10, 30), Size = UDim2.new(1, -20, 0, 28), BackgroundColor3 = C.white, BackgroundTransparency = 0.92,
	TextColor3 = C.text, PlaceholderText = "Search skins, rarity, or \"fav\"...", PlaceholderColor3 = C.dim, Text = "", Font = Enum.Font.BuilderSans,
	TextSize = 13, ClearTextOnFocus = false, TextXAlignment = Enum.TextXAlignment.Left,
}, right.frame)
corner(search, 8)
make("UIPadding", { PaddingLeft = UDim.new(0, 10) }, search)

-- pattern / wear strip (only for patterned skins)
local strip = make("Frame", { Position = UDim2.fromOffset(10, 64), Size = UDim2.new(1, -20, 0, 28), BackgroundTransparency = 1, Visible = false }, right.frame)
text(strip, "Pattern", 12, C.dim, UDim2.fromOffset(2, 0), UDim2.fromOffset(46, 28))
local patBox = inputBox(strip, UDim2.fromOffset(50, 1), UDim2.fromOffset(56, 26), "1-1000")
text(strip, "Wear", 12, C.dim, UDim2.fromOffset(116, 0), UDim2.fromOffset(32, 28))
local wearBox = inputBox(strip, UDim2.fromOffset(150, 1), UDim2.fromOffset(56, 26), "0-1")
local randBtn = button(strip, "Random", UDim2.fromOffset(216, 1), UDim2.fromOffset(70, 26))
text(strip, "press Enter to apply", 11, C.dim, UDim2.fromOffset(294, 0), UDim2.new(1, -294, 0, 28))
local function layoutRight(showStrip)
	strip.Visible = showStrip
	right.scroll.Position = UDim2.fromOffset(6, showStrip and 98 or 66)
	right.scroll.Size = UDim2.new(1, -12, 1, showStrip and -104 or -72)
end
layoutRight(false)

local current      -- selected weapon
local weaponRows, skinRows = {}, {}
local refreshWeapons, refreshSkins
local showPreview   -- set by the preview panel: showPreview(skinId) for a hovered skin, showPreview(nil) for the picked one

-- a list row: optional rarity dot, name, small tag on the right; accent colour when in use
local function row(parent, name, tag, active, dot, star)   -- star = { on = bool, click = fn } adds a favorite star
	local b = make("TextButton", {
		Size = UDim2.new(1, -2, 0, 32), BackgroundColor3 = active and C.accent or C.white,
		BackgroundTransparency = active and 0.25 or 0.94, Text = "", AutoButtonColor = false,
	}, parent)
	corner(b, 8)
	local x = 12
	if dot then
		local d = make("Frame", { Size = UDim2.fromOffset(8, 8), Position = UDim2.new(0, 12, 0.5, -4), BackgroundColor3 = dot, BorderSizePixel = 0 }, b)
		corner(d, 4)
		x = 28
	end
	local label = text(b, name, 13, C.text, UDim2.fromOffset(x, 0), UDim2.new(1, -x - (star and 112 or 62), 1, 0))
	label.TextWrapped = false
	label.TextTruncate = Enum.TextTruncate.AtEnd
	if tag and tag ~= "" then
		text(b, tag, 11, active and C.text or C.dim, UDim2.new(1, star and -114 or -62, 0, 0), UDim2.fromOffset(star and 80 or 52, 32), Enum.TextXAlignment.Right)
	end
	if star then
		local s = make("TextButton", {
			Text = star.on and "★" or "☆", Position = UDim2.new(1, -30, 0, 4), Size = UDim2.fromOffset(24, 24), BackgroundTransparency = 1,
			TextColor3 = star.on and Color3.fromRGB(255, 205, 80) or C.dim, Font = Enum.Font.BuilderSansBold, TextSize = 16, AutoButtonColor = false,
		}, b)
		s.MouseButton1Click:Connect(star.click)
	end
	b.MouseEnter:Connect(function() if not active then b.BackgroundTransparency = 0.86 end end)
	b.MouseLeave:Connect(function() if not active then b.BackgroundTransparency = 0.94 end end)
	return b
end
local function note(parent, str, store)
	local l = text(parent, str, 12, C.dim, UDim2.new(), UDim2.new(1, -8, 0, 0))
	l.AutomaticSize = Enum.AutomaticSize.Y
	store[#store + 1] = l
	return l
end

function refreshWeapons()
	for _, b in pairs(weaponRows) do b:Destroy() end
	weaponRows = {}
	for _, w in ipairs(weapons) do
		local b = row(left.scroll, displayOf[w], sel[w] and "custom" or "", w == current)
		weaponRows[#weaponRows + 1] = b
		b.MouseButton1Click:Connect(function() current = w; search.Text = ""; refreshWeapons(); refreshSkins() end)
	end
end

local function syncStrip()
	local s = current and sel[current] and byId[sel[current]]
	layoutRight(s and s.patterned or false)
	if s and s.patterned then
		patBox.Text = tostring(pat[current] or 1)
		wearBox.Text = string.format("%.2f", wear[current] or 0)
	end
end

-- put the choice on the weapon in your hands (if it is that weapon), and tell the user what happened
local function afterChange(w, msgOn, msgOff)
	local _, held = heldModel()
	if held == w then
		task.spawn(function()
			setStatus("Re-equipping your " .. (displayOf[w] or w) .. "...", nil)
			reEquip()
			if not alive then return end
			if sel[w] then
				if showingNow(w) then setStatus(msgOn, "good") else setStatus("Saved. Switch to another weapon and back to see it.", "warn") end
			else
				setStatus(msgOff, "good")
			end
		end)
	else
		setStatus(sel[w] and ("Saved. It shows the next time you equip the " .. (displayOf[w] or w) .. ".") or msgOff, "good")
	end
end

function refreshSkins()
	for _, b in pairs(skinRows) do b:Destroy() end
	skinRows = {}
	if not current then
		right.title.Text = "SKINS"
		layoutRight(false)
		note(right.scroll, "Pick a weapon on the left.", skinRows)
		return
	end
	syncStrip()
	local q = string.lower(search.Text or "")
	local list = skinsOf[current] or {}
	local d = row(right.scroll, "My own skin (default)", sel[current] == nil and "in use" or "", sel[current] == nil)
	skinRows[#skinRows + 1] = d
	d.MouseButton1Click:Connect(function()
		local w = current
		sel[w] = nil; save(); refreshWeapons(); refreshSkins()
		afterChange(w, "", "Back to your own skin for the " .. (displayOf[w] or w) .. ".")
	end)
	local shown = 0
	local favOnly = (q == "fav" or q == "favs" or q == "favorites")
	local ordered = {}   -- starred skins first, each group in catalog order
	for _, s in ipairs(list) do if fav[s.id] then ordered[#ordered + 1] = s end end
	for _, s in ipairs(list) do if not fav[s.id] then ordered[#ordered + 1] = s end end
	for _, s in ipairs(ordered) do
		local match
		if favOnly then match = fav[s.id] == true
		else match = q == "" or string.find(string.lower(s.display), q, 1, true) or string.find(string.lower(s.rarity), q, 1, true) end
		if match then
			shown += 1
			local on = sel[current] == s.id
			local b = row(right.scroll, s.display, on and "in use" or s.rarity, on, s.color or C.dim, {
				on = fav[s.id] == true,
				click = function() fav[s.id] = (not fav[s.id]) or nil; save(); refreshSkins() end,
			})
			skinRows[#skinRows + 1] = b
			b.MouseEnter:Connect(function() if showPreview then showPreview(s.id) end end)
			b.MouseLeave:Connect(function() if showPreview then showPreview(nil) end end)
			b.MouseButton1Click:Connect(function()
				local w = current
				if sel[w] == s.id then sel[w] = nil else sel[w] = s.id end
				save(); refreshWeapons(); refreshSkins()
				afterChange(w, s.display .. " is on your " .. (displayOf[w] or w) .. ".", "Turned off. Your own skin is back on the " .. (displayOf[w] or w) .. ".")
			end)
		end
	end
	right.title.Text = "SKINS FOR " .. string.upper(displayOf[current] or current) .. "  ·  " .. (q == "" and #list or (shown .. " of " .. #list))
	if shown == 0 then note(right.scroll, "No skins match \"" .. (search.Text or "") .. "\".", skinRows) end
	if showPreview then showPreview(nil) end
end

keep(search:GetPropertyChangedSignal("Text"):Connect(refreshSkins))

-- pattern / wear boxes
local function applyLook()
	local w = current
	if not (w and sel[w]) then return end
	pat[w] = clampPat(patBox.Text); wear[w] = clampWear(wearBox.Text)
	patBox.Text = tostring(pat[w]); wearBox.Text = string.format("%.2f", wear[w])
	save()
	afterChange(w, "Pattern " .. pat[w] .. ", wear " .. string.format("%.2f", wear[w]) .. " applied.", "")
	if showPreview then showPreview(nil) end
end
patBox.FocusLost:Connect(function(enter) if enter then applyLook() end end)
wearBox.FocusLost:Connect(function(enter) if enter then applyLook() end end)
randBtn.MouseButton1Click:Connect(function()
	patBox.Text = tostring(math.random(1, 1000))
	applyLook()
end)

reBtn.MouseButton1Click:Connect(function()
	task.spawn(function()
		setStatus("Re-equipping...", nil)
		local ok = reEquip()
		if not alive then return end
		setStatus(ok and "Re-equipped. Your skins are rebuilt." or "Couldn't switch weapons from here. Press your weapon keys yourself.", ok and "good" or "warn")
	end)
end)
resetOne.MouseButton1Click:Connect(function()
	local w = current
	if not w then return end
	sel[w] = nil; pat[w] = nil; wear[w] = nil
	save(); refreshWeapons(); refreshSkins()
	afterChange(w, "", "Reset the " .. (displayOf[w] or w) .. ".")
end)
resetAll.MouseButton1Click:Connect(function()
	for k in pairs(sel) do sel[k] = nil end
	for k in pairs(pat) do pat[k] = nil end
	for k in pairs(wear) do wear[k] = nil end
	save(); refreshWeapons(); refreshSkins()
	local _, held = heldModel()
	if held then task.spawn(function() reEquip(); if alive then setStatus("Everything is back to normal.", "good") end end)
	else setStatus("Everything is back to normal.", "good") end
end)


-- ===================== Effects page =====================
local fxPage = make("Frame", { Position = UDim2.fromOffset(14, 96), Size = UDim2.new(1, -28, 1, -156), BackgroundTransparency = 1, Visible = false }, win)
local repaints = {}
local function card(x, w, title, page)
	local f = make("Frame", { Position = UDim2.new(x, x == 0 and 0 or 6, 0, 0), Size = UDim2.new(w, -6, 1, 0), BackgroundColor3 = C.white, BackgroundTransparency = 0.95, BorderSizePixel = 0 }, page or fxPage)
	corner(f, 12); stroke(f, 0.93)
	text(f, title, 14, C.text, UDim2.fromOffset(14, 10), UDim2.new(1, -90, 0, 20), nil, Enum.Font.BuilderSansBold)
	return f
end
local function toggleAt(parent, pos, get, set)
	local sw = make("TextButton", {
		Text = "", AutoButtonColor = false, Position = pos, Size = UDim2.fromOffset(38, 20), BackgroundColor3 = C.white, BackgroundTransparency = 0.82,
	}, parent)
	corner(sw, 10)
	local knob = make("Frame", { Size = UDim2.fromOffset(16, 16), Position = UDim2.fromOffset(2, 2), BackgroundColor3 = C.text, BorderSizePixel = 0 }, sw)
	corner(knob, 8)
	local function paint(animate)
		local on = get()
		local goal = { BackgroundColor3 = on and C.accent or C.white, BackgroundTransparency = on and 0.1 or 0.82 }
		local kpos = on and UDim2.fromOffset(20, 2) or UDim2.fromOffset(2, 2)
		if animate then
			TweenService:Create(sw, TweenInfo.new(0.15), goal):Play()
			TweenService:Create(knob, TweenInfo.new(0.15), { Position = kpos }):Play()
		else
			for k, v in pairs(goal) do sw[k] = v end
			knob.Position = kpos
		end
	end
	paint(false)
	sw.MouseButton1Click:Connect(function() set(not get()); paint(true); save() end)
	repaints[#repaints + 1] = function() paint(false) end
	return sw
end
local function toggleRow(parent, y, label, get, set)
	text(parent, label, 13, C.text, UDim2.fromOffset(14, y), UDim2.new(1, -70, 0, 20))
	toggleAt(parent, UDim2.new(1, -52, 0, y), get, set)
end
local function slider(parent, y, label, min, max, step, get, set, fmt)
	text(parent, label, 12, C.dim, UDim2.fromOffset(14, y), UDim2.new(1, -100, 0, 16))
	local val = text(parent, "", 12, C.text, UDim2.new(1, -94, 0, y), UDim2.fromOffset(80, 16), Enum.TextXAlignment.Right)
	local bar2 = make("Frame", { Position = UDim2.fromOffset(14, y + 26), Size = UDim2.new(1, -28, 0, 6), BackgroundColor3 = C.white, BackgroundTransparency = 0.85, BorderSizePixel = 0 }, parent)
	corner(bar2, 3)
	local fill = make("Frame", { Size = UDim2.new(0, 0, 1, 0), BackgroundColor3 = C.accent, BorderSizePixel = 0 }, bar2)
	corner(fill, 3)
	accentObjs[#accentObjs + 1] = { fill, "BackgroundColor3" }
	local knob = make("Frame", { Size = UDim2.fromOffset(14, 14), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0, 0, 0.5, 0), BackgroundColor3 = C.text, BorderSizePixel = 0 }, bar2)
	corner(knob, 7)
	local hit = make("TextButton", { Text = "", BackgroundTransparency = 1, Position = UDim2.fromOffset(0, -9), Size = UDim2.new(1, 0, 1, 18) }, bar2)
	local function paint()
		local v = get()
		local a = math.clamp((v - min) / (max - min), 0, 1)
		fill.Size = UDim2.new(a, 0, 1, 0); knob.Position = UDim2.new(a, 0, 0.5, 0); val.Text = fmt(v)
	end
	local dragging = false
	local function setFromX(x)
		local a = math.clamp((x - bar2.AbsolutePosition.X) / math.max(bar2.AbsoluteSize.X, 1), 0, 1)
		local v = math.floor((min + (max - min) * a) / step + 0.5) * step
		set(math.clamp(v, min, max)); paint()
	end
	hit.InputBegan:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 then dragging = true; setFromX(i.Position.X) end end)
	keep(UIS.InputChanged:Connect(function(i) if dragging and i.UserInputType == Enum.UserInputType.MouseMovement then setFromX(i.Position.X) end end))
	keep(UIS.InputEnded:Connect(function(i) if dragging and i.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false; save() end end))
	paint()
	repaints[#repaints + 1] = paint
end
local function segmented(parent, y, label, options, get, set)
	text(parent, label, 12, C.dim, UDim2.fromOffset(14, y), UDim2.new(1, -28, 0, 16))
	local holder = make("Frame", { Position = UDim2.fromOffset(14, y + 20), Size = UDim2.new(1, -28, 0, 28), BackgroundTransparency = 1 }, parent)
	make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 4) }, holder)
	local btns = {}
	local n = #options
	for i, o in ipairs(options) do
		local b = make("TextButton", {
			Text = o.text, Size = UDim2.new(1 / n, -4 * (n - 1) / n, 1, 0), BackgroundColor3 = C.white, BackgroundTransparency = 0.92,
			TextColor3 = C.text, Font = Enum.Font.BuilderSansMedium, TextSize = 12, AutoButtonColor = false,
		}, holder)
		corner(b, 8)
		btns[i] = b
		b.MouseButton1Click:Connect(function() set(o.id); for _, f in ipairs(repaints) do f() end; save() end)
	end
	local function paint()
		for i, o in ipairs(options) do
			local on = get() == o.id
			btns[i].BackgroundColor3 = on and C.accent or C.white
			btns[i].BackgroundTransparency = on and 0.2 or 0.92
		end
	end
	paint()
	repaints[#repaints + 1] = paint
end

-- Skins page, under the weapon list: shuffle and three loadout slots
-- (each page below is wrapped in do ... end so its helpers don't count toward Luau's 200-local limit)
do
text(left.frame, "Shuffle", 12, C.text, UDim2.fromOffset(14, 182), UDim2.new(1, -70, 0, 20))
toggleAt(left.frame, UDim2.new(1, -50, 0, 182), function() return shuffle.on end, function(v)
	shuffle.on = v
	table.clear(rolled)
	setStatus(v and "Shuffle on: a random skin each time you equip (from your starred skins if that weapon has any)."
		or "Shuffle off. Your picked skins are back.", "good")
	local _, held = heldModel()
	if held then task.spawn(reEquip) end
end)
text(left.frame, "LOADOUTS", 11, C.dim, UDim2.fromOffset(14, 214), UDim2.new(1, -28, 0, 14), nil, Enum.Font.BuilderSansMedium)
local loadBtns = {}
local function paintLoadouts()
	for slot, b in pairs(loadBtns) do b.TextColor3 = loadouts[slot] and C.text or C.dim end
end
local function copyLook(src)
	local d = { sel = {}, pat = {}, wear = {} }
	for k, v in pairs(src.sel) do d.sel[k] = v end
	for k, v in pairs(src.pat) do d.pat[k] = v end
	for k, v in pairs(src.wear) do d.wear[k] = v end
	return d
end
for i = 1, 3 do
	local slot = tostring(i)
	local y = 232 + (i - 1) * 34
	local loadBtn = button(left.frame, "Loadout " .. i, UDim2.fromOffset(10, y), UDim2.new(1, -76, 0, 28))
	local saveBtn = button(left.frame, "Save", UDim2.new(1, -62, 0, y), UDim2.fromOffset(52, 28))
	loadBtn.TextSize = 12; saveBtn.TextSize = 12
	loadBtns[slot] = loadBtn
	saveBtn.MouseButton1Click:Connect(function()
		loadouts[slot] = copyLook({ sel = sel, pat = pat, wear = wear })
		save(); paintLoadouts()
		setStatus("Saved your skins to Loadout " .. i .. ".", "good")
	end)
	loadBtn.MouseButton1Click:Connect(function()
		local lo = loadouts[slot]
		if not lo then setStatus("Loadout " .. i .. " is empty. Pick your skins, then press Save next to it.", "warn"); return end
		table.clear(sel); table.clear(pat); table.clear(wear)
		for w, id in pairs(lo.sel) do if byId[id] and byId[id].weapon == w then sel[w] = id end end
		for w, n in pairs(lo.pat) do pat[w] = clampPat(n) end
		for w, n in pairs(lo.wear) do wear[w] = clampWear(n) end
		save(); refreshWeapons(); refreshSkins()
		local _, held = heldModel()
		if held then task.spawn(function() reEquip(); if alive then setStatus("Loadout " .. i .. " is on.", "good") end end)
		else setStatus("Loadout " .. i .. " is on.", "good") end
	end)
end
paintLoadouts()
end

-- Skins page, to the right of the window: a turning 3D preview of the skin under your mouse (or the one you picked),
-- and a tint for the gun in your hands. The preview is built the same way the game's own inspect screen builds one.
local previewPanel, previewCleanup
do
	previewPanel = make("Frame", { Position = UDim2.new(1, 10, 0, 96), Size = UDim2.new(0, 230, 1, -156), BackgroundColor3 = C.bg, BackgroundTransparency = 0.2, BorderSizePixel = 0 }, win)
	corner(previewPanel, 12); stroke(previewPanel, 0.86)
	text(previewPanel, "PREVIEW", 11, C.dim, UDim2.fromOffset(14, 9), UDim2.new(1, -28, 0, 14), nil, Enum.Font.BuilderSansMedium)
	local nameLabel = text(previewPanel, "", 13, C.text, UDim2.fromOffset(14, 24), UDim2.new(1, -28, 0, 18), nil, Enum.Font.BuilderSansMedium)
	nameLabel.TextWrapped = false; nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
	local vf = make("ViewportFrame", {
		Position = UDim2.fromOffset(10, 46), Size = UDim2.new(1, -20, 0, 166), BackgroundColor3 = C.white, BackgroundTransparency = 0.95,
		Ambient = Color3.fromRGB(170, 170, 180), LightColor = Color3.new(1, 1, 1), LightDirection = Vector3.new(-1, -1, -0.5),
	}, previewPanel)
	corner(vf, 10)
	local world = make("WorldModel", {}, vf)
	local vcam = make("Camera", { FieldOfView = 30 }, vf)
	vf.CurrentCamera = vcam
	local hint = text(vf, "", 11, C.dim, UDim2.new(0, 0, 1, -20), UDim2.new(1, 0, 0, 16), Enum.TextXAlignment.Center)
	local tintLabel   -- made with the tint controls below

	-- WeaponModel.create already puts the skin on. The game's FinishClient is NOT bound to the preview: it keeps updating
	-- what it binds, and it is not allowed to touch anything inside this window, which floods the console with errors.
	local model, previewWeapon, shownKey, center, radius, ang = nil, nil, nil, Vector3.zero, 1, 0
	local function drop()
		if not model then return end
		local m = model
		model = nil
		pcall(function() m:Destroy() end)
	end
	local function build(w, skinId)
		local key = tostring(w) .. "|" .. tostring(skinId)
		if key == shownKey then return end
		shownKey = key
		drop()
		hint.Text = ""
		if not w then return end
		local ok, m = g(function() return WM.create(w, false, skinId) end)
		if not (ok and typeof(m) == "Instance" and m:IsA("Model")) then hint.Text = "No preview for this one"; return end
		for _, d in ipairs(m:GetDescendants()) do
			if d:IsA("BasePart") then d.Anchored = true; d.CanCollide = false; d.CanQuery = false; d.CanTouch = false end
		end
		m.Parent = world
		local cf, size = m:GetBoundingBox()
		center, radius = cf.Position, math.max(size.X, size.Y, size.Z)
		model, previewWeapon = m, w
	end
	local token = 0
	function showPreview(id)
		token += 1
		local my, w = token, current
		local sid = id or (w and sel[w])
		nameLabel.Text = not w and "Pick a weapon" or (sid and byId[sid] and byId[sid].display) or ("Default " .. (displayOf[w] or w))
		if not id and tintLabel then   -- the picked weapon may have changed: show its own tint
			tintLabel.Text = "Tint my " .. (w and (displayOf[w] or w) or "weapon")
			for _, f in ipairs(repaints) do f() end
		end
		-- wait a moment while the mouse moves over the list, so it doesn't build a model for every row it passes
		task.delay(id and 0.12 or 0, function()
			if alive and my == token then guarded("preview", function() build(w, sid) end) end
		end)
	end
	keep(RunService.RenderStepped:Connect(function(dt)   -- slow turn
		if not (model and previewPanel.Visible and win.Visible) then return end
		ang = (ang + dt * 0.6) % (math.pi * 2)
		local d = radius * 2.1
		vcam.CFrame = CFrame.lookAt(center + Vector3.new(math.cos(ang) * d, radius * 0.25, math.sin(ang) * d), center)
	end))

	-- tint: recolors the skin's own texture (SurfaceAppearance.Color multiplies it), so blue on Emerald comes out
	-- blue-green. Arms are left alone. Shown on the gun in your hands and on the preview.
	-- the controls below always show the tint of the weapon picked on the left, and each weapon keeps its own
	tintLabel = text(previewPanel, "Tint", 13, C.text, UDim2.fromOffset(14, 222), UDim2.new(1, -70, 0, 20))
	tintLabel.TextWrapped = false; tintLabel.TextTruncate = Enum.TextTruncate.AtEnd
	local function curTint() return tintOf(current or weapons[1]) end
	toggleAt(previewPanel, UDim2.new(1, -52, 0, 222), function() return curTint().on end, function(v)
		curTint().on = v
		local name = displayOf[current] or current or ""
		setStatus(v and ("Tint on for the " .. name .. ". Your other weapons keep their own tint.") or ("Tint off for the " .. name .. ". Its skin's own colors are back."), "good")
	end)
	local rings = {}
	local function paintRings() for n2, r2 in pairs(rings) do r2.Transparency = (n2 == curTint().color) and 0 or 1 end end
	for i, name in ipairs(COLOR_ORDER) do
		local b = make("TextButton", {
			Text = name == "Rainbow" and "R" or "", Position = UDim2.fromOffset(14 + (i - 1) * 25, 250), Size = UDim2.fromOffset(20, 20),
			BackgroundColor3 = TRACER_COLORS[name] or Color3.fromRGB(255, 160, 60), AutoButtonColor = false, TextColor3 = C.bg,
			Font = Enum.Font.BuilderSansBold, TextSize = 11,
		}, previewPanel)
		corner(b, 10)
		rings[name] = make("UIStroke", { Color = C.text, Thickness = 2, Transparency = 1 }, b)
		b.MouseButton1Click:Connect(function() curTint().color = name; paintRings(); save() end)
	end
	paintRings()
	repaints[#repaints + 1] = paintRings
	slider(previewPanel, 276, "Strength", 0.05, 1, 0.05, function() return curTint().strength end, function(v) curTint().strength = v end,
		function(v) return math.floor(v * 100 + 0.5) .. " %" end)
	text(previewPanel, "Paints over the skin's own texture. Lower strength keeps more of the original colors.", 11, C.dim, UDim2.fromOffset(14, 312), UDim2.new(1, -28, 0, 28))

	-- ammo FX of the weapon picked on the left (see the ammo FX block above): "G" keeps the game's own, "-" none
	text(previewPanel, "Ammo FX", 13, C.text, UDim2.fromOffset(14, 348), UDim2.fromOffset(70, 20))
	local fxNow = text(previewPanel, "", 12, C.dim, UDim2.fromOffset(84, 349), UDim2.new(1, -98, 0, 20), Enum.TextXAlignment.Right)
	fxNow.TextWrapped = false; fxNow.TextTruncate = Enum.TextTruncate.AtEnd
	local function curFx() return ammoFx[current or weapons[1]] end
	local fxRings = {}
	local function paintFx()
		local now = curFx()
		for id, r2 in pairs(fxRings) do r2.Transparency = (id == (now or "Game")) and 0 or 1 end
		fxNow.Text = fxApi.name(now)
	end
	local opts = { "Game", "None" }
	for _, id in ipairs(fxApi.order) do opts[#opts + 1] = id end
	for i, id in ipairs(opts) do
		local col = (id == "Game" or id == "None") and C.white or (id == "Bloxxed" and Color3.fromRGB(70, 70, 80)) or fxApi.color(id) or C.white
		local b = make("TextButton", {
			Text = (id == "Game" and "G") or (id == "None" and "-") or (id == "Bloxxed" and "B") or "",
			Position = UDim2.fromOffset(14 + ((i - 1) % 7) * 29, 374 + math.floor((i - 1) / 7) * 26), Size = UDim2.fromOffset(22, 22),
			BackgroundColor3 = col, BackgroundTransparency = (id == "Game" or id == "None") and 0.85 or 0, AutoButtonColor = false,
			TextColor3 = (id == "Game" or id == "None") and C.text or C.white, Font = Enum.Font.BuilderSansBold, TextSize = 12,
		}, previewPanel)
		corner(b, 11)
		local prism = fxApi.prism
		if id == "Prism" and prism then
			local keys = {}
			for k, c in ipairs(prism) do keys[#keys + 1] = ColorSequenceKeypoint.new((k - 1) / (#prism - 1), c) end
			make("UIGradient", { Color = ColorSequence.new(keys), Rotation = 45 }, b)
		end
		fxRings[id] = make("UIStroke", { Color = C.text, Thickness = 2, Transparency = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, b)
		b.MouseEnter:Connect(function() fxNow.Text = fxApi.name(id ~= "Game" and id or nil) end)
		b.MouseLeave:Connect(paintFx)
		b.MouseButton1Click:Connect(function()
			local w = current or weapons[1]
			ammoFx[w] = (id ~= "Game") and id or nil
			paintFx(); save()
			local name = displayOf[w] or w
			local _, held = heldModel()
			if held == w then reEquip() end   -- the bullets in your gun get their FX when it's drawn
			setStatus(ammoFx[w] and (fxApi.name(ammoFx[w]) .. " on your " .. name .. ". Only you see it. Your next shots use it.")
				or ("Your " .. name .. " is back to its own ammo FX."), "good")
		end)
	end
	paintFx()
	repaints[#repaints + 1] = paintFx

	local origColor = {}   -- SurfaceAppearance / part -> its own color, put back when the tint goes off
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
	local function untint()
		for target, o in pairs(origColor) do pcall(function() target.Color = o end) end
		table.clear(origColor)
	end
	local function untintModel(m)   -- put back the colors of one model (its weapon's tint was turned off)
		for target, o in pairs(origColor) do
			if not target.Parent then origColor[target] = nil   -- a gun that no longer exists
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
		if model then handle(model, previewWeapon) end
		prune += 1
		if prune >= 120 then   -- now and then, forget guns that were destroyed while tinted
			prune = 0
			for target in pairs(origColor) do if not target.Parent then origColor[target] = nil end end
		end
	end
	do local okB, eB = pcall(function() RunService:BindToRenderStep("PDSkinChangerTint", Enum.RenderPriority.Last.Value + 6, function() guarded("tint", stepTint) end) end); if not okB then warn("[SkinChanger] could not start tint: " .. tostring(eB)) end end

	function previewCleanup()
		untint()
		drop()
	end
end

-- Bullet tracers card
do
local trCard = card(0, 0.5, "Bullet tracers")
toggleAt(trCard, UDim2.new(1, -52, 0, 12), function() return tr.on end, function(v) tr.on = v end)
text(trCard, "Color", 12, C.dim, UDim2.fromOffset(14, 42), UDim2.new(1, -28, 0, 16))
local swatches = {}
for i, name in ipairs(COLOR_ORDER) do
	local b = make("TextButton", {
		Text = name == "Rainbow" and "R" or "", Position = UDim2.fromOffset(14 + (i - 1) * 30, 62), Size = UDim2.fromOffset(24, 24),
		BackgroundColor3 = TRACER_COLORS[name] or Color3.fromRGB(255, 160, 60), AutoButtonColor = false, TextColor3 = C.bg,
		Font = Enum.Font.BuilderSansBold, TextSize = 12,
	}, trCard)
	corner(b, 12)
	local ring = make("UIStroke", { Color = C.text, Thickness = 2, Transparency = 1 }, b)
	swatches[name] = ring
	b.MouseButton1Click:Connect(function()
		tr.color = name
		for n2, r2 in pairs(swatches) do r2.Transparency = (n2 == tr.color) and 0 or 1 end
		save()
	end)
end
repaints[#repaints + 1] = function() for n2, r2 in pairs(swatches) do r2.Transparency = (n2 == tr.color) and 0 or 1 end end
for n2, r2 in pairs(swatches) do r2.Transparency = (n2 == tr.color) and 0 or 1 end
slider(trCard, 98, "Thickness", 0.02, 0.5, 0.01, function() return tr.thick end, function(v) tr.thick = v end, function(v) return string.format("%.2f", v) end)
slider(trCard, 146, "Lifetime", 0.1, 2.5, 0.05, function() return tr.life end, function(v) tr.life = v end, function(v) return string.format("%.2f s", v) end)
toggleRow(trCard, 198, "Glow", function() return tr.glow end, function(v) tr.glow = v end)
toggleRow(trCard, 226, "Moving streak", function() return tr.streak end, function(v) tr.streak = v end)
toggleRow(trCard, 254, "Replace the game's tracer", function() return tr.replace end, function(v) tr.replace = v end)
text(trCard, "Only your own shots. Test it with a shot at a wall.", 11, C.dim, UDim2.fromOffset(14, 284), UDim2.new(1, -28, 0, 30))

-- Weapon spin card
local spCard = card(0.5, 0.5, "Weapon spin")
toggleAt(spCard, UDim2.new(1, -52, 0, 12), function() return spin.on end, function(v) spin.on = v end)
slider(spCard, 44, "Speed", 20, 720, 10, function() return spin.speed end, function(v) spin.speed = v end, function(v) return math.floor(v) .. " °/s" end)
segmented(spCard, 92, "Direction", { { id = 1, text = "Clockwise" }, { id = -1, text = "Counter" } }, function() return spin.dir end, function(v) spin.dir = v end)
segmented(spCard, 146, "Axis", { { id = "X", text = "X  tilt" }, { id = "Y", text = "Y  turn" }, { id = "Z", text = "Z  roll" } }, function() return spin.axis end, function(v) spin.axis = v end)
segmented(spCard, 200, "Behavior", { { id = "Continuous", text = "Continuous" }, { id = "Swing", text = "Swing" }, { id = "On equip", text = "On equip" } }, function() return spin.mode end, function(v) spin.mode = v end)
text(spCard, "Only the weapon in your view turns. Nothing else about the game changes.", 11, C.dim, UDim2.fromOffset(14, 254), UDim2.new(1, -28, 0, 30))

end

-- ===================== overlay: keystrokes + FPS / ping =====================
do
-- A small box you can drag anywhere. It stays on screen when the main window is hidden (RightShift).
local hudFrame = make("Frame", {
	Position = UDim2.fromOffset(hud.px, hud.py), Size = UDim2.fromOffset(132, 40), BackgroundColor3 = C.bg,
	BackgroundTransparency = 0.3, BorderSizePixel = 0, Visible = false, Active = true,
}, gui)
corner(hudFrame, 10); stroke(hudFrame, 0.86)
local hudStats = text(hudFrame, "-- FPS", 12, C.text, UDim2.fromOffset(6, 6), UDim2.new(1, -12, 0, 18), Enum.TextXAlignment.Center, Enum.Font.BuilderSansMedium)
local keysHolder = make("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 30), Size = UDim2.new(1, 0, 0, 132) }, hudFrame)
local keyBoxes = {}
local function keyBox(label, x, y, w, h, test)
	local f = make("Frame", { Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(w, h), BackgroundColor3 = C.white, BackgroundTransparency = 0.9, BorderSizePixel = 0 }, keysHolder)
	corner(f, 6)
	text(f, label, 12, C.text, UDim2.new(), UDim2.fromScale(1, 1), Enum.TextXAlignment.Center, Enum.Font.BuilderSansMedium)
	keyBoxes[#keyBoxes + 1] = { frame = f, test = test, down = false }
end
local function kd(code) return function() return UIS:IsKeyDown(code) end end
local function md(btn) return function() return UIS:IsMouseButtonPressed(btn) end end
keyBox("W", 49, 0, 34, 34, kd(Enum.KeyCode.W))
keyBox("A", 8, 38, 34, 34, kd(Enum.KeyCode.A))
keyBox("S", 49, 38, 34, 34, kd(Enum.KeyCode.S))
keyBox("D", 90, 38, 34, 34, kd(Enum.KeyCode.D))
keyBox("LMB", 8, 76, 56, 26, md(Enum.UserInputType.MouseButton1))
keyBox("RMB", 68, 76, 56, 26, md(Enum.UserInputType.MouseButton2))
keyBox("Shift", 8, 106, 56, 26, function() return UIS:IsKeyDown(Enum.KeyCode.LeftShift) or UIS:IsKeyDown(Enum.KeyCode.RightShift) end)
keyBox("Space", 68, 106, 56, 26, kd(Enum.KeyCode.Space))
function applyHud()
	hudFrame.Visible = hud.on and (hud.keys or hud.stats)
	hudStats.Visible = hud.stats
	keysHolder.Visible = hud.keys
	local keysY = 6 + (hud.stats and 24 or 0)
	keysHolder.Position = UDim2.fromOffset(0, keysY)
	hudFrame.Size = UDim2.fromOffset(132, keysY + (hud.keys and 138 or 0))
end
do
	local acc, frames = 0, 0
	keep(RunService.Heartbeat:Connect(function(dt)
		if not hud.on then return end
		if hud.keys then
			for _, k in ipairs(keyBoxes) do
				local d = k.test()
				if d ~= k.down then
					k.down = d
					k.frame.BackgroundColor3 = d and C.accent or C.white
					k.frame.BackgroundTransparency = d and 0.15 or 0.9
				end
			end
		end
		if hud.stats then
			acc += dt; frames += 1
			if acc >= 0.5 then
				local fps = math.floor(frames / acc + 0.5)
				acc, frames = 0, 0
				local ok, ms = pcall(function() return (assert(assert(assert(game:GetService("Stats"):FindFirstChild("Network")):FindFirstChild("ServerStatsItem")):FindFirstChild("Data Ping")) :: StatsItem):GetValue() end)
				hudStats.Text = fps .. " FPS  ·  " .. (ok and math.floor(ms + 0.5) or 0) .. " ms"
			end
		end
	end))
	-- drag it anywhere (the mouse must be free: use the Free cursor switch in first person)
	local dragging, startPos, startMouse
	hudFrame.InputBegan:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 then dragging = true; startPos = hudFrame.Position; startMouse = i.Position end
	end)
	keep(UIS.InputChanged:Connect(function(i)
		if dragging and i.UserInputType == Enum.UserInputType.MouseMovement then
			local d = i.Position - startMouse
			hudFrame.Position = UDim2.fromOffset(startPos.X.Offset + d.X, startPos.Y.Offset + d.Y)
		end
	end))
	keep(UIS.InputEnded:Connect(function(i)
		if dragging and i.UserInputType == Enum.UserInputType.MouseButton1 then
			dragging = false
			local vs, sz = gui.AbsoluteSize, hudFrame.AbsoluteSize
			local x = math.clamp(hudFrame.Position.X.Offset, 0, math.max(vs.X - sz.X, 0))
			local y = math.clamp(hudFrame.Position.Y.Offset, 0, math.max(vs.Y - sz.Y, 0))
			hudFrame.Position = UDim2.fromOffset(x, y)
			hud.px, hud.py = x, y
			save()
		end
	end))
end

end

-- World look: your own color grade, bloom and sun rays layered on top of the game's lighting. Local only, nothing in the map is changed.
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
local function worldGone(i) return not i or not i.Parent end
local function applyWorld()
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
local function setPreset(id)
	local pr = PRESET_BY[id]; if not pr then return end
	wd.preset, wd.tint, wd.sat, wd.con, wd.dark, wd.bloom, wd.rays = id, 1, pr.sat, pr.con, pr.dark, pr.bloom, pr.rays
	applyWorld()
end
do
	local acc = 0
	keep(RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc >= 0.5 then acc = 0; if wd.on then guarded("world", applyWorld) end end
	end))
end
if wd.on then guarded("world", applyWorld) end

-- Display page: stretched resolution and overlay
local dispPage = make("Frame", { Position = UDim2.fromOffset(14, 96), Size = UDim2.new(1, -28, 1, -156), BackgroundTransparency = 1, Visible = false }, win)
do
local stCard = make("Frame", { Size = UDim2.new(0.5, -8, 1, 0), BackgroundColor3 = C.white, BackgroundTransparency = 0.95, BorderSizePixel = 0 }, dispPage)
corner(stCard, 12); stroke(stCard, 0.93)
text(stCard, "Stretched resolution", 14, C.text, UDim2.fromOffset(14, 10), UDim2.new(1, -90, 0, 20), nil, Enum.Font.BuilderSansBold)
toggleAt(stCard, UDim2.new(1, -52, 0, 12), function() return st.on end, function(v) st.on = v end)
slider(stCard, 48, "Stretch", 0, 0.7, 0.01, function() return st.amount end, function(v) st.amount = v end, function(v) return math.floor(v * 100 + 0.5) .. " %" end)
text(stCard, "Makes everything look wider by flattening your view vertically, like a stretched monitor setting. Only your own screen changes; other players and the game are not affected. Your weapon and arms stretch with the view.", 12, C.dim, UDim2.fromOffset(14, 100), UDim2.new(1, -28, 0, 150))

local ovCard = make("Frame", { Position = UDim2.new(0.5, 4, 0, 0), Size = UDim2.new(0.5, -8, 1, 0), BackgroundColor3 = C.white, BackgroundTransparency = 0.95, BorderSizePixel = 0 }, dispPage)
corner(ovCard, 12); stroke(ovCard, 0.93)
text(ovCard, "Overlay", 14, C.text, UDim2.fromOffset(14, 10), UDim2.new(1, -90, 0, 20), nil, Enum.Font.BuilderSansBold)
toggleAt(ovCard, UDim2.new(1, -52, 0, 12), function() return hud.on end, function(v) hud.on = v; applyHud() end)
toggleRow(ovCard, 52, "Keystrokes", function() return hud.keys end, function(v) hud.keys = v; applyHud() end)
toggleRow(ovCard, 82, "FPS and ping", function() return hud.stats end, function(v) hud.stats = v; applyHud() end)
text(ovCard, "A small box with your movement keys, mouse buttons, FPS and ping. Drag it anywhere (turn on Free cursor first if you are in first person). It stays visible when you hide this window.", 12, C.dim, UDim2.fromOffset(14, 120), UDim2.new(1, -28, 0, 150))
applyHud()


end

-- World page
local function pct(v) return math.floor(v * 100 + 0.5) .. " %" end
local worldPage = make("Frame", { Position = UDim2.fromOffset(14, 96), Size = UDim2.new(1, -28, 1, -156), BackgroundTransparency = 1, Visible = false }, win)
do
local wlCard = make("Frame", { Size = UDim2.new(0.5, -6, 1, 0), BackgroundColor3 = C.white, BackgroundTransparency = 0.95, BorderSizePixel = 0 }, worldPage)
corner(wlCard, 12); stroke(wlCard, 0.93)
text(wlCard, "World look", 14, C.text, UDim2.fromOffset(14, 10), UDim2.new(1, -90, 0, 20), nil, Enum.Font.BuilderSansBold)
toggleAt(wlCard, UDim2.new(1, -52, 0, 12), function() return wd.on end, function(v) wd.on = v; applyWorld() end)
text(wlCard, "Pick a look. It works in the lobby and in matches and changes only your own screen. You can fine tune it with the sliders on the right.", 12, C.dim, UDim2.fromOffset(14, 38), UDim2.new(1, -28, 0, 34))
local pBtns = {}
local function paintPresets()
	for id, b in pairs(pBtns) do
		local on = wd.preset == id
		b.BackgroundColor3 = on and C.accent or C.white
		b.BackgroundTransparency = on and 0.2 or 0.92
	end
end
local pGrid = make("Frame", { Position = UDim2.fromOffset(14, 80), Size = UDim2.new(1, -28, 0, 80), BackgroundTransparency = 1 }, wlCard)
make("UIGridLayout", { CellSize = UDim2.new(0.25, -3, 0, 36), CellPadding = UDim2.fromOffset(4, 8), SortOrder = Enum.SortOrder.LayoutOrder }, pGrid)
for i, pr in ipairs(PRESETS) do
	local b = make("TextButton", {
		Text = pr.id, LayoutOrder = i, BackgroundColor3 = C.white, BackgroundTransparency = 0.92, TextColor3 = C.text,
		Font = Enum.Font.BuilderSansMedium, TextSize = 12, AutoButtonColor = false, TextXAlignment = Enum.TextXAlignment.Right,
	}, pGrid)
	corner(b, 8)
	make("UIPadding", { PaddingRight = UDim.new(0, 8) }, b)
	local dot = make("Frame", { Size = UDim2.fromOffset(10, 10), Position = UDim2.new(0, 8, 0.5, -5), BackgroundColor3 = pr.tint, BorderSizePixel = 0 }, b)
	corner(dot, 5)
	pBtns[pr.id] = b
	b.MouseButton1Click:Connect(function()
		wd.on = true; setPreset(pr.id)
		for _, f in ipairs(repaints) do f() end
		save()
	end)
end
repaints[#repaints + 1] = paintPresets
paintPresets()
text(wlCard, "Brightness can only be lowered, never raised, so a look can make a map moodier but not easier to see into. Time of day and sky are left to the game so they do not fight its own map lighting.", 12, C.dim, UDim2.fromOffset(14, 176), UDim2.new(1, -28, 0, 90))

local wsCard = make("Frame", { Position = UDim2.new(0.5, 6, 0, 0), Size = UDim2.new(0.5, -6, 1, 0), BackgroundColor3 = C.white, BackgroundTransparency = 0.95, BorderSizePixel = 0 }, worldPage)
corner(wsCard, 12); stroke(wsCard, 0.93)
text(wsCard, "Fine tune", 14, C.text, UDim2.fromOffset(14, 10), UDim2.new(1, -90, 0, 20), nil, Enum.Font.BuilderSansBold)
local function wslider(y, label, min, max, key, fmt)
	slider(wsCard, y, label, min, max, 0.01, function() return wd[key] end, function(v) wd[key] = v; applyWorld() end, fmt or pct)
end
wslider(38, "Color strength", 0, 1, "tint")
wslider(76, "Saturation", -1, 1, "sat")
wslider(114, "Contrast", 0, 0.5, "con")
wslider(152, "Darkness", 0, 0.4, "dark")
wslider(190, "Glow", 0, 2, "bloom")
wslider(228, "Sun rays", 0, 0.5, "rays")
end

-- Camera page: motion blur, view (FOV + gun position)
local camPage = make("Frame", { Position = UDim2.fromOffset(14, 96), Size = UDim2.new(1, -28, 1, -156), BackgroundTransparency = 1, Visible = false }, win)
do
local mbCard = card(0, 0.5, "Motion blur", camPage)
toggleAt(mbCard, UDim2.new(1, -52, 0, 12), function() return mb.on end, function(v) mb.on = v end)
slider(mbCard, 44, "Strength", 2, 24, 1, function() return mb.strength end, function(v) mb.strength = v end, function(v) return tostring(math.floor(v + 0.5)) end)
slider(mbCard, 92, "Starts at", 30, 360, 10, function() return mb.threshold end, function(v) mb.threshold = v end, function(v) return math.floor(v) .. " °/s" end)
slider(mbCard, 140, "Fade", 0.03, 0.4, 0.01, function() return mb.smooth end, function(v) mb.smooth = v end, function(v) return string.format("%.2f s", v) end)
text(mbCard, "Your screen blurs while you flick or turn fast and gets sharp again when you stop. Lower \"Starts at\" to blur on slower turns, raise Fade for a longer, smoother trail. Only your own screen changes.", 12, C.dim, UDim2.fromOffset(14, 192), UDim2.new(1, -28, 0, 140))

local vwCard = card(0.5, 0.5, "View", camPage)
toggleAt(vwCard, UDim2.new(1, -52, 0, 12), function() return vm.on end, function(v) vm.on = v end)
slider(vwCard, 44, "Field of view", -20, 40, 1, function() return vm.fov end, function(v) vm.fov = v end,
	function(v) v = math.floor(v + 0.5); return (v > 0 and "+" or "") .. v .. "°" end)
slider(vwCard, 82, "Weapon size", 0.5, 2, 0.05, function() return vm.size end, function(v) vm.size = v end, pct)
text(vwCard, "GUN POSITION", 11, C.dim, UDim2.fromOffset(14, 128), UDim2.new(1, -28, 0, 14), nil, Enum.Font.BuilderSansMedium)
local function studs(v) return string.format("%.2f", v) end
slider(vwCard, 146, "Left / right", -1, 1, 0.05, function() return vm.x end, function(v) vm.x = v end, studs)
slider(vwCard, 184, "Down / up", -1, 1, 0.05, function() return vm.y end, function(v) vm.y = v end, studs)
slider(vwCard, 222, "Near / far", -1, 1.5, 0.05, function() return vm.z end, function(v) vm.z = v end, studs)
text(vwCard, "Field of view is added on top of the game's own, so zooming in still works. Size and position change your gun and arms; 100 % and 0 are how the game draws them.", 12, C.dim, UDim2.fromOffset(14, 266), UDim2.new(1, -28, 0, 90))
end

-- ===================== FPS boost =====================
-- Makes the game cheaper to draw on YOUR screen: lower graphics quality, a higher FPS cap, and (optionally) no post
-- effects, particles, decals or fancy materials. Every changed property is remembered and put back when Boost is
-- turned off or the script is closed. The weapon in your hands (and its skin) is never touched.
local applyOpt, restoreOpt
do
	local saved = { post = {}, particles = {}, textures = {}, plain = {} }   -- category -> instance -> { prop = original }
	local OURS = { PDMotionBlur = true, PDWorldGrade = true, PDWorldBloom = true, PDWorldRays = true }   -- our own effects
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
		elseif want("textures") and d:IsA("Decal") then   -- Texture is a kind of Decal
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

-- Boost page
local boostPage = make("Frame", { Position = UDim2.fromOffset(14, 96), Size = UDim2.new(1, -28, 1, -156), BackgroundTransparency = 1, Visible = false }, win)
do
local fpsCard = card(0, 0.5, "FPS boost", boostPage)
toggleAt(fpsCard, UDim2.new(1, -52, 0, 12), function() return opt.on end, function(v)
	opt.on = v; applyOpt()
	setStatus(v and "Boost on. Watch the FPS counter (Display tab overlay) to see the difference." or "Boost off. Everything is back the way it was.", "good")
end)
segmented(fpsCard, 44, "FPS cap", { { id = 60, text = "60" }, { id = 144, text = "144" }, { id = 240, text = "240" }, { id = 0, text = "Max" } },
	function() return opt.cap end, function(v) opt.cap = v; applyOpt() end)
slider(fpsCard, 100, "Graphics quality", 1, 21, 1, function() return opt.quality end, function(v) opt.quality = v; applyOpt() end,
	function(v) return tostring(math.floor(v + 0.5)) .. " / 21" end)
text(fpsCard, "Lower graphics quality is the biggest FPS win: less shadow, detail and draw distance. Max takes the FPS cap off completely. Your own effects cost FPS too, mostly motion blur (Camera tab) and the glow in World look.", 12, C.dim, UDim2.fromOffset(14, 150), UDim2.new(1, -28, 0, 120))

local lwCard = card(0.5, 0.5, "Lighter world", boostPage)
toggleRow(lwCard, 44, "No post effects (bloom, blur, haze)", function() return opt.post end, function(v) opt.post = v; applyOpt() end)
toggleRow(lwCard, 74, "No particles, smoke and fire", function() return opt.particles end, function(v) opt.particles = v; applyOpt() end)
toggleRow(lwCard, 104, "Hide decals and textures", function() return opt.textures end, function(v) opt.textures = v; applyOpt() end)
toggleRow(lwCard, 134, "Plain materials", function() return opt.plain end, function(v) opt.plain = v; applyOpt() end)
text(lwCard, "These work while FPS boost is on. Only your own screen changes, and the gun in your hands keeps its skin and effects. Turning Boost off puts everything back.", 12, C.dim, UDim2.fromOffset(14, 172), UDim2.new(1, -28, 0, 100))
end
if opt.on then applyOpt() end

-- Settings page: hotkeys, window size, accent color
local setFrame, binding, paintKeys, applyAccent   -- binding: "keyMenu" / "keyCursor" / "keyView" while waiting for a new key
local viewApi: {cycle: (() -> ())?, off: (() -> ())?} = {}   -- third-person view: cycle(), off() (set further down)
do
setFrame = make("Frame", { Position = UDim2.fromOffset(14, 96), Size = UDim2.new(1, -28, 1, -156), BackgroundTransparency = 1, Visible = false }, win)
local hkCard = card(0, 0.5, "Hotkeys", setFrame)
local keyBtns = {}
function paintKeys()
	for k, b in pairs(keyBtns) do b.Text = (binding == k) and "Press a key..." or ui[k] end
end
local function keyRow(y, label, key)
	text(hkCard, label, 13, C.text, UDim2.fromOffset(14, y + 4), UDim2.new(1, -150, 0, 20))
	local b = button(hkCard, ui[key], UDim2.new(1, -134, 0, y), UDim2.fromOffset(120, 28))
	b.TextSize = 12
	keyBtns[key] = b
	b.MouseButton1Click:Connect(function() binding = (binding ~= key) and key or nil; paintKeys() end)
end
keyRow(44, "Show / hide window", "keyMenu")
keyRow(80, "Free cursor", "keyCursor")
keyRow(116, "Third-person view", "keyView")
text(hkCard, "Click a key box, then press the new key. Esc cancels. Only keyboard keys can be used. The view key switches first person, behind you and in front of you, in Practice, the lobby and after a round ends (never while a round is being played).", 12, C.dim, UDim2.fromOffset(14, 156), UDim2.new(1, -28, 0, 60))
paintKeys()
text(hkCard, "MOVEMENT", 11, C.dim, UDim2.fromOffset(14, 222), UDim2.new(1, -28, 0, 14), nil, Enum.Font.BuilderSansMedium)
toggleRow(hkCard, 242, "Auto slide on jump", function() return ui.slideJump end, function(v) ui.slideJump = v end)
text(hkCard, "Each jump presses slide for you as you leave the ground, so you slide as you land. Hold jump to keep slide-jumping. Only when you're running fast enough to slide.", 12, C.dim, UDim2.fromOffset(14, 272), UDim2.new(1, -28, 0, 60))

local uiCard = card(0.5, 0.5, "Interface", setFrame)
local uiScale = make("UIScale", { Scale = ui.scale }, win)
slider(uiCard, 44, "Window size", 0.6, 1.4, 0.05, function() return ui.scale end, function(v) ui.scale = v end, pct)
keep(UIS.InputEnded:Connect(function(i)   -- resize on release, so the slider doesn't move under the mouse
	if i.UserInputType == Enum.UserInputType.MouseButton1 and uiScale.Scale ~= ui.scale then uiScale.Scale = ui.scale end
end))
text(uiCard, "Accent color", 12, C.dim, UDim2.fromOffset(14, 92), UDim2.new(1, -28, 0, 16))
local accRings = {}
for i, a in ipairs(ACCENTS) do
	local b = make("TextButton", { Text = "", Position = UDim2.fromOffset(14 + (i - 1) * 30, 112), Size = UDim2.fromOffset(24, 24), BackgroundColor3 = a.color, AutoButtonColor = false }, uiCard)
	corner(b, 12)
	accRings[a.id] = make("UIStroke", { Color = C.text, Thickness = 2, Transparency = (ui.accent == a.id) and 0 or 1 }, b)
	b.MouseButton1Click:Connect(function()
		ui.accent = a.id
		for id, r in pairs(accRings) do r.Transparency = (id == a.id) and 0 or 1 end
		applyAccent(); save()
	end)
end
text(uiCard, "The window resizes when you let go of the slider. The overlay keeps its own size.", 12, C.dim, UDim2.fromOffset(14, 150), UDim2.new(1, -28, 0, 60))
end

-- Silent Aim: use the game's existing direction input and hit calculations.
sa.page = make("Frame", { Position = UDim2.fromOffset(14, 96), Size = UDim2.new(1, -28, 1, -156), BackgroundTransparency = 1, Visible = false }, win)
sa.cleanup = function() end
do
    -- Drawing and targeting share a pixel radius in viewport coordinates.
    function sa.circleContains(camera, position, radius)
        local projected, onScreen = camera:WorldToViewportPoint(position)
        local center = camera.ViewportSize * 0.5
        local dx, dy = projected.X - center.X, projected.Y - center.Y
        local distanceSquared = dx * dx + dy * dy
        return onScreen and projected.Z > 0 and distanceSquared <= radius * radius, distanceSquared
    end
    local ring = make("Frame", { Name = "SilentAimFOV", AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1, BorderSizePixel = 0, Active = false, Visible = false }, gui)
    make("UICorner", { CornerRadius = UDim.new(0.5, 0) }, ring)
    local outline = make("UIStroke", { Color = C.accent, Thickness = 1.5, Transparency = 0.15, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, ring)
    accentObjs[#accentObjs + 1] = { outline, "Color" }
    keep(RunService.RenderStepped:Connect(function()
        local cam = workspace.CurrentCamera
        ring.Visible = alive and sa.showFov and cam ~= nil
        if not ring.Visible then return end
        local center = cam.ViewportSize * 0.5
        ring.Position = UDim2.fromOffset(center.X, center.Y)
        local width, height = sa.radius * 2, sa.radius * 2
        ring.Size = UDim2.fromOffset(width, height)
    end))
    local ctl, origAttack, origAim, wrappedAttack, wrappedAim, priorAttack, priorAim
    local depth = 0
    local raycast
    local ok = g(function()
        raycast = requireGame(RS.Combat.CombatRaycast)
        if type(filtergc) == "function" then
            ctl = filtergc("table", { Keys = { "duels", "state", "movement" } }, true)
        elseif type(getgc) == "function" then
            for _, value in ipairs(getgc(true)) do
                if type(value) == "table" and rawget(value, "duels") and rawget(value, "state") and rawget(value, "movement") then ctl = value; break end
            end
        end
        assert(ctl and type(ctl.attack) == "function" and type(ctl.aimHit) == "function", "Combat controller unavailable")
        origAttack, origAim = ctl.attack, ctl.aimHit
        priorAttack, priorAim = rawget(ctl, "attack"), rawget(ctl, "aimHit")
    end)
    local ready = ok and ctl and origAttack and origAim and raycast
    function sa.targetPart(character, targetHead)
        if targetHead then return character:FindFirstChild("Head") end
        return character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso") or character:FindFirstChild("HumanoidRootPart")
    end
    local partGroups = {
        Head = {"Head"},
        Body = {"UpperTorso", "LowerTorso", "Torso"},
        Limbs = {"LeftUpperArm", "LeftLowerArm", "LeftHand", "RightUpperArm", "RightLowerArm", "RightHand", "LeftUpperLeg", "LeftLowerLeg", "LeftFoot", "RightUpperLeg", "RightLowerLeg", "RightFoot", "Left Arm", "Right Arm", "Left Leg", "Right Leg"},
    }
    function sa.rollGroup(available, roll)
        local weights = {Head = sa.headWeight, Body = sa.bodyWeight, Limbs = sa.limbWeight}
        local total = 0
        for _, group in ipairs({"Head", "Body", "Limbs"}) do if available[group] then total += weights[group] end end
        if total <= 0 then return nil end
        local threshold = math.clamp(roll, 0, 0.999999999) * total
        for _, group in ipairs({"Head", "Body", "Limbs"}) do
            if available[group] then
                threshold -= weights[group]
                if threshold < 0 then return group end
            end
        end
    end
    local function choose(self, reach, radius, targetHead, mode)
        local camera = workspace.CurrentCamera
        if not camera or not lp.Character then return end
        local origin = camera.CFrame.Position
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
                        if p then candidates[#candidates+1] = {part=p, group=group} end
                    end
                end
            else
                candidates[1] = {part=sa.targetPart(character, mode == "Head" or (mode == nil and targetHead)), group=targetHead and "Head" or "Body"}
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
                    if inside and (screenDistance < bestDistance or mode == "Weighted Random") then
                        -- The game's raycast enforces region and wall visibility.
                        local hit = origAim(self, reach, 0, direction)
                        if hit and self:enemyFromHit(hit) == character then
                            if screenDistance < bestDistance then
                                bestDistance, best = screenDistance, direction
                                bestCharacter = character
                            end
                            local previous = groups[candidate.group]
                            if not previous or screenDistance < previous.distance then
                                groups[candidate.group] = {distance=screenDistance, direction=direction, character=character}
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
    sa.chooseTarget = function(radius, targetHead) if ready and ctl:canAct() then return choose(ctl, sa.range, radius, targetHead) end end
    if ready then
        wrappedAim = function(self, reach, spread, direction, ...)
            if depth > 0 and alive and sa.on and self == ctl and not self.state.knife
                and not self.menu and not sa.menuOpen then
                local selected, targetDirection = pcall(choose, self, reach, sa.radius, sa.head, sa.targetMode)
                sa.lastError = not selected and tostring(targetDirection) or nil
                if selected and targetDirection then direction = targetDirection; sa.redirected = (sa.redirected or 0) + 1 end
            end
            return origAim(self, reach, spread, direction, ...)
        end
        wrappedAttack = function(self, ...)
            depth += 1
            local result = table.pack(pcall(origAttack, self, ...))
            depth -= 1
            if not result[1] then error(result[2], 0) end
            return table.unpack(result, 2, result.n)
        end
        g(function() ctl.aimHit, ctl.attack = wrappedAim, wrappedAttack end)
        sa.cleanup = function()
            sa.on = false
            g(function()
                if rawget(ctl, "attack") == wrappedAttack then ctl.attack = priorAttack end
                if rawget(ctl, "aimHit") == wrappedAim then ctl.aimHit = priorAim end
            end)
        end
    end
    local controls = card(0, 0.5, "Silent Aim", sa.page)
    local targets = card(0.5, 0.5, "Targets", sa.page)
    toggleRow(controls, 48, "Enabled", function() return sa.on end, function(v)
        sa.on = v and ready and true or false
        if v and not ready then setStatus("Combat controller unavailable. Re-run after loading into the game.", "bad") end
    end)
    slider(controls, 90, "FOV circle radius", 10, 600, 1, function() return sa.radius end, function(v) sa.radius = v end, function(v) return tostring(v) .. " px" end)
    slider(controls, 156, "Maximum range", 10, 1000, 10, function() return sa.range end, function(v) sa.range = v end, function(v) return tostring(v) .. " studs" end)
    text(controls, "Enable, then close the menu to use. Applies to your shots; camera and weapon spread stay as the game sets them.", 12, C.dim, UDim2.fromOffset(14, 222), UDim2.new(1, -28, 0, 90))
    toggleRow(targets, 48, "Players", function() return sa.players end, function(v) sa.players = v end)
    toggleRow(targets, 84, "Practice / onboarding targets", function() return sa.npcs end, function(v) sa.npcs = v end)
    local modes = {"Head", "Body", "Closest Part", "Weighted Random"}
    local modeButton = button(targets, sa.targetMode, UDim2.fromOffset(14, 120), UDim2.new(1, -28, 0, 28), false)
    repaints[#repaints+1] = function() modeButton.Text = sa.targetMode end
    modeButton.MouseButton1Click:Connect(function()
        local index = table.find(modes, sa.targetMode) or 1
        sa.targetMode = modes[index % #modes + 1]; modeButton.Text = sa.targetMode; save()
    end)
    toggleRow(targets, 156, "Show FOV circle", function() return sa.showFov end, function(v) sa.showFov = v end)
    slider(targets, 200, "Random: head weight", 0, 100, 1, function() return sa.headWeight end, function(v) sa.headWeight = v end, tostring)
    slider(targets, 250, "Random: torso weight", 0, 100, 1, function() return sa.bodyWeight end, function(v) sa.bodyWeight = v end, tostring)
    slider(targets, 300, "Random: limbs weight", 0, 100, 1, function() return sa.limbWeight end, function(v) sa.limbWeight = v end, tostring)
    text(targets, "Weights are relative; unavailable groups are excluded. All zero = no redirection.", 11, C.dim, UDim2.fromOffset(14, 345), UDim2.new(1, -28, 0, 40))
end

do
    local es = sa.esp
    es.page = make("Frame", { Position = UDim2.fromOffset(14, 96), Size = UDim2.new(1, -28, 1, -156), BackgroundTransparency = 1, Visible = false }, win)
    local options = card(0, 0.5, "Skeleton ESP", es.page)
    local appearance = card(0.5, 0.5, "Appearance", es.page)
    toggleRow(options, 48, "Skeleton", function() return es.skeleton end, function(v) es.skeleton = v end)
    toggleRow(options, 84, "Head dot", function() return es.headDot end, function(v) es.headDot = v end)
    toggleRow(options, 120, "Hide teammates", function() return es.hideTeam end, function(v) es.hideTeam = v end)
    toggleRow(options, 156, "Practice targets", function() return es.practice end, function(v) es.practice = v end)
    slider(appearance, 48, "Line thickness", 1, 4, 0.5, function() return es.thickness end, function(v) es.thickness = v end, function(v) return tostring(v) .. " px" end)
    slider(appearance, 114, "Head dot radius", 2, 10, 1, function() return es.dotRadius end, function(v) es.dotRadius = v end, function(v) return tostring(v) .. " px" end)
    text(appearance, "Uses your accent color. Draws over the world, excludes you, and supports R6 and R15 characters.", 12, C.dim, UDim2.fromOffset(14, 190), UDim2.new(1, -28, 0, 90))
    local overlay = make("ScreenGui", { Name = "PDSkeletonOverlay", IgnoreGuiInset = true, ResetOnSpawn = false, DisplayOrder = 49 }, lp.PlayerGui)
    es.cleanup = function() overlay:Destroy() end
    local layer = make("Frame", { Name = "SkeletonESP", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ClipsDescendants = true, Active = false }, overlay)
    local r6 = {{"Head","Torso"},{"Torso","Left Arm"},{"Torso","Right Arm"},{"Torso","Left Leg"},{"Torso","Right Leg"}}
    local r15 = {{"Head","UpperTorso"},{"UpperTorso","LowerTorso"},{"UpperTorso","LeftUpperArm"},{"LeftUpperArm","LeftLowerArm"},{"LeftLowerArm","LeftHand"},{"UpperTorso","RightUpperArm"},{"RightUpperArm","RightLowerArm"},{"RightLowerArm","RightHand"},{"LowerTorso","LeftUpperLeg"},{"LeftUpperLeg","LeftLowerLeg"},{"LeftLowerLeg","LeftFoot"},{"LowerTorso","RightUpperLeg"},{"RightUpperLeg","RightLowerLeg"},{"RightLowerLeg","RightFoot"}}
    local entries, nextScan = {}, 0
    local combatRay
    g(function() combatRay = requireGame(RS.Combat.CombatRaycast) end)
    local function add(character, owner)
        if character == lp.Character or entries[character] then return end
        local group = make("Frame", { Name = character.Name, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Active = false }, layer)
        local entry = { group = group, owner = owner, lines = {} }
        for i = 1, #r15 do
            entry.lines[i] = make("Frame", { Name = "Bone" .. i, AnchorPoint = Vector2.new(0.5, 0.5), BorderSizePixel = 0, BackgroundColor3 = C.accent, Active = false, Visible = false }, group)
        end
        entry.dot = make("Frame", { Name = "HeadDot", AnchorPoint = Vector2.new(0.5, 0.5), BorderSizePixel = 0, BackgroundColor3 = C.accent, Active = false, Visible = false }, group)
        make("UICorner", { CornerRadius = UDim.new(0.5, 0) }, entry.dot)
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
        for character, entry in pairs(entries) do
            if not present[character] or not character.Parent then entry.group:Destroy(); entries[character] = nil end
        end
    end
    keep(RunService.RenderStepped:Connect(function()

        layer.Visible = alive and (es.skeleton or es.headDot)
        if not layer.Visible then return end
        local camera = workspace.CurrentCamera
        if not camera then layer.Visible = false; return end
        if os.clock() >= nextScan then nextScan = os.clock() + 0.5; scan() end
        for character, entry in pairs(entries) do
            local hum = character:FindFirstChildOfClass("Humanoid")
            local owner = entry.owner
            local sameTeam = owner and lp:GetAttribute("PDMatch") ~= nil and owner:GetAttribute("PDMatch") == lp:GetAttribute("PDMatch") and lp:GetAttribute("PDTeam") ~= nil and owner:GetAttribute("PDTeam") == lp:GetAttribute("PDTeam")
            entry.group.Visible = character.Parent ~= nil and character ~= lp.Character and hum ~= nil and hum.Health > 0 and not (es.hideTeam and sameTeam) and (owner ~= nil or es.practice)
            if entry.group.Visible then
                local bones = character:FindFirstChild("UpperTorso") and r15 or r6
                for i, line in ipairs(entry.lines) do
                    line.Visible = false
                    local bone = bones[i]
                    local p1 = bone and character:FindFirstChild(bone[1])
                    local p2 = bone and character:FindFirstChild(bone[2])
                    if es.skeleton and p1 and p2 and p1:IsA("BasePart") and p2:IsA("BasePart") then
                        local a = camera:WorldToViewportPoint(p1.Position)
                        local b = camera:WorldToViewportPoint(p2.Position)
                        if a.Z > 0.1 and b.Z > 0.1 then
                            local dx, dy = b.X-a.X, b.Y-a.Y
                            local length = math.sqrt(dx*dx + dy*dy)
                            if length > 0.1 then
                                line.Position = UDim2.fromOffset((a.X+b.X)/2, (a.Y+b.Y)/2)
                                line.Size = UDim2.fromOffset(length, es.thickness)
                                line.Rotation = math.deg(math.atan2(dy,dx))
                                line.BackgroundColor3 = C.accent; line.Visible = true
                            end
                        end
                    end
                end
                entry.dot.Visible = false
                local head = character:FindFirstChild("Head")
                if es.headDot and head and head:IsA("BasePart") then
                    local point, onScreen = camera:WorldToViewportPoint(head.Position)
                    if onScreen and point.Z > 0.1 then
                        entry.dot.Position = UDim2.fromOffset(point.X, point.Y)
                        entry.dot.Size = UDim2.fromOffset(es.dotRadius*2, es.dotRadius*2)
                        entry.dot.BackgroundColor3 = C.accent; entry.dot.Visible = true
                    end
                end
            end
        end
    end))
end

sa.cameraPage = make("Frame", { BackgroundTransparency = 1, Visible = false }, win)
do
    local controls = card(0, 0.5, "Aim Assist", sa.cameraPage)
    local info = card(0.5, 0.5, "Camera smoothing", sa.cameraPage)
    toggleRow(controls, 48, "Enabled", function() return sa.cameraOn end, function(v) sa.cameraOn = v end)
    toggleRow(controls, 84, "Smooth camera aim", function() return sa.cameraSmooth end, function(v) sa.cameraSmooth = v end)
    slider(controls, 130, "Response speed", 1, 30, 1, function() return sa.cameraSpeed end, function(v) sa.cameraSpeed = v end, function(v) return tostring(v) end)
    slider(controls, 196, "Aim Assist FOV radius", 10, 600, 1, function() return sa.cameraRadius end, function(v) sa.cameraRadius = v end, function(v) return tostring(v) .. " px" end)
    toggleRow(controls, 254, "Show Aim Assist FOV", function() return sa.cameraShowFov end, function(v) sa.cameraShowFov = v end)
    text(controls, "Hold your configured aim input to aim. Release to stop. Disabled while the menu or free cursor is open. Bind inputs in Controls.", 12, C.dim, UDim2.fromOffset(14, 292), UDim2.new(1, -28, 0, 78))
    toggleRow(info, 48, "Aim at head (off = body)", function() return sa.cameraHead end, function(v) sa.cameraHead = v end)
    text(info, "Lower speed = gentler camera movement. Higher speed = faster tracking.\n\nUses its own orange FOV circle. Head/body is selected here, independently of Silent Aim. Range and target filters are shared with Aim & FOV.\n\nSilent Aim remains a separate option. Aim Assist moves the camera and does not fire for you.", 13, C.text, UDim2.fromOffset(14, 92), UDim2.new(1, -28, 0, 270))
    local ring = make("Frame", { Name = "AimAssistFOV", AnchorPoint = Vector2.new(0.5,0.5), BackgroundTransparency = 1, BorderSizePixel = 0, Active = false, Visible = false }, gui)
    make("UICorner", { CornerRadius = UDim.new(0.5,0) }, ring)
    make("UIStroke", { Color = Color3.fromRGB(255,170,65), Thickness = 1.5, Transparency = 0.15, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, ring)
    keep(RunService.RenderStepped:Connect(function()
        local camera = workspace.CurrentCamera
        ring.Visible = alive and sa.cameraShowFov and camera ~= nil
        if not ring.Visible then return end
        local center = camera.ViewportSize / 2
        ring.Position = UDim2.fromOffset(center.X,center.Y)
        ring.Size = UDim2.fromOffset(sa.cameraRadius*2,sa.cameraRadius*2)
    end))
    function sa.cameraBlend(current, direction, dt)
        local goal = CFrame.lookAt(current.Position, current.Position + direction)
        local alpha = sa.cameraSmooth and (1 - math.exp(-sa.cameraSpeed * math.max(0, dt))) or 1
        return current:Lerp(goal, alpha)
    end
    function sa.cameraStep(dt)
        if not alive or not sa.cameraOn or sa.menuOpen or freeCursor or not (sa.holdActive and sa.holdActive()) or UIS:GetFocusedTextBox() then return end
        local camera = workspace.CurrentCamera
        if not camera or camera.CameraType ~= Enum.CameraType.Custom then return end
        local clean, field = camera.CFrame, camera.FieldOfView
        -- Select using the same projection the user sees after stretch/FOV effects.
        if st.on then camera.CFrame = clean * CFrame.new(0,0,0,1,0,0,0,1-math.clamp(st.amount,0,0.7),0,0,0,1) end
        if vm.on and vm.fov ~= 0 then camera.FieldOfView = math.clamp(field + vm.fov, 1, 120) end
        -- Potassium requires game-thread identity for the combat visibility check.
        local ok, direction = g(sa.chooseTarget, sa.cameraRadius, sa.cameraHead)
        camera.CFrame, camera.FieldOfView = clean, field
        sa.cameraError = not ok and tostring(direction) or nil
        if ok and direction then
            camera.CFrame = sa.cameraBlend(clean, direction, dt)
            sa.cameraUpdates = (sa.cameraUpdates or 0) + 1
        end
    end
end

sa.controlsPage = make("Frame", { BackgroundTransparency = 1, Visible = false }, win)
do
    local actions = {
        {"silent", "Silent Aim", sa, "on"}, {"camera", "Aim Assist", sa, "cameraOn"},
        {"smooth", "Camera smoothing", sa, "cameraSmooth"}, {"head", "Aim Assist head / body", sa, "cameraHead"},
        {"silentFov", "Silent Aim FOV circle", sa, "showFov"}, {"cameraFov", "Aim Assist FOV circle", sa, "cameraShowFov"},
        {"players", "Target players", sa, "players"}, {"practice", "Target practice NPCs", sa, "npcs"},
        {"skeleton", "Skeleton ESP", sa.esp, "skeleton"}, {"dots", "ESP head dots", sa.esp, "headDot"},
        {"team", "ESP teammate filter", sa.esp, "hideTeam"}, {"espPractice", "ESP practice targets", sa.esp, "practice"},
        {"mode", "Cycle Silent Aim target mode"},
    }
    local rows = make("ScrollingFrame", { Name = "Bindings", BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.new(1,0,1,-48), Position = UDim2.fromOffset(0,48), CanvasSize = UDim2.fromOffset(0,(#actions+1)*38), ScrollBarThickness = 5 }, sa.controlsPage)
    text(sa.controlsPage, "Click a binding, then press a key. Esc cancels; Backspace clears. Settings and enabled states save automatically.", 12, C.dim, UDim2.fromOffset(14,0), UDim2.new(1,-28,0,42))
    local buttons = {}
    local function paint()
        for id,b in pairs(buttons) do b.Text = sa.capture == id and "Press a key..." or (id == "hold" and sa.cameraHold or sa.binds[id] or "None") end
    end
    local function row(index, id, label)
        text(rows,label,13,C.text,UDim2.fromOffset(14,index*38+5),UDim2.new(1,-210,0,24))
        local b=button(rows,"",UDim2.new(1,-184,0,index*38),UDim2.fromOffset(164,28),false)
        buttons[id]=b
        b.MouseButton1Click:Connect(function() sa.capture = sa.capture ~= id and id or nil; paint() end)
    end
    row(0,"hold","Aim Assist hold input (keyboard / RMB / MMB)")
    for i,action in ipairs(actions) do row(i,action[1],action[2]) end
    function sa.holdActive()
        if sa.capture or binding then return false end
        if sa.cameraHold == "MouseButton2" or sa.cameraHold == "MouseButton3" then return UIS:IsMouseButtonPressed(Enum.UserInputType[sa.cameraHold]) end
        local key=keyOf(sa.cameraHold)
        return key ~= nil and UIS:IsKeyDown(key)
    end
    function sa.handleInput(input, processed)
        if binding then return false end
        if sa.capture then
            local key=input.KeyCode
            if key == Enum.KeyCode.Escape then sa.capture=nil; paint(); return true end
            local name = input.UserInputType == Enum.UserInputType.Keyboard and key.Name or nil
            if sa.capture == "hold" and (input.UserInputType == Enum.UserInputType.MouseButton2 or input.UserInputType == Enum.UserInputType.MouseButton3) then name=input.UserInputType.Name end
            if not name or name == "Unknown" then return true end
            if key == Enum.KeyCode.Backspace then name="None" end
            if name ~= "None" then
                if name==ui.keyMenu or name==ui.keyCursor or name==ui.keyView then setStatus("That key is already assigned in Settings.","bad"); return true end
                if sa.capture ~= "hold" and name==sa.cameraHold then setStatus("That key is the Aim Assist hold input.","bad"); return true end
                for id,value in pairs(sa.binds) do if id~=sa.capture and value==name then setStatus("That key is already assigned in Controls.","bad"); return true end end
            end
            if sa.capture=="hold" then sa.cameraHold=name else sa.binds[sa.capture]=name end
            sa.capture=nil; paint(); save(); return true
        end
        if processed or UIS:GetFocusedTextBox() or input.UserInputType~=Enum.UserInputType.Keyboard then return false end
        local name=input.KeyCode.Name
        -- Global menu bindings always take priority if changed later.
        if name==ui.keyMenu or name==ui.keyCursor or name==ui.keyView then return false end
        for _,action in ipairs(actions) do
            if sa.binds[action[1]]==name then
                if action[1]=="mode" then
                    local modes={"Head","Body","Closest Part","Weighted Random"}
                    sa.targetMode=modes[(table.find(modes,sa.targetMode) or 1)%#modes+1]
                else action[3][action[4]]=not action[3][action[4]] end
                for _,repaint in ipairs(repaints) do repaint() end
                save(); return true
            end
        end
        return false
    end
    paint()
    repaints[#repaints+1]=paint
end

sa.hub = make("Frame", { Position = UDim2.fromOffset(14, 96), Size = UDim2.new(1, -28, 1, -156), BackgroundTransparency = 1, Visible = false }, win)
do
    local aim, esp, camera, controls = sa.page, sa.esp.page, sa.cameraPage, sa.controlsPage
    for _, page in ipairs({aim, esp, camera, controls}) do
        page.Parent = sa.hub
        page.Position = UDim2.fromOffset(0, 40)
        page.Size = UDim2.new(1, 0, 1, -40)
    end
    aim.Visible, esp.Visible, camera.Visible = false, false, true
    local aimButton = button(sa.hub, "Aim & FOV", UDim2.fromOffset(0, 0), UDim2.fromOffset(140, 30), true)
    local espButton = button(sa.hub, "Skeleton ESP", UDim2.fromOffset(150, 0), UDim2.fromOffset(140, 30), false)
    local cameraButton = button(sa.hub, "Aim Assist", UDim2.fromOffset(300, 0), UDim2.fromOffset(140, 30), false)
    local controlsButton = button(sa.hub, "Controls", UDim2.fromOffset(450, 0), UDim2.fromOffset(120, 30), false)
    local function selectPage(page)
        aim.Visible, esp.Visible, camera.Visible = page == aim, page == esp, page == camera
        controls.Visible = page == controls
        sa.capture = nil
        aimButton.BackgroundTransparency = page == aim and 0.1 or 0.8
        espButton.BackgroundTransparency = page == esp and 0.1 or 0.8
        cameraButton.BackgroundTransparency = page == camera and 0.1 or 0.8
        controlsButton.BackgroundTransparency = page == controls and 0.1 or 0.8
    end
    aimButton.MouseButton1Click:Connect(function() selectPage(aim) end)
    espButton.MouseButton1Click:Connect(function() selectPage(esp) end)
    cameraButton.MouseButton1Click:Connect(function() selectPage(camera) end)
    controlsButton.MouseButton1Click:Connect(function() selectPage(controls) end)
    selectPage(camera)
end


local function defaults()
    sa.on = false
	tr.on, tr.color, tr.thick, tr.life, tr.glow, tr.streak, tr.replace = false, "Cyan", 0.12, 0.6, true, false, true
	spin.on, spin.speed, spin.dir, spin.axis, spin.mode = false, 180, 1, "Y", "Continuous"
	st.on, st.amount = false, 0.35
	hud.on, hud.keys, hud.stats = false, true, true
	wd.on = false; setPreset("Natural")
	mb.on, mb.strength, mb.threshold, mb.smooth = false, 12, 120, 0.12
	vm.on, vm.fov, vm.size, vm.x, vm.y, vm.z = false, 0, 1, 0, 0, 0
	opt.on, opt.cap, opt.quality, opt.post, opt.particles, opt.textures, opt.plain = false, 240, 3, true, true, false, false
	table.clear(tints)
	applyOpt()
	applyHud()
end

-- every page was laid out for the old full-width window with tabs on top: move each one right of the menu and up
-- into the space the tab row used to take
for _, f in ipairs({ left.frame, right.frame, fxPage, dispPage, worldPage, camPage, boostPage, setFrame, sa.hub, bar }) do
	local dy = (f == bar) and 0 or 34
	f.Position += UDim2.fromOffset(SIDE - 4, -dy)
	f.Size += UDim2.fromOffset(f.Size.X.Scale > 0 and -(SIDE - 4) or 0, dy)
end
previewPanel.Position += UDim2.fromOffset(0, -34)
previewPanel.Size += UDim2.fromOffset(0, 34)

local page = "skins"
local pages = { aim = sa.hub, fx = fxPage, boost = boostPage, display = dispPage, world = worldPage, camera = camPage, settings = setFrame }
local tabs = tabBtns
local PAGE_MSG = {
    aim = "Silent Aim: enable, then close the menu. FOV is a screen-space circle; its radius is measured in pixels.",
	skins = "Pick a weapon, click a skin. Only you see the change.",
	fx = "Tracers and weapon spin. Each one has its own switch.",
	boost = "More FPS: lower graphics, higher FPS cap, lighter world. Only your own screen changes.",
	display = "Display options. Only your own screen changes.",
	world = "Pick a look for the lobby and maps. Only your own screen changes.",
	camera = "Motion blur, field of view and gun position. Only your own screen changes.",
	settings = "Hotkeys, window size and accent color.",
}
local function paintTabs()
	for name, b in pairs(tabs) do
		local on = (name == page)
		b:SetAttribute("Active", on)
		b.BackgroundColor3 = on and C.accent or C.white
		b.BackgroundTransparency = on and 0.8 or 1
		b.TextColor3 = on and C.text or C.dim
		local bar = b:FindFirstChild("Bar")
		if bar then bar.Visible = on; bar.BackgroundColor3 = C.accent end
	end
end
local function setPage(name)
	page = name
	local skinsPage = (name == "skins")
	left.frame.Visible = skinsPage; right.frame.Visible = skinsPage; previewPanel.Visible = skinsPage
	for n, f in pairs(pages) do f.Visible = (n == name) end
	reBtn.Visible = skinsPage; resetOne.Visible = skinsPage; resetAll.Visible = skinsPage
	resetFx.Visible = not skinsPage and name ~= "settings"
	paintTabs()
	setStatus(PAGE_MSG[name] or "")
end
for name, b in pairs(tabs) do b.MouseButton1Click:Connect(function() setPage(name) end) end

function applyAccent()
	C.accent = accentOf(ui.accent)
	for _, o in ipairs(accentObjs) do pcall(function() o[1][o[2]] = C.accent end) end
	for _, f in ipairs(repaints) do f() end
	paintArms(false); paintCursor(false)
	refreshWeapons(); refreshSkins(); paintTabs()
end
resetFx.MouseButton1Click:Connect(function()
	defaults(); for _, f in ipairs(repaints) do f() end; save()
	setStatus("Effects are back to their defaults.", "good")
end)

-- help card (shown the first time, and with the ? button)
local help = make("Frame", {
	Size = UDim2.fromOffset(540, 490), Position = UDim2.new(0.5, -270, 0.5, -245), BackgroundColor3 = C.bg,
	BackgroundTransparency = 0.04, BorderSizePixel = 0, Visible = false, ZIndex = 20,
}, win)
corner(help, 14)
accentObjs[#accentObjs + 1] = { stroke(help, 0.2, C.accent, 1.5), "Color" }
local function helpString()
	return "How it works\n\n"
		.. "1.  Pick a weapon on the left, then click a skin. Click it again to turn it off. Click the star to favorite a skin: favorites go to the top, and typing \"fav\" in the search shows only them.\n"
		.. "2.  If you are holding that weapon it updates by itself. If not, it shows the next time you equip it. The panel on the right shows a 3D preview of the skin under your mouse, and can tint the skin's colors (blue on Emerald turns it blue-green). Each weapon has its own tint.\n"
		.. "3.  Patterned skins get a Pattern and Wear box. Type a number and press Enter, or hit Random.\n"
		.. "4.  Loadouts (bottom left) save your whole set of skins. Shuffle gives you a random skin each time you equip, from your favorites if that weapon has any.\n"
		.. "5.  Effects: tracers and weapon spin. Boost: more FPS. Display: stretched resolution, overlay, self highlight. World: color looks. Camera: motion blur, FOV, gun position. Settings: hotkeys, window size, accent color.\n\n"
		.. "Only you see these changes. A skin only shows on a weapon in your loadout. \"Hide arms\" and \"Free cursor\" are top right.\n\n"
		.. ui.keyMenu .. " hides or shows this window (there is no on-screen tab while it is hidden). " .. ui.keyCursor .. " frees the cursor."
end
local helpText = text(help, helpString(),
	13, C.text, UDim2.fromOffset(20, 16), UDim2.new(1, -40, 1, -70))
helpText.ZIndex = 21
helpText.TextYAlignment = Enum.TextYAlignment.Top
local gotIt = button(help, "Got it", UDim2.new(0.5, -50, 1, -46), UDim2.fromOffset(100, 32), true)
gotIt.ZIndex = 21
local function showHelp(on) help.Visible = on end
helpBtn.MouseButton1Click:Connect(function() showHelp(not help.Visible) end)
gotIt.MouseButton1Click:Connect(function() showHelp(false); seenHelp = true; save() end)

hideBtn.MouseButton1Click:Connect(function() setOpen(false) end)
keep(UIS.InputBegan:Connect(function(i, gp)
    if sa.handleInput and sa.handleInput(i, gp) then return end
	if binding then   -- the Settings tab is waiting for a new hotkey
		if i.UserInputType == Enum.UserInputType.Keyboard then
			if i.KeyCode ~= Enum.KeyCode.Escape then ui[binding] = i.KeyCode.Name; save() end
			binding = nil; paintKeys(); helpText.Text = helpString()
		end
		return
	end
	if gp then return end
	if i.KeyCode == keyOf(ui.keyMenu) then setOpen(not win.Visible)
	elseif i.KeyCode == keyOf(ui.keyCursor) then setFreeCursor(not freeCursor)
	elseif i.KeyCode == keyOf(ui.keyView) and viewApi.cycle then viewApi.cycle() end
end))

do
	local _, held = heldModel()
	current = (held and skinsOf[held]) and held or weapons[1]
end
refreshWeapons(); refreshSkins(); setPage("skins")
if seenHelp then
	setStatus("Pick a weapon, click a skin. Only you see the change.")
else
	showHelp(true)
end

-- ===================== auto slide on jump =====================
-- After each jump, the slide key is pressed for you just before you land (the same key you'd press: the game handles
-- it exactly as yours). The game keeps a slide pressed in the air for only a moment (its landing buffer, 0.15 s), and
-- a jump lasts longer than that, so the press waits until you're about to touch down: you land straight into a slide,
-- and holding jump jumps you out of it again, a chain of slide-jumps. If you land before it got the chance (a step, a
-- ledge), it presses as you land. It only presses when you're running fast enough to slide (slower, the game would
-- crouch you instead) and never while you're already sliding (that would cancel the slide).
do
	local VIM = game:GetService("VirtualInputManager")
	local MoveCfg
	g(function() MoveCfg = requireGame(RS.Combat.Config) end)
	local BUFFER = MoveCfg and MoveCfg.Slide and tonumber(MoveCfg.Slide.LandingBuffer) or 0.15
	local LEAD = math.clamp(BUFFER * 0.5, 0.03, 0.12)   -- press this long before touching down
	local function fastEnough(hum, root)
		local walk = (MoveCfg and MoveCfg.Prototype and tonumber(MoveCfg.Prototype.WalkSpeed) or 16) + 2
		local min = MoveCfg and MoveCfg.Slide and tonumber(MoveCfg.Slide.MinSpeed) or 0
		return hum.MoveDirection.Magnitude > 0.1 and (root.AssemblyLinearVelocity * Vector3.new(1, 0, 1)).Magnitude > math.max(walk, min)
	end
	-- the game's movement controller (read only): is a slide running right now?
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
	local armed = false   -- a jump is in the air and hasn't had its press yet
	local hum, root, ch
	local function ok() return alive and ui.slideJump and hum and root and not UIS:GetFocusedTextBox() end
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
				if ok() and fastEnough(hum, root) and not sliding() then pressSlide() end
			end
		end))
	end
	keep(lp.CharacterAdded:Connect(hook))
	if lp.Character then task.spawn(hook, lp.Character) end
	keep(RunService.Heartbeat:Connect(function()
		if not (armed and ok()) or hum.Parent ~= ch then return end
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

-- ===================== third-person view =====================
-- The view key cycles first person, behind you and in front of you, like Minecraft's F5. It only works where seeing
-- past corners can't help against another player: Practice (your shots only hit the practice targets there), the lobby
-- (already third person, so the front view is what it adds) and a duel once the round is over. As soon as a round is
-- being played again, it goes back to first person by itself. Only your own camera changes.
do
	local OVER = { Result = true, MatchResult = true }   -- duel phases after the shooting has stopped
	local view = 0      -- 0 first person, 1 behind you, 2 in front of you
	local saved         -- the game's camera settings from before the view was turned on
	-- how far the camera sits from you. The game keeps pulling its own zoom back to first person, so the distance is
	-- held here (closest = farthest = zoom) and the mouse wheel changes it.
	local zoom = 10
	local hidden = {}   -- parts of the first-person gun and arms hidden while the view is on
	-- the game's combat controller (read only): which mode and round phase you're in
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
	local function where()   -- "Practice" / "Lobby" / "Over" where the view may be on, nil anywhere else
		local c = combatCtl()
		local s = c and rawget(c, "state")
		if type(s) ~= "table" then return nil end
		local duels = rawget(c, "duels")
		if duels and duels.spectator and duels.spectator.active then return nil end
		if s.mode == "Practice" or s.mode == "Lobby" then return s.mode end
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
		showFirstPerson()
		if was then
			lp.CameraMinZoomDistance, lp.CameraMaxZoomDistance = was.min, was.max
			-- the camera mode the game itself picks: free in the lobby, locked to first person everywhere else
			local c = combatCtl()
			local s = c and rawget(c, "state")
			lp.CameraMode = (type(s) == "table" and s.mode == "Lobby") and Enum.CameraMode.Classic or Enum.CameraMode.LockFirstPerson
		end
	end
	local NAMES = { [0] = "First person", "Third person (behind you)", "Third person (in front of you)" }
	viewApi.off = viewOff
	function viewApi.cycle()
		local at = where()
		if not at then
			setStatus("Third-person view works in Practice, the lobby and after a round ends, not while a round is being played.", "bad")
			return
		end
		local nextView = (view + 1) % 3
		if nextView == 0 then viewOff()
		else
			if not saved then saved = { mode = lp.CameraMode, min = lp.CameraMinZoomDistance, max = lp.CameraMaxZoomDistance } end
			view = nextView
		end
		setStatus(NAMES[view] .. ".  " .. ui.keyView .. " switches the view.", "good")
	end
	local flipped, backCF   -- the front view's camera, and the one behind you it was turned from
	-- before the game's camera code runs: put back the camera the front view turned around, so the next frame starts
	-- from where you really look
	local function before()
		local cam = workspace.CurrentCamera
		if flipped and cam.CFrame == flipped then cam.CFrame = backCF end
		flipped = nil
		if view == 0 then return end
		local at = alive and where()
		if not at then viewOff(); return end
		if at == "Lobby" then return end   -- the lobby camera is already out behind you, with the game's own zoom
		lp.CameraMode = Enum.CameraMode.Classic
		if lp.CameraMaxZoomDistance ~= zoom then lp.CameraMaxZoomDistance = zoom end
		if lp.CameraMinZoomDistance ~= zoom then lp.CameraMinZoomDistance = zoom end
	end
	keep(UIS.InputChanged:Connect(function(i, gp)
		if view ~= 0 and not gp and i.UserInputType == Enum.UserInputType.MouseWheel then
			zoom = math.clamp(zoom - i.Position.Z * 1.5, 4, 24)
		end
	end))
	-- after the game's camera code: hide the first-person gun, and turn the camera around for the front view
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local function after()
		if view == 0 then return end
		hideFirstPerson()
		-- Roblox's camera frees the mouse in this camera mode every frame: lock it again so the mouse turns the camera
		-- like in first person, unless a menu or the free cursor needs it (the lobby keeps the game's own mouse)
		if lp.CameraMode == Enum.CameraMode.Classic and where() ~= "Lobby" and not (freeCursor or win.Visible or rawget(combat, "menu")) then
			UIS.MouseBehavior = Enum.MouseBehavior.LockCenter
		end
		local cam = workspace.CurrentCamera
		if view ~= 2 or cam.CameraType ~= Enum.CameraType.Custom then return end
		local cf, focus = cam.CFrame, cam.Focus.Position
		local dist = (cf.Position - focus).Magnitude
		if dist < 1 then return end
		local goal = focus + cf.LookVector * dist
		params.FilterDescendantsInstances = { lp.Character, cam }
		local hit = workspace:Raycast(focus, goal - focus, params)
		if hit then goal = focus + (goal - focus).Unit * math.max(0.5, hit.Distance - 0.3) end
		backCF = cf
		cam.CFrame = CFrame.lookAt(goal, focus)
		flipped = cam.CFrame
	end
	local okV, eV = pcall(function()
		RunService:BindToRenderStep("PDSkinChangerViewA", Enum.RenderPriority.Camera.Value - 2, before)
		RunService:BindToRenderStep("PDSkinChangerViewB", Enum.RenderPriority.Camera.Value + 3, after)
	end)
	if not okV then warn("[SkinChanger] could not start the third-person view: " .. tostring(eV)) end
end

local function unload()
	if not alive then return end
	alive = false
    pcall(sa.cleanup); pcall(sa.esp.cleanup)
	for _, name in ipairs({ "PDSkinChangerArms", "PDSkinChangerCursor", "PDSkinChangerFx", "PDSkinChangerSelf", "PDSkinChangerBlur", "PDSkinChangerTint", "PDSkinChangerStretchB", "PDSkinChangerStretchA", "PDSkinChangerViewA", "PDSkinChangerViewB" }) do
		pcall(function() RunService:UnbindFromRenderStep(name) end)
	end
	if viewApi.off then pcall(viewApi.off) end
	pcall(onlineGone)
	pcall(function() if mbBlur then mbBlur:Destroy() end end)
	pcall(restoreOpt)   -- graphics quality, FPS cap and every changed map property go back
	pcall(previewCleanup)
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
	pcall(function() gui:Destroy() end)
	_G.PistolDuelsSkinChanger = nil
end
closeBtn.MouseButton1Click:Connect(unload)

_G.PistolDuelsSkinChanger = {
	unload = unload, sa = sa, sel = sel, pat = pat, wear = wear, hits = function() return hits end, reEquip = reEquip,
	setHideArms = setHideArms, hideArms = function() return hideArms end,
	setFreeCursor = setFreeCursor, freeCursor = function() return freeCursor end,
	tr = tr, spin = spin, st = st, hud = hud, wd = wd, mb = mb, vm = vm, opt = opt, applyOpt = applyOpt, tints = tints, ammoFx = ammoFx, showPreview = function(id) showPreview(id) end, ui = ui, fav = fav, loadouts = loadouts, shuffle = shuffle, applyWorld = applyWorld, tracer = spawnTracer,
}
print(("[SkinChanger] ready: %d weapons, %d skins"):format(#weapons, (function() local n = 0 for _, l in pairs(skinsOf) do n += #l end return n end)()))
