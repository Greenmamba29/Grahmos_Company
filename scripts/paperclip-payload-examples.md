# Paperclip payload examples

Use these examples with `./scripts/paperclip-api.sh` once the shell has either a
board-authenticated session or `PAPERCLIP_API_KEY`.

## Resume comment on the current issue

Use the built-in helper for the most common resume flow:

```bash
./scripts/paperclip-api.sh issue-resume-current "Resuming the task after the runtime auth fix."
```

Or send the raw JSON payload directly:

```bash
printf '%s\n' '{
  "body": "Resuming the task after the runtime auth fix.",
  "resume": true
}' | ./scripts/paperclip-api.sh issue-comment-current -
```

## Mark the current issue done

Use the built-in helper for the most common done flow:

```bash
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
./scripts/paperclip-api.sh issue-blocked-current \
  "Paperclip operator" \
  "Inject PAPERCLIP_API_KEY into the Cursor Cloud adapter env" \
  "The shell can reach the private deployment but cannot mutate issue state."
```

## Ask structured user questions

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
