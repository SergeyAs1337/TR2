-- ===== Макет Roblox: время, корутины =====
-- os в Luau только для чтения: подменяем таблицей-обёрткой, чтобы тесты могли подставлять os.clock
local realOs = os
os = setmetatable({}, {__index = realOs})
local now = 0; local queue = {}
local function step(co, ...)
	local ok, res = coroutine.resume(co, ...)
	if not ok then print("ERROR in coroutine:", res) end
	if coroutine.status(co) == "suspended" and type(res) == "table" and res.wake then table.insert(queue, {co = co, wake = res.wake}) end
end
local function clearQueue() queue = {} end
task = {
	spawn = function(f, ...) local co = coroutine.create(f); step(co, ...); return co end,
	wait = function(t) coroutine.yield({wake = now + (t or 0.03)}) return t end,
	defer = function(f, ...) local co = coroutine.create(f); step(co, ...); return co end,
	delay = function(t, f, ...) local args = {...}; local co = coroutine.create(function() task.wait(t); f(table.unpack(args)) end); step(co) end,
}
local function runFor(s)
	local limit = now + s
	while true do
		table.sort(queue, function(a, b) return a.wake < b.wake end)
		local nxt = queue[1]
		if not nxt or nxt.wake > limit then now = limit break end
		table.remove(queue, 1); now = math.max(now, nxt.wake); step(nxt.co)
	end
end
local warnCount = 0
function warn(...) warnCount += 1 end

-- ===== Vector3 / CFrame =====
local V3 = {}
local function v3(x, y, z) return setmetatable({X = x, Y = y, Z = z}, V3) end
V3.__index = function(t, k)
	if k == "Magnitude" then return math.sqrt(t.X ^ 2 + t.Y ^ 2 + t.Z ^ 2)
	elseif k == "Unit" then local m = math.sqrt(t.X ^ 2 + t.Y ^ 2 + t.Z ^ 2); return v3(t.X / m, t.Y / m, t.Z / m)
	elseif k == "Dot" then return function(a, b) return a.X * b.X + a.Y * b.Y + a.Z * b.Z end end
end
V3.__add = function(a, b) return v3(a.X + b.X, a.Y + b.Y, a.Z + b.Z) end
V3.__sub = function(a, b) return v3(a.X - b.X, a.Y - b.Y, a.Z - b.Z) end
V3.__div = function(a, b) return v3(a.X / b, a.Y / b, a.Z / b) end
V3.__eq = function(a, b) return a.X == b.X and a.Y == b.Y and a.Z == b.Z end
V3.__mul = function(a, b)
	if type(a) == "number" then return v3(a * b.X, a * b.Y, a * b.Z) elseif type(b) == "number" then return v3(a.X * b, a.Y * b, a.Z * b) end
	return v3(a.X * b.X, a.Y * b.Y, a.Z * b.Z) end
Vector3 = {new = v3, zero = v3(0, 0, 0), one = v3(1, 1, 1), yAxis = v3(0, 1, 0)}
local CF = {}
CF.__mul = function(a, b) return CFrame.new(rawget(a, "_p") + rawget(b, "_p")) end
CF.__index = function(t, k) if k == "Position" then return rawget(t, "_p") elseif k == "LookVector" then return rawget(t, "_look") elseif k == "PointToObjectSpace" then return function(self, v) return v - rawget(self, "_p") end end end
CFrame = {new = function(a, b, c) local p = type(a) == "number" and v3(a, b, c) or a; return setmetatable({_p = p, _look = v3(0, 0, -1)}, CF) end}
UDim2 = {new = function(a, b, c, d) return {a, b, c, d} end}
Color3 = {new = function(r, g, b) return {r, g, b} end, fromRGB = function(r, g, b) return {r, g, b} end, fromHSV = function(hh, s, v) return {hsv = {hh, s, v}} end}
UDim = {new = function(s, o) return {s, o} end}
Vector2 = {new = function(x, y) return {x, y} end}
local UIS = {InputBegan = nil}
Enum = {RaycastFilterType = {Exclude = "Exclude"}, PathStatus = {Success = "Success"}, PathWaypointAction = {Jump = "Jump", Walk = "Walk"}, Font = {GothamBlack = "GothamBlack"}}
OverlapParams = {new = function() return {FilterType = nil, FilterDescendantsInstances = {}} end}
RaycastParams = {new = function() return {FilterType = nil, FilterDescendantsInstances = {}} end}

-- ===== Signal =====
local function Signal()
	local s = {handlers = {}}
	function s:Connect(f) table.insert(self.handlers, f); local h = f; return {Disconnect = function() for i, x in ipairs(s.handlers) do if x == h then table.remove(s.handlers, i) break end end end} end
	function s:Fire(...) for _, h in ipairs({table.unpack(self.handlers)}) do task.spawn(h, ...) end end
	function s:Once(f) local c; c = self:Connect(function(...) c.Disconnect(); f(...) end); return c end
	return s
end

local groundFn = function() return 10 end
local pathFn, pathCalls, pathDelay = nil, 0, 0.05

-- ===== Instance =====
local partClasses = {Part = true, MeshPart = true, UnionOperation = true}
local Inst_mt = {}
local methods = {}
local cloneCount = {}
local announced = {}
local function newInst(class, name)
	local o = setmetatable({}, Inst_mt)
	rawset(o, "_p", {ClassName = class, Name = name or class, Anchored = false, CanCollide = true, CastShadow = true,
		CFrame = CFrame.new(0, 0, 0), Position = v3(0, 0, 0), AssemblyLinearVelocity = v3(0, 0, 0), AssemblyAngularVelocity = v3(0, 0, 0)})
	rawset(o, "_kids", {})
	return o
end
Inst_mt.__index = function(t, k)
	local m = methods[k]; if m then return m end
	local p = rawget(t, "_p")
	if (k == "Touched" or k == "MoveToFinished" or k == "CharacterAdded" or k == "Activated" or k == "FocusLost" or k == "MouseEnter" or k == "MouseLeave" or k == "MouseButton1Down" or k == "MouseButton1Up" or k == "OnClientEvent" or k == "Died" or k == "ChildAdded" or k == "CharacterRemoving" or k == "Jumping" or k == "Triggered" or k == "Stopped" or k == "Event" or k == "AncestryChanged" or k == "DescendantAdded") then if not p[k] then p[k] = Signal() end return p[k] end
	if k == "AssemblyRootPart" then return p.AssemblyRootPart or t end
	if p[k] ~= nil then return p[k] end
	return methods.FindFirstChild(t, k)
end
Inst_mt.__newindex = function(t, k, v)
	local p = rawget(t, "_p")
	if k == "Parent" then
		local old = p.Parent
		if old then for i, c in ipairs(rawget(old, "_kids")) do if c == t then table.remove(rawget(old, "_kids"), i) break end end end
		p.Parent = v
		if v then table.insert(rawget(v, "_kids"), t) end
		if old ~= v and rawget(p, "AncestryChanged") then p.AncestryChanged:Fire(t, v) end
	elseif k == "CFrame" then p.CFrame = v; p.Position = v.Position
	elseif k == "Position" then p.Position = v; p.CFrame = CFrame.new(v)
	else local old = p[k]; p[k] = v; if old ~= v and p._changed and p._changed[k] then p._changed[k]:Fire() end end
end
local function descendants(inst, out)
	out = out or {}
	for _, c in ipairs(rawget(inst, "_kids")) do table.insert(out, c); descendants(c, out) end
	return out
end
function methods.GetDescendants(self) return descendants(self) end
function methods.GetChildren(self) return {table.unpack(rawget(self, "_kids"))} end
function methods.FindFirstChild(self, name, recursive)
	for _, c in ipairs(rawget(self, "_kids")) do if c.Name == name then return c end end
	if recursive then for _, c in ipairs(descendants(self)) do if c.Name == name then return c end end end
end
methods.WaitForChild = methods.FindFirstChild
function methods.FindFirstChildWhichIsA(self, cls) for _, c in ipairs(rawget(self, "_kids")) do if methods.IsA(c, cls) then return c end end end
function methods.ChangeState(self, state) rawget(self, "_p").lastState = state end
function methods.GetPivot(self) local pp = rawget(self, "_p").PrimaryPart; if pp then return pp.CFrame end return self.CFrame end
function methods.LoadAnimation(self, anim) local tr = {Looped = false, IsPlaying = false, Stopped = nil, AnimationId = anim.AnimationId}; local sig = nil
	tr.Stopped = (function() local s = {handlers = {}}; function s:Connect(f) table.insert(self.handlers, f); return {Disconnect = function() end} end; function s:Fire() for _, h in ipairs(self.handlers) do h() end end; return s end)()
	function tr:Play() self.IsPlaying = true end
	function tr:Stop() if self.IsPlaying then self.IsPlaying = false; self.Stopped:Fire() end end
	local p = rawget(self, "_p"); p.loaded = p.loaded or {}; table.insert(p.loaded, tr); return tr end
function methods.FindFirstChildOfClass(self, cls) for _, c in ipairs(rawget(self, "_kids")) do if c.ClassName == cls then return c end end end
function methods.IsA(self, cls) local c = self.ClassName; return c == cls or cls == "Instance" or (cls == "BasePart" and partClasses[c] == true) end
function methods.FindFirstAncestorOfClass(self, cls) local p = self.Parent; while p do if p.ClassName == cls then return p end p = p.Parent end end
function methods.IsDescendantOf(self, anc) local p = self.Parent; while p do if p == anc then return true end p = p.Parent end return false end
function methods.Destroy(self) self.Parent = nil; rawget(self, "_p").Destroyed = true end
function methods.Clone(self)
	local map = {}
	local function copy(src)
		local c = newInst(src.ClassName, src.Name)
		local sp, cp = rawget(src, "_p"), rawget(c, "_p")
		for k, v in pairs(sp) do if k ~= "Parent" and k ~= "Touched" and k ~= "MoveToFinished" and k ~= "PrimaryPart" and k ~= "AssemblyRootPart" and k ~= "Destroyed" then cp[k] = v end end
		map[src] = c
		for _, kid in ipairs(rawget(src, "_kids")) do local kc = copy(kid); kc.Parent = c end
		return c
	end
	local c = copy(self)
	for src, cl in pairs(map) do local pp = rawget(src, "_p").PrimaryPart; if pp then rawget(cl, "_p").PrimaryPart = map[pp] end end
	cloneCount[self.Name] = (cloneCount[self.Name] or 0) + 1
	return c
end
function methods.PivotTo(self, cf)
	local pp = rawget(self, "_p").PrimaryPart
	if self.ClassName == "Model" and pp then pp.CFrame = cf else self.CFrame = cf end
end
function methods.Play(self) local p = rawget(self, "_p"); p.IsPlaying = true; p.PlayCount = (p.PlayCount or 0) + 1 end
function methods.Stop(self) rawget(self, "_p").IsPlaying = false end
function methods.MoveTo(self, pos) local p = rawget(self, "_p"); p.Moves = (p.Moves or 0) + 1; p.LastMove = pos; task.delay(0.1, function() self.MoveToFinished:Fire() end) end
function methods.SetNetworkOwner(self, owner) local p = rawget(self, "_p"); p.NetOwnerCalled = true; p.NetOwner = owner end
function methods.GetPropertyChangedSignal(self, prop) local p = rawget(self, "_p"); p._changed = p._changed or {}; if not p._changed[prop] then p._changed[prop] = Signal() end return p._changed[prop] end
function methods.FireServer(self, ...) local p = rawget(self, "_p"); p.fired = p.fired or {}; table.insert(p.fired, {...}); if p.OnServerEvent then p.OnServerEvent:Fire(LocalPlayerRef, ...) end end
function methods.SetAttribute(self, k, v) local p = rawget(self, "_p"); p.attrs = p.attrs or {}; local old = p.attrs[k]; p.attrs[k] = v; if old ~= v and p._attrChanged and p._attrChanged[k] then p._attrChanged[k]:Fire() end end
function methods.GetAttributeChangedSignal(self, k) local p = rawget(self, "_p"); p._attrChanged = p._attrChanged or {}; if not p._attrChanged[k] then p._attrChanged[k] = Signal() end return p._attrChanged[k] end
function methods.FireClient(self, plr, ...) local p = rawget(self, "_p"); p.clientFired = p.clientFired or {}; table.insert(p.clientFired, {plr, ...}) end
function methods.GetAttribute(self, k) local p = rawget(self, "_p"); return p.attrs and p.attrs[k] end
function methods.Kick(self, msg) rawget(self, "_p").kicked = msg or "" end
function methods.GetServerTimeNow(self) return now end
function methods.FireAllClients(self, ...) table.insert(announced, (...)) end
local Workspace
local groundInst = nil
local function boxOf(part)
	local s, c = part.Size, part.Position
	return v3(c.X - s.X / 2, c.Y - s.Y / 2, c.Z - s.Z / 2), v3(c.X + s.X / 2, c.Y + s.Y / 2, c.Z + s.Z / 2)
end
local function rayBox(o, d, bmin, bmax)
	local tmin, tmax, normal = 0, 1, nil
	local oa, da, mina, maxa = {o.X, o.Y, o.Z}, {d.X, d.Y, d.Z}, {bmin.X, bmin.Y, bmin.Z}, {bmax.X, bmax.Y, bmax.Z}
	for i = 1, 3 do
		if math.abs(da[i]) < 1e-9 then
			if oa[i] < mina[i] or oa[i] > maxa[i] then return nil end
		else
			local t1, t2, sign = (mina[i] - oa[i]) / da[i], (maxa[i] - oa[i]) / da[i], -1
			if t1 > t2 then t1, t2, sign = t2, t1, 1 end
			if t1 > tmin then tmin = t1; local n = {0, 0, 0}; n[i] = sign; normal = v3(n[1], n[2], n[3]) end
			if t2 < tmax then tmax = t2 end
			if tmin > tmax then return nil end
		end
	end
	return tmin, normal or v3(0, 0, 0)
end
local function excludedBy(part, params)
	for _, ex in ipairs((params and params.FilterDescendantsInstances) or {}) do
		if part == ex or part:IsDescendantOf(ex) then return true end
	end
	return false
end
local function castBoxes(origin, direction, params, radius, withGround)
	local best = nil
	local L = direction.Magnitude
	for _, d in ipairs(descendants(Workspace)) do
		if d.Size and d.CanCollide ~= false and not excludedBy(d, params) then
			local bmin, bmax = boxOf(d)
			bmin = v3(bmin.X - radius, bmin.Y - radius, bmin.Z - radius); bmax = v3(bmax.X + radius, bmax.Y + radius, bmax.Z + radius)
			local t, n = rayBox(origin, direction, bmin, bmax)
			if t and (not best or t < best.t) then best = {t = t, normal = d.RampNormal or n, inst = d} end
		end
	end
	if withGround and direction.Y < -1e-9 then
		local g = groundFn(origin.X, origin.Z)
		if origin.Y >= g then
			local t = (g - origin.Y) / direction.Y
			if t <= 1 and (not best or t < best.t) then
				groundInst = groundInst or (function() local p = newInst("Part", "Osnova"); p.Anchored = true; return p end)()
				best = {t = t, normal = v3(0, 1, 0), inst = groundInst}
			end
		end
	end
	if not best then return nil end
	return {Instance = best.inst, Position = origin + direction * best.t, Normal = best.normal, Distance = best.t * L}
end
function methods.Raycast(self, origin, direction, params) return castBoxes(origin, direction, params, 0, true) end
function methods.Spherecast(self, origin, radius, direction, params) return castBoxes(origin, direction, params, radius, false) end
function methods.GetPartBoundsInRadius(self, pos, r, params)
	local out = {}
	for _, d in ipairs(descendants(self)) do
		if partClasses[d.ClassName] and d.CanQuery ~= false and not excludedBy(d, params) then
			local dist
			if d.Size then
				local bmin, bmax = boxOf(d)
				local cx, cy, cz = math.max(bmin.X, math.min(pos.X, bmax.X)), math.max(bmin.Y, math.min(pos.Y, bmax.Y)), math.max(bmin.Z, math.min(pos.Z, bmax.Z))
				dist = (v3(cx, cy, cz) - pos).Magnitude
				if dist <= r then table.insert(out, d) end
			elseif (d.Position - pos).Magnitude <= r + 5 then
				table.insert(out, d)
			end
		end
	end
	return out
end
Instance = {new = function(class) return newInst(class) end}

-- ===== Службы =====
Workspace = newInst("Workspace", "Workspace")
local ReplicatedStorage = newInst("ReplicatedStorage")
local ServerStorage = newInst("ServerStorage")
local ServerScriptService = newInst("ServerScriptService")
local playerList = {}
local PlayersSvc = {MaxPlayers = 50, PlayerAdded = Signal(), PlayerRemoving = Signal(),
	GetPlayerByUserId = function(self, id) for _, p in ipairs(playerList) do if p.UserId == id then return p end end end,
	GetPlayers = function() return {table.unpack(playerList)} end,
	GetPlayerFromCharacter = function(self, ch) for _, p in ipairs(playerList) do if p.Character == ch then return p end end end}
local Debris = {AddItem = function(self, inst, t) task.delay(t, function() if not rawget(inst, "_p").Destroyed then inst:Destroy() end end) end}
local Pathfinding = {CreatePath = function()
	pathCalls += 1
	local obj = {Status = "NoPath", _wps = {}}
	function obj:ComputeAsync(a, b)
		task.wait(pathDelay)
		local list = pathFn and pathFn(a, b)
		if list then self.Status = "Success"; self._wps = list else self.Status = "NoPath" end
	end
	function obj:GetWaypoints() return self._wps end
	return obj end}
local RunServiceSvc = {IsServer = function() return true end, IsClient = function() return false end, IsStudio = function() return false end}
local heartbeat = Signal(); RunServiceSvc.Heartbeat = heartbeat
local renderStepped = Signal(); RunServiceSvc.RenderStepped = renderStepped
local function startHeartbeat() task.spawn(function() while true do heartbeat:Fire(1 / 60); task.wait(1 / 60) end end) end
local tweenLog = {}
TweenInfo = {new = function(t) return {Time = t or 1} end}
local tags = {}
local CollectionSvc = {GetTagged = function(self, tag) return tags[tag] or {} end, GetInstanceAddedSignal = function(self, tag) return Signal() end}
local PhysicsSvc = {groups = {}, RegisterCollisionGroup = function(self, g) self.groups[g] = true end, CollisionGroupSetCollidable = function() end}
PhysicalProperties = {new = function(...) return {...} end}
BrickColor = BrickColor or {new = function(n) return {Name = n} end}
local CASvc = {bound = {}, BindAction = function(self, name, fn, touch, ...) self.bound[name] = {fn = fn, keys = {...}} end, UnbindAction = function(self, name) self.bound[name] = nil end}
local MarketSvc = {owns = {}, prompts = {}, failCheck = false,
	UserOwnsGamePassAsync = function(self, uid, pass) if self.failCheck then error("market down") end return self.owns[uid] == true end,
	PromptGamePassPurchase = function(self, plr, pass) table.insert(self.prompts, {plr, pass}) end}
ColorSequence = {new = function(a, b) return {a, b or a} end}
-- HttpService: JSON только для плоских объектов {"Имя":число}, этого хватает тестам
local HttpSvc = {
	JSONEncode = function(self, t) local parts = {}; for k, v in pairs(t) do table.insert(parts, string.format('"%s":%s', k, tostring(v))) end; table.sort(parts); return "{" .. table.concat(parts, ",") .. "}" end,
	JSONDecode = function(self, str) local t = {}; if type(str) ~= "string" or string.sub(str, 1, 1) ~= "{" then error("bad json") end; for k, v in string.gmatch(str, '"([^"]+)"%s*:%s*([%-%d%.]+)') do t[k] = tonumber(v) end; return t end,
}
local TweenSvc = {Create = function(self, inst, info, goals)
	local tw = {Completed = Signal()}
	table.insert(tweenLog, {inst = inst, info = info, goals = goals})
	local cancelled = false
	function tw:Play() task.delay(info.Time, function() if cancelled then return end for k, v in pairs(goals) do inst[k] = v end; tw.Completed:Fire() end) end
	function tw:Cancel() cancelled = true end
	return tw
end}
local filterMode = "pass"
local TextServiceSvc = {FilterStringAsync = function(self, msg, uid, ctx)
	if filterMode == "error" then error("filter down") end
	return {GetNonChatStringForBroadcastAsync = function() if filterMode == "censor" then return (string.gsub(msg, "bad", "###")) end return msg end}
end}
Enum.TextFilterContext = {PublicChat = "PublicChat"}
game = {PlaceVersion = 42, JobId = "abcdef0123456789", GetService = function(self, n)
	local t = {TweenService = TweenSvc, UserInputService = UIS, TextService = TextServiceSvc, Players = PlayersSvc, Workspace = Workspace, ReplicatedStorage = ReplicatedStorage, ServerStorage = ServerStorage,
		ServerScriptService = ServerScriptService, HttpService = HttpSvc, ContextActionService = CASvc, CollectionService = CollectionSvc, PhysicsService = PhysicsSvc, MarketplaceService = MarketSvc, Debris = Debris, PathfindingService = Pathfinding, RunService = RunServiceSvc}
	return t[n]
end}
local EventsModuleInst = newInst("ModuleScript", "EventManager"); EventsModuleInst.Parent = ReplicatedStorage
local loadedEvents = nil
local moduleRegistry = {}
function require(m) if m == EventsModuleInst then return loadedEvents end return moduleRegistry[m] end

-- ===== Фабрики сцены =====
local function mkPart(name, pos, anchored)
	local p = newInst("Part", name); p.Position = pos; p.Anchored = anchored or false; return p
end
local function mkModelWithPrimary(name, nParts, primaryName)
	local m = newInst("Model", name)
	local primary = mkPart(primaryName or "PrimaryPart", v3(0, 0, 0)); primary.Parent = m
	for i = 1, nParts - 1 do local pt = mkPart("Part" .. i, v3(0, 0, 0), true); pt.Parent = m end
	rawget(m, "_p").PrimaryPart = primary
	return m, primary
end
local uid = 0
local function mkPlayer(name, pos, opts)
	opts = opts or {}
	uid += 1
	local pl = newInst("Player", name); pl.DisplayName = name; pl.UserId = uid
	if not opts.noGui then local gui = newInst("PlayerGui"); gui.Parent = pl end
	if not opts.noCharacter then
		local ch = newInst("Model", name .. "_char")
		local hrp = mkPart("HumanoidRootPart", pos); hrp.Parent = ch
		local hum = newInst("Humanoid"); hum.Health = opts.health or 100; hum.MaxHealth = 100; hum.SeatPart = opts.seated and newInst("Seat") or nil; hum.Parent = ch
		rawget(ch, "_p").PrimaryPart = hrp
		pl.Character = ch
	end
	table.insert(playerList, pl)
	return pl
end
local function mkWall(name, center, size, opts)
	local w = newInst("Part", name); w.Position = center; w.Size = size; w.Anchored = true
	if opts then for k, v in pairs(opts) do w[k] = v end end
	w.Parent = Workspace; return w
end
local function resetWorld()
	clearQueue(); now = 0; warnCount = 0
	for _, root in ipairs({Workspace, ServerStorage, ServerScriptService}) do for _, c in ipairs(methods.GetChildren(root)) do c.Parent = nil end end
	for _, c in ipairs(methods.GetChildren(ReplicatedStorage)) do if c ~= EventsModuleInst then c.Parent = nil end end
	playerList = {}; announced = {}; cloneCount = {}
	-- шаблоны
	local truck = mkModelWithPrimary("Furocka3", 46, "Body"); truck.Parent = ServerStorage
	local bomb = mkModelWithPrimary("BombModel", 1, "PrimaryPart"); bomb.Parent = ServerStorage
	local bot = newInst("Model", "Nexbot")
	local hrp = mkPart("HumanoidRootPart", v3(0, 0, 0)); hrp.Parent = bot
	local hum = newInst("Humanoid"); hum.Parent = bot
	local sounds = newInst("Folder", "Sounds"); sounds.Parent = bot
	Workspace.Gravity = 196.2; Workspace.DistributedGameTime = 123.7
	for _, n in ipairs({"Chase", "Hit", "End", "Spawn", "Jump"}) do local s = newInst("Sound", n); s.TimeLength = 2; s.Parent = sounds end
	bot.Parent = ServerStorage
	local snd = newInst("Sound", "RocketExplosionSound"); snd.Parent = ReplicatedStorage
	local ann = newInst("RemoteEvent", "EventAnnouncement"); ann.OnServerEvent = Signal(); ann.Parent = ReplicatedStorage
	local stopR = newInst("RemoteEvent", "StopEventRemote"); stopR.OnServerEvent = Signal(); stopR.Parent = ReplicatedStorage
	for _, n in ipairs({"TruckSpawner", "TruckSpawner2"}) do local s = newInst("Script", n); s.Disabled = false; s.Parent = ServerScriptService end
	local ramki = newInst("Model", "ramki"); ramki.Parent = Workspace
	local rain = mkPart("RainFall", v3(0, 100, 0), true); rain.Parent = ramki
	local em = newInst("ParticleEmitter"); em.Enabled = false; em.Parent = rain
end
-- typeof как в Roblox: макетные объекты — Instance / Vector3 / CFrame, а не table
local realTypeof = typeof
typeof = function(v)
	if type(v) == "table" then
		local mt = getmetatable(v)
		if mt == Inst_mt then return "Instance" end
		if mt == V3 then return "Vector3" end
		if mt == CF then return "CFrame" end
	end
	return realTypeof(v)
end
UIS.InputBegan = Signal()
MarketSvc.PromptGamePassPurchaseFinished = Signal()
CFrame.lookAt = function(a, b) return CFrame.new(a) end
local function check(n, c) print((c and "PASS " or "FAIL ") .. n) end
