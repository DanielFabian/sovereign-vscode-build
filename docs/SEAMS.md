# Cursed Seams Catalog

Working doc for Phase 1 of mission `01KQZSBNGZ01DZ2X593RX44WTX`.
Per-seam: source location → hiding mechanism → smallest-fix sketch →
principle classification → sibling-pattern notes → open questions.

The three principles this fork operates on:

1. **Honesty / observability** — the editor must stop hiding behavior:
   settings hidden behind magic keys, models silently downgraded,
   request streams only available via debug commands with popup races,
   context assembly opaque to observers. *Justifies what we patch.*
2. **Right division of labor** — build deterministic infrastructure
   that prevents the AI from being asked to do things AI is bad at.
   Don't ask AI to remember things via post-it notes; give it
   structured retrieval. Don't ask AI to introspect or lie about
   itself; have the runtime tell the truth. *Justifies how we patch.*
3. **Fix-it-yourself agency** — when upstream ships something cursed
   (a quadratic `tokenize(concat(chunks))` recomputation per
   keystroke; one-line PRs taking months to merge — see
   microsoft/vscode-copilot-chat#2211), we have a shipping channel
   that doesn't depend on convincing them. *Justifies the existence
   of the fork as a long-term project.* Principles 1 and 2 justify
   individual patches; principle 3 justifies the maintenance burden
   of the fork itself.

Anchor patches investigated in this order (cheapest-first):
1. Hidden settings (this doc) — *done*
2. soverbrain-exporter event API (debug-command screen-scraping) — *done*
3. Subagent model honesty — *done*
4. Timestamps in context assembly (Sasha already has a branch:
   <https://github.com/eodus/vscode-copilot-chat/tree/custom/time-injection>) — *done*
5. File-edit policy ("can't touch package.json") — *done*
6. ExP treatment visibility (extracted from Seam 3 investigation) — *scoped*

---

## Seam 1 — Hidden settings (Copilot extension)

**Status:** investigated 2026-05-07. Sub-mechanism A is fixed at the user level
(toggled in Daniel's user settings, travels with the install). Sub-mechanism B
is the actually-cursed one.

### What we found

The Copilot extension exposes `558` configuration keys via `package.json`
schema and defines `190` keys via `defineSetting()` in code. There are **two
distinct hiding mechanisms**, of unequal severity.

#### Sub-mechanism A — `tags: ["advanced"]` in schema

87 of 93 `tags:["advanced"]` settings live in the Copilot extension —
"EXACTLY the things we want to know about" (Daniel's words, and confirmed
by sampling: `omitBaseAgentInstructions`, `agentHistorySummarizationMode`,
`useResponsesApiTruncation`, `tools.defaultToolsGrouped`, …).

**Gate:** [`settingsEditor2.ts:351-379`](../../vscode/src/vs/workbench/contrib/preferences/browser/settingsEditor2.ts) — `canShowAdvancedSettings()` /
`shouldShowSetting()`. A setting tagged `advanced` is filtered out unless
**any** of:

1. `workbench.settings.alwaysShowAdvancedSettings = true` (a normal,
   visible setting)
2. User explicitly types `@tag:advanced` in the search bar
3. User types `@id:<exact-key>`
4. The search query contains the setting's key as a substring

The `experimental` tag (117 settings) is cosmetic — it adds a warning badge
([`settingsEditorSettingIndicators.ts:307,552`](../../vscode/src/vs/workbench/contrib/preferences/browser/settingsEditorSettingIndicators.ts)) but does **not** hide.
`onExp` (69) and `preview` (5) likewise don't hide. `included: false` is
**not used** anywhere in `vscode/extensions/copilot/package.json`. No
`when:` clauses on configurations.

**Smallest fix:** flip `workbench.settings.alwaysShowAdvancedSettings` to
`true`. One toggle exposes all 87. Already done by Daniel at user-config
level; could optionally be baked as a sovereign default in
`product.json` / overlay if we ever care about new users.

**Bonus typo bug spotted:** 6 settings in `vscode/extensions/copilot/package.json`
use `"onExP"` (capital P) instead of `"onExp"`. Whatever consumes the ExP
treatment tag won't match these. Side-quest, not in scope.

#### Sub-mechanism B — code-only settings (no schema entry)

**16 settings are defined via `defineSetting()` in
[`vscode/extensions/copilot/src/platform/configuration/common/configurationService.ts`](../../vscode/extensions/copilot/src/platform/configuration/common/configurationService.ts)
but have NO entry in `package.json` `contributes.configuration`.**

These are *strictly* more hidden than `tags:["advanced"]`:

- Toggling `alwaysShowAdvancedSettings` does **not** reveal them — the
  Settings UI never knew they existed.
- No autocomplete in `settings.json` (no JSON schema).
- No description, no type validation, no UI widget.
- Only way to set them: hand-edit `settings.json` knowing the exact key.

The 16 (key suffixes; full key is `github.copilot.<suffix>`):

```
advanced.authPermissions
advanced.authProvider
advanced.debug.overrideCapiUrl
advanced.debug.overrideProxyUrl
advanced.debug.useElectronFetcher
advanced.debug.useNodeFetchFetcher
advanced.debug.useNodeFetcher
chat.advanced.enableAskAgent
chat.advanced.enableFallbackNodeFetchOnNetworkProcessCrash
chat.advanced.enableReadFileV2
chat.advanced.enableRetryNetworkErrors
chat.advanced.retryServerErrorStatusCodes
chat.azureAuthType
chat.byok.ollamaEndpoint
chat.debug.githubAuthFailWith
chat.planAgent.model
```

Most are debug/networking knobs. AI-orchestration relevant in this list:

- **`chat.planAgent.model`** — override the plan agent's model. Direct
  model-honesty surface.
- **`chat.byok.ollamaEndpoint`** — bring-your-own-key plumbing.
- **`chat.advanced.enableAskAgent`** / **`chat.advanced.enableReadFileV2`** —
  feature gates that change agent behavior.

**Smallest fix sketches** (pick one):

1. *Debug-dump command* (cheapest): patch the Copilot extension to register
   a command like `github.copilot.debug.dumpAllKnownSettings` that walks
   the `ConfigKey` namespace and prints `{key, defaultValue, currentValue,
   inSchema}` to a notebook or output channel. Doesn't change the editor's
   gating; just makes the universe of keys discoverable.
2. *Auto-contribute schema* (more honest): build-time check that every
   `defineSetting()` call has a matching `package.json` schema entry (with
   at least `type` + auto-generated description). Failing the build on
   mismatch makes hiding a deliberate act, not an accident of omission.
3. *Sovereign-side mirror schema* (no upstream churn): generate the schema
   from `defineSetting()` calls at sovereign-build time and inject it as
   an additions overlay. Same effect as #2 without modifying upstream
   files.

### Classification

Pure **principle-1 (honesty/observability)**. No principle-2 dividend —
this is just "the UI lies about what knobs exist". Doesn't off-load any
work from AI judgment.

### Sibling pattern

The pattern is **schema-vs-implementation drift**: when there are two
sources of truth (TypeScript `defineSetting` and `package.json` schema),
the implementation always wins at runtime, but only the schema feeds the
UI. The drift hides the delta.

**Hypothesis to check later:** the same shape probably exists for
*commands* — commands registered in code that aren't contributed to
`package.json` won't appear in the Command Palette. Worth a quick check
when we look at the exporter seam (which is itself a debug command).

### Open questions

- Does flipping `alwaysShowAdvancedSettings` cause downstream UI noise
  bad enough to dissuade new users? (Daniel: experiment in own profile,
  decide later.)
- Are any of the 16 code-only settings actually tested-against by
  Copilot's CI, or are they vestigial? (Cheap to check via `rg` for
  ConfigKey usage; deferred.)
- Same audit for the *vscode core* extensions (not just Copilot)? Would
  expand the picture from "MS hides Copilot internals" to "MS hides editor
  internals". Lower-priority because anchor patches are AI-focused.

---

## Seam 2 — soverbrain-exporter event API

**Status:** investigated 2026-05-07.

### What we found

The current exporter polls `github.copilot.chat.debug.exportAllPromptLogsAsJson`
every 5 seconds, races a 10s timeout against a (sometimes-suppressed) popup,
reads back the JSON file, and diffs against a `seenRequestIds` set to detect
new entries. This is a worked example of principle-2 *infrastructure-debt*:
the AI/extension does work (polling, diffing, racing, file round-trips) that
should be done deterministically by listening to an event.

**The event source already exists in the Copilot extension's DI graph.**
It's [`IRequestLogger`](../../vscode/extensions/copilot/src/platform/requestLogger/common/requestLogger.ts) and its full API is exactly what we need:

```ts
interface IRequestLogger {
    onDidChangeRequests: Event<void>;          // fires on every append
    getRequests(): LoggedInfo[];               // full log, in order
    getRequestById(id: string): LoggedInfo | undefined;
    addEntry(entry: LoggedRequest): void;
    // … and richer producer-side methods used by Copilot internally
}
```

The debug command at
[`requestLogTree.ts:415`](../../vscode/extensions/copilot/src/extension/log/vscode-node/requestLogTree.ts)
is essentially a serializer-on-demand over `chatRequestProvider.getChildren()`,
which itself wraps `requestLogger.getRequests()`. Same data, same shape — but
walled inside Copilot's extension boundary and unreachable from other
extensions except via this debug command.

### Why the current setup hurts

Concretely, what soverbrain-exporter pays for the missing API:

1. **Polling** — `DEFAULT_POLL_INTERVAL_MS = 5000` in `recorder.ts:11`. Up
   to 5s of latency on every event; load on every poll regardless of
   whether anything happened.
2. **Whole-tree re-serialization** — every poll re-serializes *all* prompts
   ever logged in the session, then `seenRequestIds` filters out the
   already-known ones. O(n²) on session length.
3. **Popup race** — `replay.ts:36-44` races a 10s timeout because the
   upstream command sometimes shows a popup that awaits user click. The
   `if (!savePath)` branch in `requestLogTree.ts:487` *does* suppress the
   success popup when called programmatically with a path, but the
   exporter still races as a defensive measure (and there are other
   popups elsewhere in the export path: `showSaveDialog`, `showErrorMessage`,
   reveal/open actions).
4. **File round-trip** — write JSON to disk, read back, parse. Pure
   ceremony; the data was just in memory on the other side of the
   extension boundary.
5. **Vestigial command reference** — exporter calls a second command
   `github.copilot.chat.debug.exportTrajectories` (`replay.ts:6`) which
   *does not exist anywhere in the current upstream tree*. The
   `availableCommands.includes` check silently routes around it. Likely
   a leftover from an earlier upstream API that was removed; means
   trajectory export is currently dead code on our side. (Side-quest:
   confirm what trajectories *were* and whether we want them back.)

### Smallest fix sketch

The seam is so clean it's almost embarrassing. Two layers:

**Layer 1 — surface the event** (principle-1, ~50-line patch):
add a vscode-proposed-API namespace (or a fresh extension-to-extension
contract via an exported activation API) that exposes a subset of
`IRequestLogger` to other extensions:

```ts
namespace github.copilotChat.requestLog {
    export const onDidLogRequest: Event<LoggedInfo>;
    export function getRequests(): readonly LoggedInfo[];
}
```

The event payload shape is already a stable internal type (`LoggedInfo`
discriminated union: `Request | Element | ToolCall`). Filtering by
`COMPLETED_REQUEST_TYPES` like the exporter does today becomes a one-line
predicate on the consumer side.

**Layer 2 — replace the exporter's recorder loop** (principle-2,
exporter-side rewrite):
swap `setInterval(poll, 5000)` for `requestLog.onDidLogRequest(entry =>
spool(entry))`. Drops `seenRequestIds`, `pollInFlight`, the popup race,
the temp-file round-trip, and the whole-tree re-serialization. Recorder
becomes a thin transformer: `LoggedInfo` → CAS bundle → spool.

The two layers are independent: Layer 1 is upstream-style patch
(touches `vscode/extensions/copilot/`); Layer 2 is purely soverbrain-side
once Layer 1 lands.

### Classification

**Both principles, composed.** The patch is principle-1 (expose the
hidden event), but its *purpose* is enabling principle-2 (move
poll+diff+race work off the AI/extension onto a deterministic event
subscription). This composition is itself a recurring shape: principle-1
patches often justify themselves as enablers for principle-2 dividends
elsewhere. Worth flagging when we see it again.

### Sibling-pattern notes

The "real API hiding behind a debug command" pattern is the one to
pattern-hunt. Other commands in the `github.copilot.chat.debug.*`
namespace are candidate sites:

```
$ rg -n '"command":\s*"github\.copilot\.chat\.debug\.' vscode/extensions/copilot/package.json
```

Quick scan of `requestLogTree.ts` shows several siblings registered in
the same file: `exportPromptArchive`, `exportPromptLogsAsJson` (single
prompt), `showRawRequestBody`. All read from the same `IRequestLogger`.
Each is a "real API was here, we hid it behind a tree-view command"
instance. Once Layer 1 is in place, all of them become trivially
implementable on the consumer side.

Bigger sibling pattern: **schema-vs-implementation drift**, already
named in Seam 1. Here the drift is between *what the extension knows
internally* (full structured event stream) and *what it exposes
externally* (a one-shot file-dump command driven by a TreeView). Same
shape: implementation has more truth than the published surface.

### Open questions

- Is there any reason `IRequestLogger.onDidChangeRequests` fires `void`
  instead of the new `LoggedInfo`? Probably just because the consumer
  is a TreeView that needs a full re-render anyway. For a real event
  API we'd want `Event<LoggedInfo>` (the new entry) plus `getRequests()`
  for warm-start. Cheap upstream change to refactor; or sovereign-side,
  fire `Event<LoggedInfo>` from `addEntry` directly without changing
  the existing `onDidChangeRequests` consumers.
- What's the right extensibility shape — vscode-proposed API
  namespace, exported extension activation API, or something else?
  Defer until Seam 3 informs the privilege-surface picture (extension
  exports work between any two extensions; proposed APIs require
  privileged-extension status).
- What was `exportTrajectories`? Find in upstream history; decide
  whether to revive or remove the dead exporter call.

---


## Seam 3 — subagent model honesty

**Status:** investigated 2026-05-07. *This section was rewritten from
scratch after two earlier framings (an in-place "three concentric layers"
and a corrected-but-still-wrong "Stack A vs Stack B") were both falsified.
The rewrites traced to a recurring failure mode — asserting a categorical
property of the system from a single non-falsifying check — which is now
covered by the falsifier-check rule in our epistemic-honesty protocol.
Catalog discipline lesson: when in doubt, verify the topology before
naming layers, and broaden grep patterns before claiming non-existence.*

### What we found

There are **three orchestration paths** in the codebase that can run a
chat turn against a model. They are *alternatives*, not nested layers,
and they live in physically separate parts of the tree.

| Path | Lives in | What spawns the model run | Settings prefix | Used in partner-ai mode? |
|---|---|---|---|---|
| **X** — panel chat | `vscode/extensions/copilot/` (most of it) | in-process JS, calls `IEndpointProvider.getChatEndpoint(request)` | `chat.*` (mixed) | **yes** — this is what we use |
| **Y** — copilotcli sessions | `vscode/extensions/copilot/src/extension/chatSessions/copilotcli/` | in-process JS, imports `@github/copilot/sdk` (a sub-export of the bundled `@github/copilot` CLI npm package) | `chat.cli.*` (16 settings) | no |
| **Z** — agentHost SDK sessions | `vscode/src/vs/platform/agentHost/node/copilot/` | spawns the `@github/copilot` CLI binary as a child process, talks to it over JSON-RPC via `@github/copilot-sdk` | distinct, `agentHost`-flavored | no |

> *Stack-topology note (verified):*
>
> - `@github/copilot` (pinned `1.0.39` in `vscode/package.json`,
>   `^1.0.39` in extension) — the CLI npm package. Bundled into VS Code
>   at build time. Subpath `./sdk` is loaded **in-process** by Path Y
>   (~20 files import from `@github/copilot/sdk`). Top-level binary
>   `bin/copilot` (`npm-loader.js`) is what the user-facing
>   `~/.vscode-server/.../copilot` shim shells out to.
> - `@github/copilot-sdk` (`^0.3.0`) — separate npm package, JSON-RPC
>   client. Used only by Path Z (~8 files in `agentHost/`). Spawns
>   the `@github/copilot` CLI as a child.
> - The CLI runtime (`app.js` ~14 MB, `sdk/index.js` ~9 MB) is bundled
>   minified JS. Not source-available
>   ([LICENSE.md](https://github.com/github/copilot-cli/blob/main/LICENSE.md)
>   — proprietary). Patchable in principle (it's JS), but neither
>   inviting nor needed for our use case.

#### Why partner-ai mode lets us ignore Y and Z

Y and Z exist to support unattended automation (a CLI session executing
plans, an agentHost session running custom agents). Partner-ai mode is
*"we both think iteratively in panel chat"* — Path X is the entire
surface we ride. Y and Z can stay broken because we don't ride them.
This collapses the seam from "fix three orchestrators" to **"fix Path X,
plus the one shared dispatcher"**.

#### Where Path X is dishonest

Two distinct dishonesty surfaces, plus one connection back to Seam 1.

##### X1 — `ProxyAgenticEndpoint` (silent downgrade in two specific tools)

Two file-local instances of the same pattern:

[`executionSubagentToolCallingLoop.ts:108-145`](../../vscode/extensions/copilot/src/extension/prompt/node/executionSubagentToolCallingLoop.ts):

```ts
private static readonly DEFAULT_AGENTIC_PROXY_MODEL = 'exec-subagent-router-a';
```

[`searchSubagentToolCallingLoop.ts:86-115`](../../vscode/extensions/copilot/src/extension/prompt/node/searchSubagentToolCallingLoop.ts):

```ts
private static readonly DEFAULT_AGENTIC_PROXY_MODEL = 'vscode-agentic-search-router-a';
```

`ProxyAgenticEndpoint` is referenced from **exactly these two files**
(verified: `rg ProxyAgenticEndpoint vscode/` gives the class definition
plus exactly two call sites). The dispatcher tool `runSubagent` does
**not** use it.

In both call sites, when `chat.<sub>.useAgenticProxy` is on, the method
constructs `new ProxyAgenticEndpoint(routerModel)` *instead of* calling
`getChatEndpoint(this.options.request)` — the request's selected model is
replaced before any routing logic runs.

Why main chat routes correctly but these don't: the rest of Path X calls
`getChatEndpoint(request)` and lets the endpoint provider use
`request.model` (the user's pick). These two `getEndpoint()` methods opt
out of that infrastructure. **The infrastructure is fine; two specific
call sites bypass it.**

The router model identifiers are hardcoded TypeScript constants — not
in any settings schema, not in any model picker. Three reinforcing hides:

1. The router-model identifier is hardcoded; no schema lists it.
2. The toggle that activates the route (`chat.<sub>.useAgenticProxy`) is
   tagged `["advanced", "experimental", "onExp"]` — invisible without
   `workbench.settings.alwaysShowAdvancedSettings`.
3. The toggle is `ConfigType.ExperimentBased` — GitHub's experimentation
   service can flip it server-side without changing the user's
   `settings.json` and without notification.

##### X2 — `runSubagent` MCP is honest, but missing knobs

The generic dispatcher
[`runSubagentTool.ts:117`](../../vscode/src/vs/workbench/contrib/chat/common/tools/builtinTools/runSubagentTool.ts)
already exposes `properties.model: { type: 'string', description: '...' }`.
The model the caller asks for is the model that runs. No proxy
involvement.

But the schema is `{prompt, description, agentName, model?}` — no
`reasoningEffort`. Adding it is a small principle-1 win: at present the
caller has no way to ask for `reasoningEffort: 'high'` without going
through hidden settings (`chat.cli.thinkingEffort.enabled` and friends,
all of which apply to Path Y, not the generic dispatcher).

##### X3 — Plan/Implement-agent model overrides hidden in Seam 1

The `AgentHandoff.model` field
([`agentTypes.ts:9`](../../vscode/extensions/copilot/src/extension/agents/vscode-node/agentTypes.ts))
is driven by:

- `chat.planAgent.defaultModel` — core schema, visible
- `github.copilot.chat.planAgent.model` — **deprecated, code-only**
  (one of the 16 hidden settings flagged in Seam 1!)
- `chat.implementAgent.model` — **code-only** (another of the 16!)

**Connection to Seam 1.** Two of the 16 "code-only no-schema" settings
identified in Seam 1 turn out to be specifically the model-override
knobs for plan/implement agent handoffs. The drift wasn't random; it
selectively hides the model controls.

### Smallest fix sketch

Three independent patches, all small. Together they make Path X honest
about model identity and give the caller real control without touching
Y or Z.

1. **Extend `runSubagent` schema with `reasoningEffort`** (vscode core,
   ~10 LOC). Add a `reasoningEffort` property to
   `runSubagentTool.getToolData()` and thread it into the existing
   `resolveSubagentModel` call. Principle-1: caller controls reasoning
   effort without needing to know any ConfigKey. *Decision deferred:*
   whether to also add `bypassBackendRouting: boolean` here, or omit
   it. Argument for omitting: the dispatcher already doesn't use the
   proxy, so the flag is a no-op today. Lean toward omit; add when
   needed.

2. **Set the proxy toggles to `false` in user settings** (zero patch).
   `chat.executionSubagent.useAgenticProxy: false` and the same for
   `searchSubagent`. **Verified 2026-05-07:** in
   [`configurationServiceImpl.ts:218-256`](../../vscode/extensions/copilot/src/platform/configuration/vscode/configurationServiceImpl.ts)
   `getExperimentBasedConfig` already short-circuits on a user-configured
   value before consulting the experimentation service. So a user value
   wins; no ExP-bypass machinery is needed for this case. Optional
   sovereign variant: change the *schema default* in the extension's
   `package.json` (~4 LOC) so new sovereign installs have the proxy off
   without per-user config.

3. **(Was: ExP opt-out)** — not needed for #2; user values already win.
   The interesting ExP-related work is *visibility* of treatments the
   user hasn't configured — promoted to its own Seam 6, see below.

The earlier "fix #4 = surface Stack-B model in chat UI" and "fix #5 =
SDK fork" are both **dropped** under partner-ai-mode framing: we don't
ride those paths.

### Classification

Pure **principle-1**. The principle-2 dividend is indirect: when the
user can see (and control) the model being used, they don't waste
context window investigating model behavior — *and* they don't have to
build mental models of which silent route a given subagent took.

X1 is plausibly the seam where the *commercial* incentive for hiding is
strongest: router-model variants are presumably cheaper-per-call than
premium models. Routing user calls to them without notification is
direct cost transfer from GitHub to user output quality. Worth flagging
because it predicts where MS would defend hardest if patches were
proposed upstream.

### Sibling-pattern notes

Three patterns instantiated here:

- **Schema-vs-implementation drift** (Seam 1): `chat.implementAgent.model`
  and `chat.planAgent.model` are literal instances of Seam 1's
  sub-mechanism B inside the Seam 3 surface. Fixing Seam 1 sub-mechanism B
  fixes part of X3.
- **Hidden allowlist / hidden denylist** (Seam 5): the router model
  identifiers (`exec-subagent-router-a`,
  `vscode-agentic-search-router-a`) are a hardcoded *allowlist* of
  internal models, baked as TypeScript constants. Same shape as
  `ALWAYS_CHECKED_EDIT_PATTERNS`.
- **Real API hiding behind a debug command** (Seam 2): the only way to
  observe X1's actual model usage today is to trigger
  `exportAllPromptLogsAsJson` and parse the JSON post-hoc.

This is the seam where we discovered that **principle-1 patches in
multiple seams compose to fix a single problem**. Seam 1B + Seam 2
Layer 1 + this seam's #1 together produce "user sees the actually-running
model in real time". None alone does.

### Open questions

- Are there other `'…-router-a'` style hardcoded model constants
  beyond the two found? Quick grep needed:
  `rg "router-[a-z]" vscode/extensions/copilot/src/`.
- Path Y has 16 `chat.cli.*` settings, of which `cli.autoModel.enabled`
  is a model-selection knob. We don't ride Y today, but if we ever do,
  this is the entry point — flag for revisit.

---

## Seam 6 — ExP treatment visibility

**Status:** scoped 2026-05-07 (extracted from Seam 3 open question).

### What we found

The Copilot extension's `IExperimentationService` is implemented by
`BaseExperimentationService` in
[`baseExperimentationService.ts`](../../vscode/extensions/copilot/src/platform/telemetry/node/baseExperimentationService.ts),
which wraps Microsoft's `vscode-tas-client` (Treatment Assignment
Service client). Treatments refresh hourly + on user-info change.

The wrapper keeps a `_previouslyReadTreatments: Map<string, value>`
cache of every treatment the code has asked about, with the value the
server returned. **This is exactly the dataset a visibility UI would
need.** Currently `private`.

Resolution priority for `ConfigType.ExperimentBased` settings
([`configurationServiceImpl.ts:218`](../../vscode/extensions/copilot/src/platform/configuration/vscode/configurationServiceImpl.ts)):

1. User-configured value at any scope (verified) — **user wins**
2. `getTreatmentVariable(key.experimentName)` if `experimentName` set
3. `getTreatmentVariable('copilotchat.config.<id>')` (legacy)
4. `getTreatmentVariable('config.<fullyQualifiedId>')` (matches `onExp` tag)
5. Old-key fallbacks
6. Default

User value wins; the cursed-ness here is **non-introspectability**, not
silent override. The user can't see what value ExP delivered for a
setting they haven't configured — and there are likely many such
settings (every `defineExpSetting` call in `configurationService.ts`).

### Smallest fix sketch (three tiers)

1. **Lo-fi** (~30 LOC). Add `getReadTreatments(): ReadonlyMap<string, value>`
   to `IExperimentationService` (one line) and `BaseExperimentationService`.
   Add a debug command `github.copilot.debug.dumpExperimentTreatments`
   that walks all `ExperimentBased` keys, queries the four ExP names
   each, and dumps `{key, expValue, userValue, defaultValue,
   effectiveValue}` to a notebook or output channel. *Self-aware note:*
   this would itself instantiate Seam 2's "real API behind a debug
   command" anti-pattern; ship knowing that, use it as the prototype
   data source for the next tier.
2. **Mid-fi**. Dedicated tree view "Copilot Experiments" in the
   Activity Bar (or a webview), built on top of the lo-fi data API.
   Per-row "set as user override" button that writes into
   `settings.json`. This is what Daniel sketched on May 7.
3. **Hi-fi**. Integrate into the Settings editor: when an
   `ExperimentBased` setting renders, add the ExP value as a third
   inspector entry alongside default and user. Requires hooking
   `vscode/src/vs/workbench/contrib/preferences/`'s setting renderers,
   so spans extension + core. Defer until lo-fi/mid-fi data confirms
   it's worth it.

### Classification

Pure **principle-1**: the data exists, the editor just doesn't show
it. No principle-2 dividend yet — would emerge if visibility changes
user behavior (e.g., "oh, ExP turned on Y for me, no wonder my plan
agent uses Haiku now").

### Sibling-pattern notes

- **Real API hiding behind a debug command** (Seam 2): the lo-fi tier
  literally instantiates this anti-pattern. Acceptable as a
  data-source prototype but not as a shipping endpoint. The mid-fi UI
  is the actual fix.
- **Schema-vs-implementation drift** (Seam 1): every `defineExpSetting`
  call in `configurationService.ts` should ideally have a paired
  schema entry that includes the `experimentName` so users can see
  *that the setting is ExP-driven* in the first place. Connection to
  Seam 1's sub-mechanism B remediation.

### Open questions

- How many `defineExpSetting` calls are there, and which have
  `experimentName` set vs. relying on auto-derived ExP names?
  Quick grep + classify.
- Does `vscode-tas-client` itself expose a list of *all* assigned
  treatments (not just the ones our code has read)? If yes, we could
  surface unknown treatments too — "ExP gave us a value for X but
  nothing in the codebase reads X". Useful for spotting upstream
  experiments before they ship.
- Workspace-vs-user-scope for the override write: probably user-scope;
  verify against existing settings-write defaults.

---

## Seam 4 — timestamps in context assembly

**Status:** investigated 2026-05-07 via Sasha's branch. Diff fetched
from <https://github.com/eodus/vscode-copilot-chat/compare/main...custom/time-injection.diff>.

### The "before"

[`agentPrompt.tsx`](../../vscode/extensions/copilot/src/extension/prompts/node/agent/agentPrompt.tsx)
contains a `CurrentDatePrompt` `PromptElement` whose entire render
function is:

```tsx
const dateStr = new Date().toLocaleDateString(undefined, {
    year: 'numeric', month: 'long', day: 'numeric'
});
// guard kept on simulation mode so cache entries don't invalidate daily
return !this.envService.isSimulation() && <>The current date is {dateStr}.</>;
```

So the model gets date-only, hardcoded format, system locale. **No time,
no weekday, no timezone, no settings hook.** The hiding mechanism is
*omission*, not gating: there is simply no knob.

### The "after" (Sasha's diff)

Three new settings under `chat.advanced.context.*`:

| Setting | Type | Default | Effect |
|---|---|---|---|
| `timeFormat` | enum `"off"`\|`"24h"`\|`"12h"` | `"off"` | Append current time |
| `showWeekday` | bool | `false` | Prepend weekday name |
| `showTimezone` | bool | `false` | Append `GMT±N` offset (only if time is on) |

All three tagged `["advanced", "experimental"]` — so they're subject to
Seam 1 sub-mechanism A (hidden until `alwaysShowAdvancedSettings`). All
opt-in by default.

The `CurrentDatePrompt` render is replaced with a call to a new
`formatCurrentDateContext(configurationService)` in
`src/extension/prompts/common/currentDateContext.ts`. Single function,
~50 lines including formatting variants. Test file covers UTC, US
Eastern (DST), Tokyo, US Pacific (PST), India (`GMT+5:30` non-whole-hour
offset), and a date-rollover-across-timezone case. Solid coverage.

Total diff: 3 new settings in `package.json` + nls strings, 1 new file
(~50 LOC), 1 new test file (~180 LOC), 5 lines changed in
`agentPrompt.tsx`, 3 settings added to `configurationService.ts`. ~280
LOC including tests; ~50 LOC functional. **Smallest concrete patch in
the catalog so far.**

The simulation guard (`!this.envService.isSimulation()`) is preserved.
Important — including current time in cached prompts would invalidate
the cache every second, breaking simulation reproducibility.

### Classification

**Principle-1 with a clean principle-2 dividend.**

- *Principle-1* (the obvious read): the model genuinely doesn't know
  what time it is. Adding time gives honest situational awareness.
  A model that only knows the date can't reason about "is it morning
  or evening?", can't judge timestamp staleness in logs, can't tell
  whether tool output is fresh or hours old.
- *Principle-2* (subtler): currently the *human* has to remember to
  inject "btw it's $time" if temporal reasoning matters. That's
  load-bearing user judgment for something deterministically
  retrievable. The patch moves that work onto deterministic infra
  (the editor) and lets the AI just *have* the information.

### Sibling-pattern notes

This seam *names* a fourth recurring pattern:

> *Recurring pattern*: **omission as hiding**. Some prompt-context
> fields aren't gated, hidden, or overridden — they're simply
> *not there*, and there's no knob. The fix shape is "add the knob
> + add the data". Cursed-ness is invisible until you compare
> what context the AI gets vs what context would let it reason.

The pattern-hunt this opens is: what other `PromptElement`s in
`vscode/extensions/copilot/src/extension/prompts/node/agent/` (and the
broader `prompts/`) hardcode their content with no settings hook?

A 60-second look at `agentPrompt.tsx` shows there's already a
`UserOSPrompt` element directly above `CurrentDatePrompt` (line 492
in the diff context) — likely a similar OS-info element. Worth
cataloging the full PromptElement inventory, classifying each by:

- (a) configurable / not configurable
- (b) simulation-cached / not cached
- (c) potentially-stale / fresh
- (d) hardcoded format / locale-aware

This is *not* this mission's scope, but it's the obvious follow-up
and it's the kind of audit that a deterministic tool (a script that
walks the PromptElement class hierarchy and dumps render-method
signatures) would do better than us reading source. Principle-2
applied to our own catalog work.

Connection to other seams:

- **Seam 1 sub-mechanism A**: the new settings inherit the same
  `["advanced", "experimental"]` hide. Daniel's
  `alwaysShowAdvancedSettings: true` makes them visible without
  effort. So if we adopt this patch, no Seam-1 fix needed.

### Smallest fix sketch

Adopt Sasha's diff verbatim as a patch in our `patches/` stack. Done.
~280 LOC, isolated, well-tested. This is the easiest concrete patch
in the catalog.

**One sovereign-side variation worth considering**: change the
*default* of `chat.advanced.context.timeFormat` from `"off"` to `"24h"`
(and possibly `showTimezone: true`). Sasha's defaults are
upstream-friendly ("opt-in, doesn't change behavior unless asked").
Sovereign-side, our position is "honest context by default", so
flipping the defaults is consistent with the project principle.

### Open questions

- Sasha's patch lands new keys under `chat.advanced.context.*`. Are
  there *other* context-assembly fields under prefixes like
  `chat.advanced.context.*` already, or is this a fresh namespace?
  Cheap check; affects whether we treat this prefix as the conventional
  home for principle-1-omission fixes going forward.
- The simulation cache guard. If we ever add fields that *should* be
  in cached prompts (e.g. workspace name, OS version), how do we
  distinguish them from time-like volatile fields? Probably needs a
  per-field `isSimulationStable: boolean` convention, or a
  `<TimeAware>` wrapper. Not blocking for adoption.
- The exact `Intl.DateTimeFormat`/`toLocaleString` variants Sasha used
  are good for English-speaking US-style consumers. For sovereign
  multi-locale users, we might want `locale: 'en-US'` to be
  configurable too, or ISO-8601 as an option (`2026-05-07T14:30:45+02:00`).
  Defer.

---

---

## Seam 5 — file-edit policy ("can't touch package.json")

**Status:** investigated 2026-05-07.

### The observed weirdness

Daniel's symptom: dedicated tools (`create_file`, `replace_string_in_file`)
sometimes refuse / require confirmation for files like `package.json`, but
the same edit lands fine via `touch foo` + edit-tool, or `rm foo` via the
terminal. We want to *own* this policy.

### What we found

The mechanism is **two-layered**, and both layers are upstream-defined:

#### Layer A — soft block (confirmation prompt)

Located in
[`vscode/extensions/copilot/src/extension/tools/node/editFileToolUtils.tsx:805`](../../vscode/extensions/copilot/src/extension/tools/node/editFileToolUtils.tsx) — `makeUriConfirmationChecker`. Returns a
`ConfirmationCheckResult` enum: `NoConfirmation | NoPermissions | Sensitive
| SystemFile | OutsideWorkspace`. Any non-`NoConfirmation` result causes
`createEditConfirmation` to produce a `confirmationMessages` block on the
prepared tool invocation, which the chat UI surfaces as "Allow edits to
sensitive files? Yes/No".

This is **not a hard refusal** — it's a confirm-or-deny prompt. The
"refusal" symptom is just the prompt being auto-declined or read as a
block by the model.

Sources of "Sensitive" classification, in priority order inside `checkUri`:

1. **`platformConfirmationRequiredPaths`** (hardcoded
   [`editFileToolUtils.tsx:711-728`](../../vscode/extensions/copilot/src/extension/tools/node/editFileToolUtils.tsx)):
   `~/.*` and `~/.*/**` (any homedir dotfile/dotdir),
   `~/Library` on macOS, `%APPDATA%` / `%LOCALAPPDATA%` on Windows.
   Always returns `SystemFile` if the URI matches and the workspace
   isn't itself rooted under that path. **Hardcoded — no setting.**
2. **`ALWAYS_CHECKED_EDIT_PATTERNS`** (hardcoded
   [`editFileToolUtils.tsx:711`](../../vscode/extensions/copilot/src/extension/tools/node/editFileToolUtils.tsx)):
   `'**/.vscode/*.json': false`. Always requires confirmation.
   **Hardcoded — no setting.**
3. **`chat.hookFilesLocations`** config — patterns are auto-added to
   the deny list. Defined in vscode core
   ([`chat.contribution.ts:1370`](../../vscode/src/vs/workbench/contrib/chat/browser/chat.contribution.ts)).
4. **`chat.tools.edits.autoApprove`** — the user-facing knob. **Defined
   in vscode core, not the Copilot extension.** Default value
   ([`chat.contribution.ts:516`](../../vscode/src/vs/workbench/contrib/chat/browser/chat.contribution.ts)):

   ```jsonc
   {
       "**/*": true,
       "**/.vscode/*.json": false,
       "**/.git/**": false,
       "**/{package.json,server.xml,build.rs,web.config,.gitattributes,.env}": false,
       "**/*.{code-workspace,csproj,fsproj,vbproj,vcxproj,proj,targets,props}": false,
       "**/*.lock": false,        // yarn.lock, bun.lock, etc.
       "**/*-lock.{yaml,json}": false  // pnpm-lock.yaml, package-lock.json
   }
   ```

   **Last-match-wins.** "Sensitive" returned when no rule approves
   ([`editFileToolUtils.tsx:890`](../../vscode/extensions/copilot/src/extension/tools/node/editFileToolUtils.tsx)).

Default config explicitly lists `package.json` as confirmation-required.
**That's the source of Daniel's symptom.** It's not a tool bug; it's a
default policy.

#### Layer B — hard block (`allowedEditUris`)

When `promptContext.allowedEditUris` is set to a `ResourceSet`, any edit
to a URI outside that set fails outright via `getDisallowedEditUriError`
with a non-recoverable error returned to the model. Not pattern-based —
session-state-based.

**Single producer in the codebase**:
[`inlineChatIntent.ts:407`](../../vscode/extensions/copilot/src/extension/inlineChat2/node/inlineChatIntent.ts).
The set contains exactly one URI: the document the user invoked inline
chat (Cmd+I / Ctrl+I) from. So Layer B fires **only for inline chat**,
not for panel chat, agent mode, or terminal chat. Outside inline chat
`allowedEditUris` is `undefined` and the hard block never engages.

This is narrower than it looks — it's specifically inline-chat's
scoping mechanism (the user opened inline-chat *on this file*, so we
won't let the model wander to other files), not a general
"constrained edit" framework.

#### Note on `NoPermissions`

The `NoPermissions` enum value is **genuine filesystem `EPERM`**, not
a Copilot policy. Code path
([`editFileToolUtils.tsx:925-928`](../../vscode/extensions/copilot/src/extension/tools/node/editFileToolUtils.tsx)):
`fs.realpath(uri.fsPath)` is called to resolve symlinks; if it throws
`EPERM` (POSIX "you don't have permission to traverse this path" —
typically a missing directory `x` bit, SELinux, or AppArmor), the
checker returns `NoPermissions`. The naming overloads "permissions"
unfortunately (with the policy sense), but the implementation is
honest: real OS error, not a soft policy.

### Why terminal commands escape

`touch foo`, `rm foo`, `mv` etc. go through the **terminal tool**, which
has its own *separate* confirmation/approval policy
(`chat.tools.terminal.autoApprove*` family of settings). Different
allowlist, different defaults — and crucially, terminal `touch` doesn't
trip the file-edit `Sensitive` classifier at all because the file-edit
policy only runs inside `prepareInvocation` of the file-write tools.
Once `touch package.json` has run, the file *exists*, and a subsequent
`replace_string_in_file` only triggers an *edit* prompt — which can be
auto-approved by `chat.tools.edits.autoApprove` overrides — instead of
the *create* prompt that creating-from-scratch would have surfaced.

This is a real seam: **the policy is not unified across "ways to write
a file"**. Two separate policy stacks (file-tool edit-policy and
terminal-tool command-policy) reach the same physical action via
different code paths, and they disagree on what's sensitive.

### Smallest fix sketch

Multiple shapes, in increasing surface:

1. **User-config override** (zero-patch, immediate): set
   `chat.tools.edits.autoApprove` in user settings to overwrite the
   default — e.g. add `"**/package.json": true` if Daniel wants
   package.json freely edited. This is what one would do today, but
   it leaves `**/.vscode/*.json` and `**/.git/**` and the homedir
   dotfile rule still hardcoded-deny.

2. **Sovereign default override** (small, build-time): replace the
   default value of `chat.tools.edits.autoApprove` in the upstream
   schema. One-line patch in `chat.contribution.ts`. Reveals our
   stance ("we trust the user; don't pre-block their own files") but
   the hardcoded `ALWAYS_CHECKED_EDIT_PATTERNS` and
   `platformConfirmationRequiredPaths` rules still apply.

3. **Promote hardcoded rules to settings** (medium, principle-1
   honesty): turn `ALWAYS_CHECKED_EDIT_PATTERNS` and
   `platformConfirmationRequiredPaths` into config-overridable values.
   Stops the editor from lying about which rules are in effect — right
   now, two of three rule sources are invisible to the user. The "I
   wonder why my edit needs confirmation" → settings.json path is
   currently broken because the rule isn't in settings.

4. **Unified policy across file-tool and terminal-tool** (large,
   principle-1 + principle-2): factor the "is this resource sensitive"
   decision out of both stacks into a single resource-classification
   service. Both file-tool `prepareInvocation` and terminal-tool
   command-prepare consult it. Currently the two stacks diverge on
   patterns and on confirmation UX — that divergence is exactly the
   "weirdness" Daniel observes.

Recommend starting with #2 and #3 together. #2 ships a sovereign
default; #3 makes the policy fully introspectable. #4 is a real
refactor and deserves its own mission later.

### Classification

**Both principles, slightly differently.**

- Principle-1 (honesty/observability): two of three rule sources are
  hardcoded and invisible — ALWAYS_CHECKED and platform paths. The
  "settings UI lies about effective policy" pattern is the same shape
  as Seam 1.
- Principle-2 (right division of labor): the terminal-vs-file-tool
  divergence forces the AI to *route around* policy via terminal
  commands rather than declaring intent honestly. The AI is doing
  policy-arbitrage work that the editor should be doing. Unifying the
  two stacks (#4) is the principle-2 dividend.

### Sibling-pattern notes

This seam reuses the **schema-vs-implementation drift** pattern from
Seam 1 (effective rules ≠ schema-published rules) AND the
**hidden-allowlist / hidden-denylist** pattern that we should now
generalize:

> *Recurring pattern*: when a system has a list of "things to be
> careful about" (sensitive files, sensitive commands, sensitive URLs,
> auto-approved tools, …), check whether the list is actually fully
> in settings or whether some of it is hardcoded. The hardcoded part
> is always the cursed part.

Concrete sibling lists to audit later (just from this morning's reads):

- `chat.tools.terminal.autoApprove*` — terminal command policy. Same
  shape almost certainly.
- `chat.tools.fetchPage.approvedUrls` /
  `chat.tools.eligibleForAutoApproval` — already partly in settings,
  worth a check for hardcoded companions.
- `trustedExtensionAuthAccess` — extension auth allowlist (was on the
  privilege-surface map). Same shape, wider blast radius.

### Open questions

- What's in the terminal-tool policy stack, and does it really diverge
  from the file-tool policy as much as I'm asserting? Worth a
  half-hour read before promising the divergence claim. Side-quest
  flagged.
- Does `chat.tools.edits.autoApprove` honor user-scope vs
  workspace-scope correctly? If a malicious workspace `.vscode/*.json`
  could weaken policy, that's a security concern — opposite direction
  from our usual "MS over-locks" bias.
- The `forceConfirmationReason` parameter on `createEditConfirmation`
  — who passes it, and is it ever set by something *other* than the
  user's tool config? If it's a back door for upstream to escalate
  confirmation regardless of user policy, that's a Layer-A bypass that
  the user can't override and we'd want to expose.

---

# Phase 1 close-out: coexistence & privilege surface

Two questions Phase 1 owed answers to, captured here before closing the
mission. *Not seam catalog entries* — these are operational findings that
inform Phase 2's patch-stack audit.

## A. Side-by-side install with vanilla VS Code

**Status: solved, machinery already in place.**

VSCodium's `prepare_vscode.sh` mutates ~25 product.json identity fields
based on `ORG_NAME` / `VSCODE_QUALITY` env. Side-by-side install with
vanilla works by setting all of:

- `nameShort`, `nameLong`, `applicationName` → binary name
- `dataFolderName`, `serverDataFolderName` → user-data dir (`~/.vscode`
  vs `~/.scode`)
- `urlProtocol` → URL scheme handler
- `linuxIconName` → desktop icon
- `serverApplicationName` → remote-server binary name
- Win/macOS-specific: `darwinBundleIdentifier`, `win32MutexName`,
  `win32AppId` (multiple variants), `win32RegValueName` …
- `tunnelApplicationName`, `win32TunnelMutex`, `win32TunnelServiceMutex`
  → coexisting tunnel service

For Linux-only sovereign builds (our only build target), the
load-bearing fields are: `nameShort`, `nameLong`, `applicationName`,
`dataFolderName`, `urlProtocol`, `linuxIconName`,
`serverApplicationName`, `serverDataFolderName`,
`tunnelApplicationName`. ~9 fields.

Protocol exception: the final stable product intentionally keeps
`urlProtocol = vscode` for web/auth compatibility. Side-by-side identity
comes from the binary, display name, data dirs, server dirs, icons, and update
channel; `vscode://` is the one deliberate conflict with vanilla VS Code.

**All already settable through the existing VSCodium script.** We just
need to fork the script's hardcoded "VSCodium"/"codium" values to
"Sovereign Code"/"scode" or whatever final brand.

Patch implication: most of the "rebrand" inheritance from VSCodium's
patch stack is *not* what we need. The branding logic is in the
build *script*, not in VS Code patches. We just configure it
differently.

## B. Updates via our GitHub release metadata

**Status: first-wave wired.**

`prepare_vscode.sh` already sets:

- `product.updateUrl = https://raw.githubusercontent.com/${GH_REPO_PATH}/refs/heads/main`
- `product.downloadUrl = https://github.com/${ASSETS_REPOSITORY}/releases`

Both are env-driven. For Sovereign Code, `GH_REPO_PATH` and
`ASSETS_REPOSITORY` both point at `DanielFabian/sovereign-vscode-build`, so
release assets and `latest.json` metadata live in the build repo rather than a
separate `versions` repository.

## C. Coexistence with marketplace `GitHub.copilot-chat`

**Status: scoped.** This is the actually-thorny question.

### The collision

The bundled Copilot extension at `vscode/extensions/copilot/` ships with
`{ publisher: "GitHub", name: "copilot-chat" }` (identity:
`GitHub.copilot-chat`). It's built into the install dir as a built-in
extension. Six places in `product.json` reference this id:

```
"defaultChatAgent.extensionId": "GitHub.copilot"           (completions ext)
"defaultChatAgent.chatExtensionId": "GitHub.copilot-chat"  (chat ext)
"defaultChatAgent.chatExtensionOutputId": "GitHub.copilot-chat.GitHub Copilot Chat.log"
"trustedExtensionAuthAccess.github": ["GitHub.copilot-chat"]
"trustedExtensionAuthAccess.github-enterprise": ["GitHub.copilot-chat"]
"builtInExtensionsEnabledWithAutoUpdates": ["GitHub.copilot-chat"]
"extensionsEnabledWithApiProposalVersion": ["GitHub.copilot-chat", ...]
```

Plus dozens of code paths in `vscode/src/` read these via
`productService.defaultChatAgent.chatExtensionId`. The id is **not**
hardcoded in core code — it flows through product.json. So we can
remap it.

The marketplace also ships `GitHub.copilot-chat` (current upstream
version). If the user installs it (or it auto-updates because
`builtInExtensionsEnabledWithAutoUpdates` lists it), **the marketplace
copy shadows the built-in**. Our patches disappear silently. This is
the actually-cursed risk, not "users get confused which Copilot to
install".

### Strategy choice

Three options:

**Strategy 1 — Keep `GitHub.copilot-chat` id, suppress marketplace
auto-update.** Remove `GitHub.copilot-chat` from
`builtInExtensionsEnabledWithAutoUpdates`. Built-in stays pinned to
our patched version. Risk: user manually clicks "Update" in the
marketplace UI and clobbers us anyway. Lower risk but not zero.

**Strategy 2 — Rename the bundled extension to `Sovereign.copilot-chat`
(or `sovereign-vscode.copilot-chat`).** Rebrand the publisher in
`vscode/extensions/copilot/package.json`, set `defaultChatAgent.chatExtensionId`
in product.json, mirror in `trustedExtensionAuthAccess` and
`extensionsEnabledWithApiProposalVersion`. Marketplace
`GitHub.copilot-chat` becomes a foreign extension; if the user installs
it, it activates as a non-default chat extension. It cannot collide
with ours because the ids are different.

**Strategy 3 — Add a "deprecated/superseded by" map** that points
`GitHub.copilot-chat` to our id. Built into vscode core via the
extension gallery service's `deprecated` map (see
[`extensionGalleryService.ts:2008`](../../vscode/src/vs/platform/extensionManagement/common/extensionGalleryService.ts)).
Requires Strategy 2 anyway (we need a target id), so this is an
*addition* to Strategy 2, not an alternative.

**Recommend Strategy 2 (alone, possibly + 3 if we want UX polish).**
Strategy 1 has a "user clicks update and breaks the editor" failure
mode that's invisible until it bites.

### Implementation cost of Strategy 2

Patches needed:

1. `vscode/extensions/copilot/package.json`: `publisher: "GitHub"` →
   `"sovereign-vscode"` (or chosen name). One line.
2. `product.json` (via prepare script or overlay): change all 6 refs
   from `GitHub.copilot-chat` to `sovereign-vscode.copilot-chat`. Six
   `setpath` calls.
3. `defaultChatAgent.chatExtensionOutputId` includes the displayName
   `"GitHub Copilot Chat"` — verify whether changing the displayName
   also changes the output channel id. Either keep the displayName
   as "GitHub Copilot Chat" (cosmetically it's still a Copilot UI) or
   thread it through.
4. Verify `trustedExtensionAuthAccess` rebrand actually works — i.e.,
   that the GitHub auth provider grants tokens to extensions in this
   list by id-match. Quick test post-rebuild.
5. Ensure CI extension testing (`extensionsEnabledWithApiProposalVersion`)
   isn't surprised by the rename.

Total: ~10 LOC across product.json + extension package.json. The hard
part is testing, not writing.

### Privilege surface, briefly

The id-keyed privileges that matter for our fork:

| Privilege | Source | What it grants |
|---|---|---|
| Default chat agent | `defaultChatAgent.chatExtensionId` | Bound to chat panel UI, settings paths |
| GitHub auth without consent prompt | `trustedExtensionAuthAccess.github` | OAuth token access for the listed ids |
| Proposed API access in built builds | `extensionsEnabledWithApiProposalVersion` | Use of `vscode.proposed.*.d.ts` APIs |
| "Built-in" tool grouping in UI | `defaultChatAgent.chatExtensionId` (read by `isBuiltinTool`) | Tools from this ext show under "Built-in" in chat UI |
| Auto-update from marketplace | `builtInExtensionsEnabledWithAutoUpdates` | Dangerous for us; remove our id from this |

**All five gates are id-keyed via product.json.** None of them require
the gate to be `GitHub.*` specifically. We rebrand the id; the gates
follow.

Other id-keyed privileges that exist in core but **we don't depend
on** (not exhaustive — only what showed up in this morning's grep):
`trustedMcpAuthAccess`, `extensionEnabledApiProposals` (per-extension
proposed-API allow-map), `extensionRecommendations`, `onboardingKeymaps`.

### Conclusion

- **Side-by-side install: free** (existing build script).
- **Updates via CDN: free** (existing build script).
- **Coexistence with marketplace Copilot: requires rename to a
  sovereign id**, ~10 LOC across product.json + extension
  package.json. No core-code patches needed; all gates are id-keyed
  through product.json.

### Implication for the patch-stack audit (Phase 2 scope)

Most of the inherited VSCodium "rebrand" patches are not what we
need — the brand mutation lives in the build *script*, not in
applied patches. The actual sovereign rebrand is:

1. Fork `prepare_vscode.sh` (or override its env vars) to set our
   names instead of "VSCodium"/"codium".
2. Add 6 `setpath` lines in our overlay/script to remap
   `GitHub.copilot-chat` → `sovereign-vscode.copilot-chat`.
3. Rebrand `vscode/extensions/copilot/package.json` publisher (one
   line, applied as a patch).
4. Drop `GitHub.copilot-chat` from
   `builtInExtensionsEnabledWithAutoUpdates`.

Total code surface for full coexistence: < 20 LOC.

Phase 2 mission can start with this concrete shopping list.
