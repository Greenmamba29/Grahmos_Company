# GRA-107 - Prometheus silent run review

## Summary

This heartbeat reviewed the silent Prometheus run reported under GRA-107 and found that the run did not stall inside task execution. The latest concrete failure happened earlier during the `opencode_local` adapter preflight step, where `opencode models` timed out after 20 seconds.

## Evidence collected

- Wake payload continuation summary identified the affected run as `17623396-b125-4eb3-90e0-c3ea245c6ebd`.
- The latest follow-up run recorded in the summary was `328f56dd-897d-4e88-bb56-9fff463d8b8d`, which ended `failed`.
- The summary captured:
  - no task output
  - no adapter result summary
  - latest run error: `opencode models` timed out after 20s
- Live Paperclip UI/API inspection showed the board is reachable, but shell access from this cloud agent has no board session and cannot mutate issue state directly.
- External references confirm this is a known `opencode_local` failure mode in Paperclip:
  - `paperclipai/paperclip#2835` documents that `opencode_local` runs `opencode models` as a model-discovery preflight and fails the run when that step exceeds a fixed 20 second timeout.
  - OpenCode CLI docs confirm `opencode models` performs model listing and may depend on models metadata fetches.

## What this likely means

The "silent run" symptom is secondary. The actual failure is that the adapter never got past model discovery, so the task body never began producing output.

This points to an adapter/runtime problem on the host that runs Prometheus rather than a repo code regression in this workspace.

Most likely causes:

1. `opencode models` is slow on the Prometheus host and exceeds Paperclip's fixed 20 second preflight timeout.
2. The Prometheus host has outbound access, DNS, proxy, TLS, or provider-auth conditions that slow or block model discovery.
3. The adapter should be configured to avoid or shorten remote model fetch dependence where possible.

## Recommended unblock owner and action

**Owner:** Casius Nexus / platform owner for the Prometheus `opencode_local` environment.

**Action:**

1. Reproduce on the Prometheus host with timing:
   - `time opencode models`
2. If this exceeds 20 seconds, treat it as the direct blocker.
3. Apply one of these mitigations on that host:
   - configure the environment to avoid remote model fetch where appropriate, such as `OPENCODE_DISABLE_MODELS_FETCH=true` with a local models source
   - point `OPENCODE_MODELS_URL` at a reachable internal mirror if the host network is constrained
   - fix proxy / TLS / outbound connectivity issues affecting model discovery
   - upgrade or patch the Paperclip `opencode_local` adapter so the model-discovery timeout is configurable instead of fixed at 20 seconds

## Disposition

Recommended issue disposition: **blocked**

Reason: the next required step is a host-level fix or adapter configuration change on the Prometheus `opencode_local` runtime, and this cloud-agent shell does not have board authentication or control of that runtime.
