-- Executes actual shipped Lua-compatible core modules, using mocked Roblox API objects.
-- Run from the ZIP root: texlua tests/offline_regression.lua (or Lua 5.3+).
local base = "src/server/AI/"
local realRequire = require
local cache = {}

script = { Parent = setmetatable({}, {
	__index = function(_, k)
		return k
	end,
}) }
function require(name)
	if type(name) ~= "string" then
		return realRequire(name)
	end
	if cache[name] == nil then
		cache[name] = assert(loadfile(base .. name .. ".luau"))()
	end
	return cache[name]
end

local now = 0

os.clock = function()
	return now
end
math.clamp = function(v, a, b)
	return math.max(a, math.min(b, v))
end
math.round = function(v)
	return math.floor(v + 0.5)
end
math.atan2 = math.atan2 or math.atan
table.freeze = function(t)
	return t
end

function warn(...)
	print(...)
end

function typeof(v)
	return type(v) == "table" and v._type or type(v)
end

local V = {}
local mt = {}

function V.new(x, y, z)
	return setmetatable({ X = x, Y = y, Z = z, _type = "Vector3" }, mt)
end

mt.__index = function(a, k)
	if k == "Magnitude" then
		return math.sqrt(a.X * a.X + a.Y * a.Y + a.Z * a.Z)
	end
	if k == "Unit" then
		return a / a.Magnitude
	end
	return V[k]
end

mt.__add = function(a, b)
	return V.new(a.X + b.X, a.Y + b.Y, a.Z + b.Z)
end
mt.__sub = function(a, b)
	return V.new(a.X - b.X, a.Y - b.Y, a.Z - b.Z)
end
mt.__unm = function(a)
	return V.new(-a.X, -a.Y, -a.Z)
end
mt.__mul = function(a, b)
	if type(a) == "number" then
		a, b = b, a
	end
	return V.new(a.X * b, a.Y * b, a.Z * b)
end
mt.__div = function(a, b)
	return V.new(a.X / b, a.Y / b, a.Z / b)
end

function V:Dot(b)
	return self.X * b.X + self.Y * b.Y + self.Z * b.Z
end

Vector3 = V
V.zero = V.new(0, 0, 0)
Enum = {
	Material = { Air = "Air", Ground = "Ground" },
	PathWaypointAction = { Jump = "Jump", Walk = "Walk" },
	PathStatus = { Success = "Success", NoPath = "NoPath" },
	RaycastFilterType = { Exclude = "Exclude" },
	HumanoidStateType = { Jumping = "Jumping", Freefall = "Freefall", Running = "Running" },
}
RaycastParams = {
	new = function()
		return {}
	end,
}

local players = { list = {} }
function players:GetPlayers()
	return self.list
end

local world = { hit = nil }

function world:Raycast(_, delta, params)
	if self.floorHit and delta.Y < 0 and delta.X == 0 and delta.Z == 0 then
		return self.floorHit
	end
	if self.hit and params and params.FilterDescendantsInstances then
		for _, item in ipairs(params.FilterDescendantsInstances) do
			if item == self.hit.Instance then
				return nil
			end
		end
	end
	return self.hit
end

local plans = {}
local planMode = "Success"
local pauseCompute = false
local service = {}

function service:CreatePath()
	local path = { Status = planMode, destroyed = false, Blocked = {} }
	function path.Blocked:Connect(f)
		path.blockedCallback = f
		return {
			Disconnect = function()
				path.blockedCallback = nil
			end,
		}
	end
	function path:ComputeAsync(start, goal)
		self.start = start
		self.goal = goal
		if pauseCompute then
			coroutine.yield()
		end
	end

	function path:GetWaypoints()
		return {
			{ Position = self.start, Action = "Walk" },
			{ Position = self.start + (self.goal - self.start) * 0.5, Action = "Walk" },
			{ Position = self.goal, Action = "Walk" },
		}
	end

	function path:Destroy()
		self.destroyed = true
	end
	plans[#plans + 1] = path
	return path
end

game = {
	GetService = function(_, name)
		return ({ Players = players, Workspace = world, PathfindingService = service })[name]
	end,
}
local pending, cancelled = {}, {}

task = {
	defer = function(f)
		local co = coroutine.create(f)
		pending[#pending + 1] = co
		return co
	end,
	cancel = function(co)
		cancelled[co] = true
	end,
}

local function flush()
	local old = pending
	pending = {}
	for _, co in ipairs(old) do
		if not cancelled[co] and coroutine.status(co) ~= "dead" then
			local ok, err = coroutine.resume(co)
			assert(ok, err)
			if coroutine.status(co) ~= "dead" then
				pending[#pending + 1] = co
			end
		end
	end
end

local S = require("Settings")
local function flat(v)
	return V.new(v.X, 0, v.Z)
end

local function ctxNew()
	local attrs = {}
	local npc = {
		SetAttribute = function(_, k, v)
			attrs[k] = v
		end,
		GetAttribute = function(_, k)
			return attrs[k]
		end,
	}
	local root = { Position = V.new(0, 3, 0), Parent = true, CFrame = { LookVector = V.new(1, 0, 0) } }
	local human = { Health = 100, Parent = true, FloorMaterial = "Ground", MoveDirection = V.zero, WalkSpeed = 19 }

	function human:MoveTo(goal)
		self.goal = goal
		self.commands = (self.commands or 0) + 1
	end
	function human:Move(direction)
		self.MoveDirection = direction
	end

	local c = {
		npc = npc,
		root = root,
		humanoid = human,
		SETTINGS = S,
		running = true,
		state = "Chasing",
		mode = "None",
		modeSince = now,
		waypoints = {},
		waypointIndex = 2,
		pathGeneration = 0,
		failedPaths = 0,
		nextPath = 0,
		lastCommandTime = 0,
		recoveryUntil = 0,
		progressPosition = root.Position,
		progressTime = now,
		lastRouteTime = now,
		waypointProgressAt = now,
		flat = flat,
		distance2D = function(a, b)
			return flat(a - b).Magnitude
		end,
		groundAt = function(pos)
			return V.new(pos.X, 0, pos.Z)
		end,
		directClear = function()
			return false
		end,
	}
	require("Movement")(c)
	require("Navigation")(c)
	c.resetRecovery()
	return c, attrs
end

local total = 0
local function test(name, fn)
	now = 0
	pending = {}
	cancelled = {}
	plans = {}
	planMode = "Success"
	pauseCompute = false
	fn()
	total = total + 1
	print("PASS " .. name)
end

local P = require("RoutePolicy")
test("retry is bounded and increases", function()
	assert(P.retryDelay(1, 0.5, 3) == 0.5 and P.retryDelay(2, 0.5, 3) == 1 and P.retryDelay(100, 0.5, 3) == 3)
end)

test("target lock lifetime does not depend on perception", function()
	assert(not P.targetEnded(true, false, false, false))
	assert(P.targetEnded(false, false, false, false))
	assert(P.targetEnded(true, true, false, false))
	assert(P.targetEnded(true, false, true, false))
	assert(P.targetEnded(true, false, false, true))
end)

test("direct movement, no path request, arrival stops", function()
	local c = ctxNew()
	c.directClear = function()
		return true
	end
	assert(not c.navigate(V.new(10, 3, 0), nil))
	assert(c.mode == "Direct" and #pending == 0 and c.humanoid.goal.X == 10)
	c.root.Position = V.new(9, 3, 0)
	assert(c.navigate(V.new(10, 3, 0), nil))
	assert(c.mode == "None" and c.lastCommand == nil)
end)

test("blocked target cannot be falsely marked arrived", function()
	local c = ctxNew()
	assert(not c.navigate(V.new(1, 3, 0), nil))
	assert(c.mode == "Path" and c.computing)
	flush()
	assert(c.path and not c.computing)
end)

test("path waypoints followed, forward blocked event invalidates", function()
	local c = ctxNew()
	c.navigate(V.new(12, 3, 0), nil)
	flush()
	assert(c.path)
	c.navigate(V.new(12, 3, 0), nil)
	assert(c.humanoid.goal.X == 6)
	c.root.Position = V.new(6, 3, 0)
	now = 0.4
	c.navigate(V.new(12, 3, 0), nil)
	assert(c.waypointIndex == 3 and c.humanoid.goal.X == 12)
	c.path.blockedCallback(2)
	assert(not c.blocked)
	c.path.blockedCallback(3)
	assert(c.blocked)

	local old = c.path
	c.navigate(V.new(12, 3, 0), nil)
	assert(old.destroyed and c.computing)
end)

test("cancellation invalidates suspended request", function()
	local c = ctxNew()
	pauseCompute = true
	c.navigate(V.new(20, 3, 0), nil)
	flush()
	local old = plans[1]
	c.resetMovement()
	assert(old.destroyed and not c.computing)
	pauseCompute = false
	c.navigate(V.new(30, 3, 0), nil)
	flush()
	assert(c.path and c.path.goal.X == 30 and not c.computing)
end)

test("path timeout is bounded and releases worker", function()
	local c, a = ctxNew()
	pauseCompute = true
	c.navigate(V.new(20, 3, 0), nil)
	flush()
	now = S.PathTimeout + 0.1
	c.checkPathTimeout(now)
	assert(not c.computing and plans[1].destroyed and a.AI_PathStatus == "TimedOut")
	assert(c.nextPath > now)
end)

test("fallback keeps actual endpoint and rotates on completion", function()
	local c, a = ctxNew()
	planMode = "NoPath"
	local goal = V.new(20, 3, 0)
	c.navigate(goal, nil)
	flush()
	assert(c.failedPaths == 1 and a.AI_PathStatus == "NoPath")
	now = c.nextPath + 0.1
	planMode = "Success"
	c.navigate(goal, nil)
	flush()
	assert(c.routeFallback and c.routeDestination.X ~= goal.X and c.failedPaths == 1)

	local endpoint = c.routeDestination
	c.root.Position = endpoint
	c.waypointIndex = #c.waypoints
	now = now + 1
	c.navigate(goal, nil)
	assert(not c.path and c.failedPaths == 2 and a.AI_PathStatus == "FallbackReached")
	assert(c.nextPath >= now + S.FallbackRetry and not c.computing)
end)

test("recovery runs during pending path and owns escape", function()
	local c, a = ctxNew()
	local goal = V.new(20, 3, 0)
	c.directClear = function(pos)
		return pos.X < 0 or math.abs(pos.Z) > 2
	end
	pauseCompute = true
	c.navigate(goal, nil)
	flush()
	now = S.NoRouteTimeout + 0.1
	c.monitorProgress()
	assert(a.AI_RecoveryActive and c.lastCommand and c.lastCommand.X < 0 and not c.computing)

	local escape = c.lastCommand
	now = now + 0.1
	c.navigate(goal, nil)
	assert(c.lastCommand == escape and not c.computing)
	c.root.Position = escape
	now = now + 0.1
	pauseCompute = false
	c.navigate(goal, nil)
	flush()
	assert(not a.AI_RecoveryActive)
end)

test("recovery executes during no-path retry cooldown", function()
	local c, a = ctxNew()
	c.mode = "Path"
	c.navigationGoal = V.new(20, 3, 0)
	c.nextPath = 100
	c.directClear = function(pos)
		return pos.X < 0
	end
	now = S.NoRouteTimeout + 0.1
	c.monitorProgress()
	assert(a.AI_RecoveryActive and c.lastCommand.X < 0)
end)

test("moving route accepts safe forward join rather than stale second waypoint", function()
	local c = ctxNew()
	c.mode = "Path"
	c.directClear = function(goal)
		return goal.X >= c.root.Position.X
	end
	local path = service:CreatePath()
	path.start = V.new(0, 3, 0)
	path.goal = V.new(18, 3, 0)

	c.root.Position = V.new(10, 3, 0)
	assert(c.acceptRoute(path, path:GetWaypoints(), path.goal, path.goal, path.start, nil, false))
	assert(c.waypointIndex == 3)
end)

test("jump delegated to movement and not repeated at same waypoint", function()
	local c = ctxNew()
	c.mode = "Path"
	local path = service:CreatePath()
	path.start = V.new(0, 3, 0)
	path.goal = V.new(12, 3, 0)
	local pts = path:GetWaypoints()
	pts[2].Action = "Jump"
	c.acceptRoute(path, pts, path.goal, path.goal, path.start, nil, false)
	local jumps = 0
	c.jump = function()
		jumps = jumps + 1
		return true
	end
	c.followPath()
	c.followPath()
	assert(jumps == 1 and c.lastJumpIndex == 2)
end)

local function characterAt(x, z)
	local root = {
		Position = V.new(x, 3, z),
		AssemblyLinearVelocity = V.zero,
		CollisionGroup = "Default",
		IsA = function(_, k)
			return k == "BasePart"
		end,
		CFrame = { LookVector = V.new(1, 0, 0) },
	}
	local human = {
		Health = 100,
		Sit = false,
		PlatformStand = false,
		state = "Running",
		GetState = function(self)
			return self.state
		end,
	}
	local char = {
		Parent = true,
		root = root,
		human = human,
		FindFirstChild = function(self, k)
			if k == "HumanoidRootPart" then
				return self.root
			end
		end,
		FindFirstChildWhichIsA = function(self)
			return self.human
		end,
	}
	return char, root, human
end

test("hearing through a wall is separate from vision", function()
	local npc = characterAt(0, 0)
	local char, root = characterAt(20, 0)
	root.AssemblyLinearVelocity = V.new(16, 0, 0)
	world.hit = { Instance = {
		IsA = function()
			return true
		end,
		Transparency = 0,
		GetAttribute = function()
			return nil
		end,
	} }

	local per = require("Perception")
	local heard, position = per.CanHear(npc, char)
	assert(heard and position.X == 20 and not per.CanSee(npc, char))
	world.hit = nil
end)

test("hearing remembers fixed sound after player stops", function()
	local npc = characterAt(0, 0)
	local char, root = characterAt(10, 0)
	root.AssemblyLinearVelocity = V.new(16, 0, 0)
	local h = require("Hearing")
	assert(h.Get(npc, char))
	root.AssemblyLinearVelocity = V.zero

	now = 0.5
	local heard, position = h.Get(npc, char)
	assert(heard and position.X == 10)
	now = 2
	assert(not h.Get(npc, char))
end)

test("vision cone, transparent visual geometry and rear rejection", function()
	local npc = characterAt(0, 0)
	local front = characterAt(10, 0)
	local rear = characterAt(-10, 0)
	local per = require("Perception")
	world.hit = nil
	assert(per.CanSee(npc, front) and not per.CanSee(npc, rear))
	local opaque = {
		IsA = function()
			return true
		end,
		Transparency = 0,
		GetAttribute = function()
			return nil
		end,
	}

	world.hit = { Instance = opaque }
	assert(not per.CanSee(npc, front))
	opaque.Transparency = 1
	assert(per.CanSee(npc, front))
	world.hit = nil
end)

local function brainNew()
	local c, a = ctxNew()
	local char, r, h = characterAt(12, 0)
	local player = { Parent = players, Character = char, UserId = 1 }
	c.target = player
	c.lockedCharacter = char
	c.confirmedTarget = true
	c.attackUntil = 0
	c.Config = require("Configuration")
	c.Perception = {
		CanSee = function()
			return false
		end,
		CanHear = function()
			return false, nil
		end,
		Scan = function()
			return nil
		end,
	}
	c.TargetMemory = {
		Remember = function() end,
		IsValid = function()
			return false
		end,
	}
	c.memory = {}
	c.getCharacter = function(p)
		if p and p.Character and p.Character.root and p.Character.human.Health > 0 then
			return p.Character, p.Character.human, p.Character.root
		end
	end
	c.setAggro = function(p)
		c.aggroPlayer = p
	end
	c.setState = function(s)
		c.state = s
	end
	c.forgetTarget = function()
		c.target = nil
		c.confirmedTarget = false
		c.lockedCharacter = nil
	end
	c.cancelBreach = function() end
	c.updateBreachTraversal = function()
		return false
	end
	c.beginBreach = function()
		return false
	end
	c.obstacle = function()
		return {}
	end
	c.navigate = function(goal)
		c.chaseGoal = goal
		return false
	end
	c.monitorProgress = function() end
	c.cancelRoomSearch = function() end
	c.updateWandering = function() end
	c.attack = function()
		error("Unexpected attack")
	end
	require("Behavior")(c)
	return c, player, char, r, h, a
end

test("confirmed chase continues without vision or hearing", function()
	local c, p, char, r = brainNew()
	c.update()
	assert(c.confirmedTarget and c.target == p and c.chaseGoal == r.Position)
end)

test("temporary missing root does not release target", function()
	local c, p, char, r = brainNew()
	char.root = nil
	c.update()
	assert(c.confirmedTarget and c.targetWaiting)
	char.root = r
	c.update()
	assert(c.confirmedTarget and not c.targetWaiting and c.chaseGoal == r.Position)
end)

test("confirmed death and respawn release target", function()
	local c, p, char, r, h = brainNew()
	h.Health = 0
	c.update()
	assert(not c.confirmedTarget)
	c, p, char, r, h = brainNew()
	p.Character = characterAt(20, 0)
	c.update()
	assert(not c.confirmedTarget)
end)

test("hearing investigation never activates aggression or breach", function()
	local c, p, char, r = brainNew()
	c.confirmedTarget = false
	c.target = nil
	c.lockedCharacter = nil
	c.Perception.Scan = function()
		return { Player = p, Visible = false, Heard = true, Position = V.new(12, 3, 0) }
	end
	c.acquire = function(player)
		c.target = player
	end
	c.TargetMemory.Remember = function(m, _, pos)
		m.Position = pos
	end
	c.TargetMemory.IsValid = function()
		return true
	end
	c.beginBreach = function()
		error("Sound must not breach")
	end
	c.update()
	assert(c.target == p and not c.confirmedTarget and c.aggroPlayer == nil and c.state == "Investigating")

	local first = c.memory.Position
	c.Perception.Scan = function()
		return { Player = p, Visible = false, Heard = true, Position = V.new(30, 3, 0) }
	end
	c.update()
	assert(c.memory.Position == first and c.chaseGoal == first)
end)

test("wall crossing shortens exit when the next solid wall is near", function()
	local c, a = ctxNew()
	c.confirmedTarget = true
	c.lockedCharacter = {}
	c.root.Position = V.new(1.2, 3, 0)
	c.setState = function(state)
		c.state = state
	end

	local wall = {
		Parent = true,
		Size = V.new(2, 10, 20),
		CFrame = {
			PointToObjectSpace = function(_, pos)
				return pos - V.new(6, 3, 0)
			end,
			VectorToObjectSpace = function(_, v)
				return v
			end,
		},
	}

	local hit = { Instance = wall, Position = V.new(5, 3, 0) }
	c.isBreakable = function(w)
		return w == wall and w.Parent
	end
	c.shatter = function(w)
		w.Parent = nil
		return true
	end
	c.obstacle = function()
		if wall.Parent then
			return hit
		end
	end
	c.directClear = function(pos)
		return pos.X <= 8.7
	end
	require("Breaching")(c)
	assert(c.beginBreach(hit, c.lockedCharacter))
	assert(c.mode == "Breach")
	assert(c.updateBreach())
	now = S.BreakWindup + 0.1
	assert(c.updateBreach())
	assert(not wall.Parent and a.AI_BreachTraversing and c.breachExitPoint.X > 7 and c.breachExitPoint.X <= 8.7)
	c.root.Position = V.new(7.8, 3, 0)
	now = now + 0.1
	assert(not c.updateBreachTraversal() and not a.AI_BreachTraversing and c.confirmedTarget)
end)

test("breaching is prohibited before visual confirmation", function()
	local c = ctxNew()
	c.confirmedTarget = false
	c.isBreakable = function()
		error("Must not evaluate a wall when unconfirmed")
	end
	require("Breaching")(c)
	assert(not c.beginBreach({ Instance = {} }, nil))
end)
test("failed crossing returns to chase without unlocking target", function()
	local c, a = ctxNew()
	c.confirmedTarget = true
	c.lockedCharacter = {}
	c.root.Position = V.new(1.2, 3, 0)
	c.setState = function(state)
		c.state = state
	end

	local wall = {
		Parent = true,
		Size = V.new(2, 10, 20),
		CFrame = {
			PointToObjectSpace = function(_, pos)
				return pos - V.new(6, 3, 0)
			end,
			VectorToObjectSpace = function(_, v)
				return v
			end,
		},
	}
	local hit = { Instance = wall, Position = V.new(5, 3, 0) }

	c.isBreakable = function(w)
		return w.Parent
	end
	c.shatter = function(w)
		w.Parent = nil
		return true
	end
	c.obstacle = function()
		return hit
	end
	c.directClear = function()
		return false
	end
	require("Breaching")(c)
	assert(c.beginBreach(hit, nil))
	assert(c.updateBreach())
	now = S.BreakWindup + 0.1
	assert(not c.updateBreach() and c.confirmedTarget and not a.AI_BreachTraversing and c.mode == "None")
end)

test("movement refresh and steering handoff", function()
	local c = ctxNew()
	local g = V.new(10, 3, 0)
	c.move(g)
	assert(c.humanoid.commands == 1)
	now = 0.1
	c.move(g)
	assert(c.humanoid.commands == 1)
	now = S.MovementRefresh + 0.1
	c.move(g)
	assert(c.humanoid.commands == 2)
	c.steer(g)
	assert(c.commandKind == "Steer")
	c.move(g)
	assert(c.commandKind == "MoveTo" and c.humanoid.commands == 3)
end)

test("visual confirmation requires sustained sight and cannot switch locked player", function()
	local c, p, char, r = brainNew()
	c.target = nil
	c.confirmedTarget = false
	c.lockedCharacter = nil
	c.acquire = function(player)
		c.target = player
	end
	c.Perception.Scan = function()
		return { Player = p, Visible = true, Heard = false, Position = r.Position }
	end
	c.Perception.CanSee = function()
		return true
	end
	c.Prediction = {
		GetPosition = function(_, target)
			return target.Position
		end,
	}
	c.update()
	assert(not c.confirmedTarget and c.visualCandidate == p)
	now = c.Config.VisualConfirmTime / 2
	c.update()
	assert(not c.confirmedTarget)
	now = c.Config.VisualConfirmTime + 0.01
	c.update()
	assert(c.confirmedTarget and c.target == p and c.aggroPlayer == p)
	c.Perception.Scan = function()
		error("Must not scan for new targets while locked")
	end
	c.Perception.CanSee = function()
		return false
	end
	c.update()
	assert(c.target == p and c.confirmedTarget)
end)

test("trusted server sound event is audible without movement", function()
	local npc = characterAt(0, 0)
	local char, root = characterAt(12, 0)
	local hearing = require("Hearing")
	hearing.Emit(char, root.Position, 25)
	local heard, pos = hearing.Get(npc, char)
	assert(heard and pos.X == 12)
end)

test("moving platform does not generate stationary footstep noise", function()
	local npc = characterAt(0, 0)
	local char, root = characterAt(10, 0)
	root.AssemblyLinearVelocity = V.new(16, 0, 0)
	world.floorHit = { Instance = {
		IsA = function()
			return true
		end,
		AssemblyLinearVelocity = V.new(16, 0, 0),
	} }

	local hearing = require("Hearing")
	assert(not hearing.Get(npc, char))
	now = 0.2
	root.Position = V.new(13.2, 3, 0)
	assert(not hearing.Get(npc, char))
	world.floorHit = nil
end)

print(
	("All %d regression scenarios passed. Roblox API calls were mocked; no physics or engine validation."):format(total)
)
