# GRA-15 investigation: plugin worker outbound HTTP to Telegram

## Heartbeat disposition

Blocked. The current Cursor workspace is the GrahmOS control repo, not the Hermes implementation repo that contains the failing Telegram worker send path.

## What changed this heartbeat

I traced the likely implementation surface to `Greenmamba29/hermes-agent_bot` and validated a targeted fix there in a local clone.

## Root cause

The Hermes gateway adapter already has hardened Telegram network handling:

- `gateway/platforms/telegram.py`
- `gateway/platforms/telegram_network.py`

That path already supports:

- fallback IP transport for `api.telegram.org`
- retry/reconnect handling for transient Telegram network failures

The worker/tool path does **not** share that protection:

- `tools/send_message_tool.py::_send_telegram`

Before the patch, the worker send path:

- built a plain `Bot(token=...)`
- did not use the fallback transport
- did not retry transient network errors such as `ECONNRESET`

That means plugin/tool workers could still fail on outbound Telegram HTTP even though the gateway adapter had already been hardened.

## Validated patch prepared against `hermes-agent_bot`

Target files:

- `tools/send_message_tool.py`
- `tests/tools/test_send_message_tool.py`

Patch behavior:

1. Pass configured Telegram fallback IPs from `_send_to_platform(...)` into `_send_telegram(...)`.
2. Detect retryable worker-side Telegram failures including:
   - `ECONNRESET`
   - connection resets/refusals
   - timeouts
   - generic Telegram `NetworkError` / `TimedOut`-style failures
3. Rebuild the one-shot Telegram `Bot(...)` with `TelegramFallbackTransport` after the first retryable network failure.
4. Retry the send with exponential backoff.
5. Add focused tests for:
   - retry after a retryable network failure
   - fallback-transport rebuild after an `ECONNRESET`-style failure
   - passing configured fallback IPs through the worker send path

## Verification completed

I could not run the repo's full pytest target without pulling in the broader Hermes dependency tree, but I did complete focused verification against the patched worker path:

- syntax check:
  - `python3 -m py_compile tools/send_message_tool.py tests/tools/test_send_message_tool.py`
- focused smoke test:
  - loaded `tools/send_message_tool.py` with stubbed Telegram and transport modules
  - simulated first-send `ECONNRESET`
  - verified retry switched to fallback transport and then succeeded
  - observed output: `smoke-ok`

## Unblock owner and next action

Owner: the next agent/heartbeat with the actual Hermes source repo mounted.

Next action:

1. Mount or switch the workspace to `Greenmamba29/hermes-agent_bot`.
2. Apply the validated patch to:
   - `tools/send_message_tool.py`
   - `tests/tools/test_send_message_tool.py`
3. Run the focused Telegram tests in that repo's real environment.
4. Open the implementation PR from the Hermes repo.

## Notes

- I was not able to update the Paperclip issue directly from this workspace because the available Paperclip API routes required authentication that is not exposed in the current environment.
- No new human comment was present in the wake payload; this heartbeat was a source-scoped recovery action on an already blocked issue.
