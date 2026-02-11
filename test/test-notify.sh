#!/usr/bin/env bash
# Tests for srcery-notify
source "$(dirname "$0")/helpers.sh"

# ===================
echo "--- srcery-notify ---"

notify_input() {
	echo "{\"hook_event_name\":\"$1\",\"notification_type\":\"$2\",\"message\":\"$3\"}"
}

export SRCERY_SVC_WINDOW="test_wt/claude"

t "srcery-notify writes idle status"
notify_input Notification idle_prompt "Done" | srcery-notify
assert test -f "$SRCERY_DATA/status/test_wt/claude"
assert test "$(cat "$SRCERY_DATA/status/test_wt/claude")" = "idle"

t "srcery-notify writes attention status"
notify_input Notification permission_prompt "Need permission" | srcery-notify
assert test "$(cat "$SRCERY_DATA/status/test_wt/claude")" = "attention"

t "srcery-notify clears status on UserPromptSubmit"
notify_input UserPromptSubmit "" "" | srcery-notify
assert_not test -f "$SRCERY_DATA/status/test_wt/claude"

t "srcery-notify ignores unknown notification types"
notify_input Notification auth_success "" | srcery-notify
assert_not test -f "$SRCERY_DATA/status/test_wt/claude"

unset SRCERY_SVC_WINDOW

report
