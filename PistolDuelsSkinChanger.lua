-- PISTOL DUELS | Skin Changer (local only)  |  made by meowthjr & Claude
--
-- WHAT IT DOES
--   Pick any Glock, Tec-9, Deagle or Knife skin and your own gun shows it, even skins you don't own.
--   Only YOU see the change. Other players, your inventory, trades and purchases are not touched.
--   Skins that only exist for staff (admin_*) are left out on purpose.
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
--      Settings tab: hotkeys, window size and accent color.
--   7. The panel right of the window shows a turning 3D preview of the skin under your mouse, and can tint your gun.
--   8. Star skins to favorite them, save whole skin sets in Loadouts, or turn on Shuffle for a random skin per equip.
--   Your choices are saved and come back the next time you run the script.
--   Note: a skin only shows up on a weapon that is in your loadout (the pistol slot or the knife slot).

if _G.PistolDuelsSkinChanger and _G.PistolDuelsSkinChanger.unload then pcall(_G.PistolDuelsSkinChanger.unload) end

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local UIS = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local lp = Players.LocalPlayer

local SAVE_FILE = "pistol_duels_skin_changer.json"
local alive = true
local conns = {}
local function keep(c) conns[#conns + 1] = c; return c end

-- the game's modules can only be required from a thread with identity 2 (executors run at 8), so anything that
-- touches them goes through g(): it runs the function in such a thread, waits for it, and returns pcall's results
local setIdentity = (type(setthreadidentity) == "function" and setthreadidentity)
	or (type(set_thread_identity) == "function" and set_thread_identity)
	or (type(setidentity) == "function" and setidentity)
	or (type(setthreadcontext) == "function" and setthreadcontext)
	or (type(syn) == "table" and type(syn.set_thread_identity) == "function" and syn.set_thread_identity)
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
	SkinCatalog = require(cos.SkinCatalog)
	WM = require(cos.WeaponModel)
	pcall(function()
		FC = require(lp.PlayerScripts.Client.Cosmetics.FinishClient)
	end)
	pcall(function()
		CE = require(lp.PlayerScripts.Client.Effects.CosmeticEffects)
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
local seenHelp = false
local hideArms = false
-- effect settings (the Effects tab): bullet tracers on your own shots, and a spin on your own weapon model
local tr = { on = false, color = "Cyan", thick = 0.12, life = 0.6, glow = true, streak = false, replace = true }
local spin = { on = false, speed = 180, dir = 1, axis = "Y", mode = "Continuous" }
local st = { on = false, amount = 0.35 }   -- stretched resolution (Display tab)
local hud = { on = false, keys = true, stats = true, px = 24, py = 240 }   -- keystrokes + FPS/ping overlay (Display tab)
local sh = { on = false, color = "Cyan", fill = 0.65, outline = 0.0, onTop = true }   -- highlight on your own character (Display tab)
local wd = { on = false, preset = "Natural", tint = 1, sat = 0, con = 0, dark = 0, bloom = 0, rays = 0 }   -- World look (World tab)
local mb = { on = false, strength = 12, threshold = 120, smooth = 0.12 }   -- motion blur when turning fast (Camera tab)
local vm = { on = false, fov = 0, size = 1, x = 0, y = 0, z = 0 }   -- field of view, gun size and position (Camera tab)
local opt = { on = false, cap = 240, quality = 3, post = true, particles = true, textures = false, plain = false }   -- FPS boost (Boost tab)
local tints = {}   -- weapon -> { on, color, strength }: each weapon's own tint (Skins tab, next to the preview)
local function tintOf(w)
	if not tints[w] then tints[w] = { on = false, color = "Cyan", strength = 0.45 } end
	return tints[w]
end
local ui = { scale = 1, accent = "Blue", keyMenu = "RightShift", keyCursor = "RightControl" }   -- window size, accent, hotkeys (Settings tab)
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
			mergeInto(tr, d.tr); mergeInto(spin, d.spin); mergeInto(st, d.st); mergeInto(hud, d.hud); mergeInto(sh, d.sh); mergeInto(wd, d.wd); mergeInto(mb, d.mb)
			mergeInto(vm, d.vm); mergeInto(opt, d.opt); mergeInto(ui, d.ui)
			for w, v in pairs(type(d.tints) == "table" and d.tints or {}) do
				if type(v) == "table" then
					tints[w] = { on = v.on == true, color = type(v.color) == "string" and v.color or "Cyan", strength = type(v.strength) == "number" and v.strength or 0.45 }
				end
			end; mergeInto(shuffle, d.shuffle)
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
			writefile(SAVE_FILE, HttpService:JSONEncode({ sel = sel, pat = pat, wear = wear, seenHelp = seenHelp, hideArms = hideArms, tr = tr, spin = spin, st = st, hud = hud, sh = sh, wd = wd, mb = mb,
				vm = vm, opt = opt, tints = tints, ui = ui, shuffle = shuffle, fav = fav, loadouts = loadouts }))
		end
	end)
end

local function keyOf(name)
	local ok, k = pcall(function() return Enum.KeyCode[name] end)
	return ok and k or nil
end
if not keyOf(ui.keyMenu) then ui.keyMenu = "RightShift" end
if not keyOf(ui.keyCursor) then ui.keyCursor = "RightControl" end
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
			if it.weapon == w and not it.adminOnly and not it.standard and not string.find(tostring(id), "^admin_") then
				local c = colors[it.rarity]
				local s = {
					id = id, display = it.name or id, rarity = tostring(it.rarity or ""),
					color = typeof(c) == "Color3" and c or nil, patterned = it.procedural ~= nil, weapon = w,
				}
				list[#list + 1] = s
				byId[id] = s
			end
		end
		table.sort(list, function(a, b)
			local ra, rb = RANK[a.rarity] or 99, RANK[b.rarity] or 99
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
		local list, favs = skinsOf[w] or {}, {}
		for _, s in ipairs(list) do if fav[s.id] then favs[#favs + 1] = s end end
		local from = #favs > 0 and favs or list
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
local function stepFx() guarded("tracers", stepTracers); guarded("gun position", stepViewmodel); guarded("spin", stepSpin) end
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
do local okB, eB = pcall(function() RunService:BindToRenderStep("PDSkinChangerStretchB", Enum.RenderPriority.Last.Value + 3, function() guarded("stretch", applyStretch); guarded("fov", applyFov) end) end); if not okB then warn("[SkinChanger] could not start stretch: " .. tostring(eB)) end end
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
	Size = UDim2.fromOffset(640 + SIDE, 500), Position = UDim2.new(0.5, -(640 + SIDE) / 2, 0.5, -250), BackgroundColor3 = C.bg,
	BackgroundTransparency = 0.2, BorderSizePixel = 0,
}, gui)
corner(win, 14)
stroke(win, 0.86)

-- no on-screen tab when hidden (so nobody can see you use it): RightShift brings the window back
local function setOpen(open) win.Visible = open end

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
	for i, t in ipairs({ { "skins", "Skins" }, { "fx", "Effects" }, { "boost", "Boost" }, { "display", "Display" }, { "world", "World" }, { "camera", "Camera" }, { "settings", "Settings" } }) do
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
		if not (ok and typeof(m) == "Instance") then hint.Text = "No preview for this one"; return end
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
				local ok, ms = pcall(function() return game:GetService("Stats").Network.ServerStatsItem["Data Ping"]:GetValue() end)
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

-- ===================== self highlight =====================
-- An outline/fill on YOUR OWN character only. Other players are never highlighted.
local shHl
do
local function stepSelf()
	local ch = lp.Character
	if not (sh.on and ch) then
		if shHl then shHl.Enabled = false end
		return
	end
	if not shHl or not shHl.Parent then
		shHl = Instance.new("Highlight")
		shHl.Name = "PDSkinChangerSelf"
		shHl.Parent = gui
	end
	local c = sh.color == "Rainbow" and Color3.fromHSV((os.clock() * 0.7) % 1, 0.85, 1) or TRACER_COLORS[sh.color] or TRACER_COLORS.Cyan
	shHl.Adornee = ch
	shHl.Enabled = true
	shHl.FillColor = c; shHl.OutlineColor = c
	shHl.FillTransparency = sh.fill; shHl.OutlineTransparency = sh.outline
	shHl.DepthMode = sh.onTop and Enum.HighlightDepthMode.AlwaysOnTop or Enum.HighlightDepthMode.Occluded
end
do local okB, eB = pcall(function() RunService:BindToRenderStep("PDSkinChangerSelf", Enum.RenderPriority.Last.Value + 4, function() guarded("self highlight", stepSelf) end) end); if not okB then warn("[SkinChanger] could not start self highlight: " .. tostring(eB)) end end
end

-- Display page: stretched resolution, overlay, self highlight
local dispPage = make("Frame", { Position = UDim2.fromOffset(14, 96), Size = UDim2.new(1, -28, 1, -156), BackgroundTransparency = 1, Visible = false }, win)
do
local stCard = make("Frame", { Size = UDim2.new(1 / 3, -8, 1, 0), BackgroundColor3 = C.white, BackgroundTransparency = 0.95, BorderSizePixel = 0 }, dispPage)
corner(stCard, 12); stroke(stCard, 0.93)
text(stCard, "Stretched resolution", 14, C.text, UDim2.fromOffset(14, 10), UDim2.new(1, -90, 0, 20), nil, Enum.Font.BuilderSansBold)
toggleAt(stCard, UDim2.new(1, -52, 0, 12), function() return st.on end, function(v) st.on = v end)
slider(stCard, 48, "Stretch", 0, 0.7, 0.01, function() return st.amount end, function(v) st.amount = v end, function(v) return math.floor(v * 100 + 0.5) .. " %" end)
text(stCard, "Makes everything look wider by flattening your view vertically, like a stretched monitor setting. Only your own screen changes; other players and the game are not affected. Your weapon and arms stretch with the view.", 12, C.dim, UDim2.fromOffset(14, 100), UDim2.new(1, -28, 0, 150))

local ovCard = make("Frame", { Position = UDim2.new(1 / 3, 4, 0, 0), Size = UDim2.new(1 / 3, -8, 1, 0), BackgroundColor3 = C.white, BackgroundTransparency = 0.95, BorderSizePixel = 0 }, dispPage)
corner(ovCard, 12); stroke(ovCard, 0.93)
text(ovCard, "Overlay", 14, C.text, UDim2.fromOffset(14, 10), UDim2.new(1, -90, 0, 20), nil, Enum.Font.BuilderSansBold)
toggleAt(ovCard, UDim2.new(1, -52, 0, 12), function() return hud.on end, function(v) hud.on = v; applyHud() end)
toggleRow(ovCard, 52, "Keystrokes", function() return hud.keys end, function(v) hud.keys = v; applyHud() end)
toggleRow(ovCard, 82, "FPS and ping", function() return hud.stats end, function(v) hud.stats = v; applyHud() end)
text(ovCard, "A small box with your movement keys, mouse buttons, FPS and ping. Drag it anywhere (turn on Free cursor first if you are in first person). It stays visible when you hide this window.", 12, C.dim, UDim2.fromOffset(14, 120), UDim2.new(1, -28, 0, 150))
applyHud()

local shCard = make("Frame", { Position = UDim2.new(2 / 3, 8, 0, 0), Size = UDim2.new(1 / 3, -8, 1, 0), BackgroundColor3 = C.white, BackgroundTransparency = 0.95, BorderSizePixel = 0 }, dispPage)
corner(shCard, 12); stroke(shCard, 0.93)
text(shCard, "Self highlight", 14, C.text, UDim2.fromOffset(14, 10), UDim2.new(1, -90, 0, 20), nil, Enum.Font.BuilderSansBold)
toggleAt(shCard, UDim2.new(1, -52, 0, 12), function() return sh.on end, function(v) sh.on = v end)
text(shCard, "Color", 12, C.dim, UDim2.fromOffset(14, 40), UDim2.new(1, -28, 0, 16))
local shSw = {}
for i, name in ipairs(COLOR_ORDER) do
	local b = make("TextButton", {
		Text = name == "Rainbow" and "R" or "", Position = UDim2.fromOffset(14 + (i - 1) * 26, 58), Size = UDim2.fromOffset(20, 20),
		BackgroundColor3 = TRACER_COLORS[name] or Color3.fromRGB(255, 160, 60), AutoButtonColor = false, TextColor3 = C.bg,
		Font = Enum.Font.BuilderSansBold, TextSize = 11,
	}, shCard)
	corner(b, 10)
	local ring = make("UIStroke", { Color = C.text, Thickness = 2, Transparency = 1 }, b)
	shSw[name] = ring
	b.MouseButton1Click:Connect(function()
		sh.color = name
		for n2, r2 in pairs(shSw) do r2.Transparency = (n2 == sh.color) and 0 or 1 end
		save()
	end)
end
repaints[#repaints + 1] = function() for n2, r2 in pairs(shSw) do r2.Transparency = (n2 == sh.color) and 0 or 1 end end
for n2, r2 in pairs(shSw) do r2.Transparency = (n2 == sh.color) and 0 or 1 end
slider(shCard, 90, "Fill", 0, 1, 0.05, function() return 1 - sh.fill end, function(v) sh.fill = 1 - v end, function(v) return math.floor(v * 100 + 0.5) .. " %" end)
slider(shCard, 130, "Outline", 0, 1, 0.05, function() return 1 - sh.outline end, function(v) sh.outline = 1 - v end, function(v) return math.floor(v * 100 + 0.5) .. " %" end)
toggleRow(shCard, 172, "Show over everything", function() return sh.onTop end, function(v) sh.onTop = v end)
text(shCard, "Outlines and tints your own character, like a glow. Only you and only your character: other players are not affected and nothing about them is shown. In first person you mostly see it on your arms and legs.", 12, C.dim, UDim2.fromOffset(14, 204), UDim2.new(1, -28, 0, 110))

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
local setFrame, binding, paintKeys, applyAccent   -- binding: "keyMenu" / "keyCursor" while waiting for a new key
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
text(hkCard, "Click a key box, then press the new key. Esc cancels. Only keyboard keys can be used.", 12, C.dim, UDim2.fromOffset(14, 124), UDim2.new(1, -28, 0, 60))
paintKeys()

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

local function defaults()
	tr.on, tr.color, tr.thick, tr.life, tr.glow, tr.streak, tr.replace = false, "Cyan", 0.12, 0.6, true, false, true
	spin.on, spin.speed, spin.dir, spin.axis, spin.mode = false, 180, 1, "Y", "Continuous"
	st.on, st.amount = false, 0.35
	hud.on, hud.keys, hud.stats = false, true, true
	sh.on, sh.color, sh.fill, sh.outline, sh.onTop = false, "Cyan", 0.65, 0, true
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
for _, f in ipairs({ left.frame, right.frame, fxPage, dispPage, worldPage, camPage, boostPage, setFrame, bar }) do
	local dy = (f == bar) and 0 or 34
	f.Position += UDim2.fromOffset(SIDE - 4, -dy)
	f.Size += UDim2.fromOffset(f.Size.X.Scale > 0 and -(SIDE - 4) or 0, dy)
end
previewPanel.Position += UDim2.fromOffset(0, -34)
previewPanel.Size += UDim2.fromOffset(0, 34)

local page = "skins"
local pages = { fx = fxPage, boost = boostPage, display = dispPage, world = worldPage, camera = camPage, settings = setFrame }
local tabs = tabBtns
local PAGE_MSG = {
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
	Size = UDim2.fromOffset(540, 450), Position = UDim2.new(0.5, -270, 0.5, -225), BackgroundColor3 = C.bg,
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
	if binding then   -- the Settings tab is waiting for a new hotkey
		if i.UserInputType == Enum.UserInputType.Keyboard then
			if i.KeyCode ~= Enum.KeyCode.Escape then ui[binding] = i.KeyCode.Name; save() end
			binding = nil; paintKeys(); helpText.Text = helpString()
		end
		return
	end
	if gp then return end
	if i.KeyCode == keyOf(ui.keyMenu) then setOpen(not win.Visible)
	elseif i.KeyCode == keyOf(ui.keyCursor) then setFreeCursor(not freeCursor) end
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

local function unload()
	if not alive then return end
	alive = false
	for _, name in ipairs({ "PDSkinChangerArms", "PDSkinChangerCursor", "PDSkinChangerFx", "PDSkinChangerSelf", "PDSkinChangerBlur", "PDSkinChangerTint", "PDSkinChangerStretchB", "PDSkinChangerStretchA" }) do
		pcall(function() RunService:UnbindFromRenderStep(name) end)
	end
	pcall(function() if shHl then shHl:Destroy() end end)
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
		if CE and wrapShot and CE.shot == wrapShot then CE.shot = origShot end	end)
	for _, c in ipairs(conns) do pcall(function() c:Disconnect() end) end
	pcall(function() gui:Destroy() end)
	_G.PistolDuelsSkinChanger = nil
end
closeBtn.MouseButton1Click:Connect(unload)

_G.PistolDuelsSkinChanger = {
	unload = unload, sel = sel, pat = pat, wear = wear, hits = function() return hits end, reEquip = reEquip,
	setHideArms = setHideArms, hideArms = function() return hideArms end,
	setFreeCursor = setFreeCursor, freeCursor = function() return freeCursor end,
	tr = tr, spin = spin, st = st, hud = hud, sh = sh, wd = wd, mb = mb, vm = vm, opt = opt, applyOpt = applyOpt, tints = tints, showPreview = function(id) showPreview(id) end, ui = ui, fav = fav, loadouts = loadouts, shuffle = shuffle, applyWorld = applyWorld, tracer = spawnTracer,
}
print(("[SkinChanger] ready: %d weapons, %d skins"):format(#weapons, (function() local n = 0 for _, l in pairs(skinsOf) do n += #l end return n end)()))
