# Paperclip payload examples

Use these examples with `./scripts/paperclip-api.sh` once the shell has either a
board-authenticated session or `PAPERCLIP_API_KEY`.

If you only need to inspect the generated JSON without sending a request, prefer
the `*-payload` commands shown below.

## Resume comment on the current issue

Use the built-in helper for the most common resume flow:

```bash
./scripts/paperclip-api.sh issue-resume-payload "Resuming the task after the runtime auth fix."
./scripts/paperclip-api.sh issue-resume-current "Resuming the task after the runtime auth fix."
```

Or send the raw JSON payload directly:

```bash
printf '%s\n' '{
  "body": "Resuming the task after the runtime auth fix.",
  "resume": true
}' | ./scripts/paperclip-api.sh issue-comment-current -
```

## Reopen the current issue for follow-up work

Use the built-in helper when the issue needs a reopen signal and a resume signal:

```bash
./scripts/paperclip-api.sh issue-reopen-payload "Reopening this issue for follow-up work."
./scripts/paperclip-api.sh issue-reopen-current "Reopening this issue for follow-up work."
```

Or send the raw JSON payload directly:

```bash
printf '%s\n' '{
  "body": "Reopening this issue for follow-up work.",
  "resume": true,
  "reopen": true
}' | ./scripts/paperclip-api.sh issue-comment-current -
```

## Interrupt the current issue

Use the built-in helper when the issue should record an interrupt:

```bash
./scripts/paperclip-api.sh issue-interrupt-payload "Interrupting current execution pending external input."
./scripts/paperclip-api.sh issue-interrupt-current "Interrupting current execution pending external input."
```

Or send the raw JSON payload directly:

```bash
printf '%s\n' '{
  "body": "Interrupting current execution pending external input.",
  "interrupt": true
}' | ./scripts/paperclip-api.sh issue-comment-current -
```

## Mark the current issue done

Use the built-in helper for the most common done flow:

```bash
./scripts/paperclip-api.sh issue-done-payload "Completed and verified in the cloud workspace."
./scripts/paperclip-api.sh issue-done-current "Completed and verified in the cloud workspace."
```

Or send the raw JSON payload directly:

```bash
printf '%s\n' '{
  "status": "done",
  "comment": "Completed and verified in the cloud workspace."
}' | ./scripts/paperclip-api.sh issue-update-current -
```

## Mark the current issue blocked

Use the built-in helper when the issue must name an unblock owner and required
action:

```bash
./scripts/paperclip-api.sh issue-blocked-payload \
  "Paperclip operator" \
  "Inject PAPERCLIP_API_KEY into the Cursor Cloud adapter env" \
  "The shell can reach the private deployment but cannot mutate issue state."
./scripts/paperclip-api.sh issue-blocked-current \
  "Paperclip operator" \
  "Inject PAPERCLIP_API_KEY into the Cursor Cloud adapter env" \
  "The shell can reach the private deployment but cannot mutate issue state."
```

## Ask structured user questions

Use the built-in helper for the most common single-question flow:

```bash
./scripts/paperclip-api.sh issue-ask-user-question-payload \
  runtime-auth \
  "Which Paperclip secret should back PAPERCLIP_API_KEY for this agent?"
./scripts/paperclip-api.sh issue-ask-user-question-current \
  runtime-auth \
  "Which Paperclip secret should back PAPERCLIP_API_KEY for this agent?"
```

Or send the raw JSON payload directly:

```bash
printf '%s\n' '{
  "kind": "ask_user_questions",
  "questions": [
    {
      "id": "runtime-auth",
      "prompt": "Which Paperclip secret should back PAPERCLIP_API_KEY for this agent?"
    }
  ],
  "continuationPolicy": "wake_assignee"
}' | ./scripts/paperclip-api.sh issue-interaction-current -
```

## Suggest child tasks

Use the built-in helper for the common single-task suggestion flow:

```bash
./scripts/paperclip-api.sh issue-suggest-task-payload \
  "Suggested follow-up tasks" \
  "Inject PAPERCLIP_API_KEY into the Cursor Cloud adapter env" \
  "Add the agent API key as a secret-backed env var so the cloud shell can comment on and update issues."
./scripts/paperclip-api.sh issue-suggest-task-current \
  "Suggested follow-up tasks" \
  "Inject PAPERCLIP_API_KEY into the Cursor Cloud adapter env" \
  "Add the agent API key as a secret-backed env var so the cloud shell can comment on and update issues."
```

Or send the raw JSON payload directly:

```bash
printf '%s\n' '{
  "kind": "suggest_tasks",
  "title": "Suggested follow-up tasks",
  "body": "Choose any follow-up work that should happen after the current blocker is cleared.",
  "tasks": [
    {
      "title": "Inject PAPERCLIP_API_KEY into the Cursor Cloud adapter env",
      "body": "Add the agent API key as a secret-backed env var so the cloud shell can comment on and update issues."
    },
    {
      "title": "Verify authenticated heartbeat end-to-end",
      "body": "Run the helper suite, then leave a Paperclip task comment and final disposition from the shell."
    }
  ],
  "continuationPolicy": "wake_assignee"
}' | ./scripts/paperclip-api.sh issue-interaction-current -
```

## Request confirmation for a plan

Update the plan document first, then send a confirmation tied to the latest plan
revision. Replace the placeholder values before sending:

Use the built-in helper when you only need the standard plan-confirmation shape:

```bash
./scripts/paperclip-api.sh issue-confirm-plan-payload \
  run-issue-id \
  "Approve plan revision" \
  "Please approve the latest plan revision before implementation starts." \
  revision-123
./scripts/paperclip-api.sh issue-confirm-plan-current \
  "Approve plan revision" \
  "Please approve the latest plan revision before implementation starts." \
  revision-123
```

Or send the raw JSON payload directly:

```bash
ISSUE_ID="replace-with-issue-id"
REVISION_ID="replace-with-plan-revision-id"

printf '%s\n' "{
  \"kind\": \"request_confirmation\",
  \"title\": \"Approve plan revision\",
  \"body\": \"Please approve the latest plan revision before implementation starts.\",
  \"idempotencyKey\": \"confirmation:${ISSUE_ID}:plan:${REVISION_ID}\",
  \"supersedeOnUserComment\": true,
  \"continuationPolicy\": \"wake_assignee\",
  \"documentTarget\": {
    \"type\": \"plan_revision\",
    \"revisionId\": \"${REVISION_ID}\"
  }
}" | ./scripts/paperclip-api.sh issue-interaction-current -
```

## Read current issue details or comments

```bash
./scripts/paperclip-api.sh issue-get-current
./scripts/paperclip-api.sh issue-comments-current
./scripts/paperclip-api.sh issue-comments-current comment-id-to-page-after
```

## Update the current issue without blocking

Use the built-in helper for the most common in-review flow:

```bash
./scripts/paperclip-api.sh issue-in-review-payload "Work is ready for a named reviewer."
./scripts/paperclip-api.sh issue-in-review-current "Work is ready for a named reviewer."
```

Or send the raw JSON payload directly:

```bash
printf '%s\n' '{
  "status": "in_review",
  "comment": "Work is ready for a named reviewer."
}' | ./scripts/paperclip-api.sh issue-update-current -
```

## Run the full helper verification suite

```bash
./scripts/test-paperclip-tools.sh
```
