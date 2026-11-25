# AI 1.0 — Studio release gate

Run in a disposable copy of the place. These are required acceptance tests, not
results from the offline harness. Keep a copy of server Output and the Noob
attributes when something fails. Test both Start Server with two players and solo Play.

## Setup
- Standard R6 Noob, unanchored, alive, root collision disabled, no other movement authority.
- Flat anchored floor (e.g. 200 × 1 × 200), clear central area.
- Solid wall: anchored Part, e.g. 2 × 12 × 24 studs; do not tag it.
- Breakable wall: same geometry, tag `Breakable` with Tag Editor; set `Breakable=true` if desired.
- Leave at least 6 studs of free corridor around wall ends. Also add a separate narrow/blocked area to exercise failure handling.
- Enable Studio navigation-mesh visualization. Ensure test routes exist. Reset the place between independent tests, since walls are destroyed permanently.

| # | Scenario | Pass condition |
|---|---|---|
| 1 | Start with no visible/noisy players | AI_Version=1.0; NPC alternates Idle/Wandering, no red errors |
| 2 | Stand behind NPC without moving | No visual lock or shake |
| 3 | Run behind an opaque solid wall within ~25 studs | AI_CanHear becomes true, investigates fixed location, no aggro or destruction |
| 4 | Stop behind wall and move silently away | NPC continues to original sound location, searches, then returns to wandering |
| 5 | Jump behind wall within hearing range | Sound event detected without visual confirmation |
| 6 | Stand 10 studs in front for >0.3 seconds | AI_ConfirmedTarget=true, AI_State=Chasing, correct user ID |
| 7 | Run out of vision and hearing range | Confirmed target and ID remain locked; no target swap |
| 8 | Run around solid wall | NPC follows path around wall, no destruction |
| 9 | Block active path with new anchored obstacle | Route rebuilt; blockage ahead handled; recovery may move away |
| 10 | Target in completely sealed room | Bounded retries/escape attempts, no script crash and no lock loss |
| 11 | Reopen sealed-room exit | NPC eventually resumes pursuit if navmesh offers a route |
| 12 | Hide behind tagged breakable wall after visual lock | Wall shatters, fragments fall on floor, NPC ignores fragments and crosses |
| 13 | Place another wall close beyond breakable wall | NPC selects shorter safe crossing or replans; no collision bypass |
| 14 | Rotate breakable wall 30–45 degrees | Correct breach approach and exit; no wall tunneling |
| 15 | Run through several breakable walls | Physical fragment budget ≤192; old debris cleaned; no persistent obstruction |
| 16 | Stand on stairs / climb accessible ramp | NPC follows valid path, retains target |
| 17 | Force a temporary missing target root in test place | Lock retained; pursuit resumes once same character root is restored |
| 18 | Let NPC attack | Only locked living character takes punch/knockback and delayed death |
| 19 | Target dies or respawns | Aggro clears, effects stop, returns to roaming after attack cooldown |
| 20 | Two players; another player is closer | Locked player remains target; other client gets no camera/red effects |
| 21 | Locked player moves from 45 studs toward 3 studs | Shake/red intensity increases smoothly; fades with distance; FOV unchanged |
| 22 | Set ReduceCameraShake=true on player | Camera shake immediately stops; no accumulated offset |
| 23 | NPC dies/Controller.Stop() called | Movement, path requests and aggro stop; no leftover effects |
| 24 | Long soak (at least 15 minutes) | No recurring errors, runaway fragment growth, repeated unnecessary path resets or sustained frame/physics degradation |

## If a freeze occurs
Record whether the NPC is physically moving, its target's position, and map geometry.
Inspect AI_State, AI_Mode, AI_ConfirmedTarget, AI_PathStatus, AI_ComputingPath,
AI_RecoveryActive, AI_RecoveryAttempts, AI_NavigationStuckTime, AI_MoveGoal,
AI_ActualSpeed, AI_WalkSpeed, AI_RouteDestination, AI_LastDecision and error attributes.
A `NoPath` in enclosed geometry is expected; repeated `NoPath` on a verified open
route is not. A `Faulted` state is a release-blocking error: collect the traceback.

## Release decision
Ship only after all applicable scenarios pass with the actual map, rig, network
conditions and camera scripts. Run Studio Script Analysis and Luau type checking
where available. Profile physics and server script time with multiple players.
If you tune configuration or modify modules, repeat offline checks and relevant
Studio cases. The included test results are not certification of the live game.

## Advanced room-search patch (additional cases)
- Emit a sound inside a room with an accessible doorway; verify the NPC can enter and search without aggression or destruction until visual confirmation.
- Repeat with a sealed room; verify no clipping or sound-only breach, and eventual search expiry.
- Confirm a target during an active search route; verify search cancellation and pursuit takeover.
- Block a search route dynamically; verify bounded retries and eventual expiry.
