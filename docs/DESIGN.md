# Business as Usual — design notes (Prototype 001)

## Pillars
1. **People, not computers.** The ERP is only the stage. Every problem in Day 1 is caused by a
   person: a vague client, an overloaded consultant, a literal-minded developer, a deprecation
   nobody owns, and a manager who turns a colour change into a strategy.
2. **Serious simulation, fun to play.** The real workflow (request → analysis → spec → build →
   test → UAT → release → consequences) is represented as small, readable decisions, not chores.
3. **You can do everything right and it still goes sideways.** The disaster happens even with
   a perfect spec. Your choices change *how* it goes wrong, who gets blamed, and your review.

## Day 1 beat sheet
| Beat | Joke engine | Player agency |
|---|---|---|
| Arrival & badge says VISITOR | bureaucracy | 3 replies to Maggie |
| Meet Tobias / Sanne / Bogdan | character intros, running gags (Henrik, "not the network") | order, password choice |
| Meeting about meetings, SYNERGIA | buzzwords, awkward silence | "replace management?" |
| URGENT email with no content | observational | how to reply to Gerald |
| Dagmar knows everything | knowledge ≠ seniority | what you ask |
| Handover builder | "developers build exactly what you write" | which notes become the spec |
| ERP test environment | nobody reads the warnings | test thoroughly? flag FloorLink? |
| Deploy button with safety cover | Monday afternoon release | — |
| Cake → escalation phone → video call | escalating absurdity | — |
| Biscuit avalanche | visual comedy payoff | — |
| War-room blame game → dust-cloud brawl | situational and slapstick comedy | stop / fetch Maggie / take minutes |
| Cake ends the fight | the Feel-Good Manager is the real power | — |
| Twist: record production, Gerald takes credit, Chad invoices SYNERGIA | dark corporate irony | — |
| Final email: "make DELETE green too" | the cycle begins again | — |
| Performance review | consequences and progression | replay for other branches |

## Running gags (for future days)
Henrik on Tobias's headset · "It's not the network" · Chad's buzzword of the week · Maggie's
multi-purpose cakes · Gerald's tablet signature · the rubber duck "Senior Solution Architect" ·
Olu's missing Gantt chart · Kevin's rounding error · FloorLink and the cheese-making author.

## Systems that are ready to grow
- **Data-driven dialogue** with flags, stats, events, conditional lines and nested choices.
- **Stage-aware flavour**: `chat_<id>_<stage>` / `flavor_<id>_<stage>` keys.
- **Escalation phone** levels 0–3 (calm → buzzing → hot → embers).
- **Work panels** are reusable templates for other careers (infrastructure: deploy/rollback;
  sales: proposal builder; PM: steering-committee slide that must look green).
- **In-world screens** can render any chart or slide, so the war room can show live project data.

## Suggested next steps
1. First launch in Godot 4.3+: fix any runtime typos, tune lighting and camera.
2. Bundle a licensed display font, and add the licensed music.
3. Replace the procedural people with sculpted or rigged models that keep the same face system
   (expressions, mouth flaps, gestures).
4. Day 2, "The Steering Committee": a status meeting where the dashboard must stay green.
5. Danish, Flemish and Belgian-French text tables (the infrastructure is already in place).
