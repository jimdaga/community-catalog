#!/usr/bin/env bash
set -eu

# Fixtures are selected by the Snapshot, ReleasePlan, and Release names
# passed to kubectl. Release names are "release-<snapshot>", so the Snapshot
# name also controls how the Release behaves.
#
# Snapshots:
#   pr-snapshot           pull_request event, application demo
#   pr-snapshot-existing  a Release already exists for it
#   pr-snapshot-failed    its Release fails
#   pr-snapshot-stuck     its Release never completes
#   pr-snapshot-duplicate two Releases already exist for it
#   push-snapshot         push event
#   other-app-snapshot    pull_request event, application other
# ReleasePlans:
#   dev-plan              application demo, auto-release "false"
#   prod-plan             application demo, auto-release "true"

function sleep() {
  command sleep 1
}

function kubectl() {
  if [[ "$1" == "get" && "$2" == "snapshot" ]]; then
    case "$3" in
      push-snapshot) EVENT=push; APP=demo ;;
      other-app-snapshot) EVENT=pull_request; APP=other ;;
      *) EVENT=pull_request; APP=demo ;;
    esac
    jq -n --arg name "$3" --arg event "$EVENT" --arg app "$APP" '{
      metadata: {
        name: $name, uid: ("uid-" + $name),
        labels: {"pac.test.appstudio.openshift.io/event-type": $event}
      },
      spec: {application: $app, components: []}
    }'

  elif [[ "$1" == "get" && "$2" == "releaseplan" ]]; then
    case "$3" in
      dev-plan) AUTO=false ;;
      prod-plan) AUTO=true ;;
      *) echo "Error: Unexpected ReleasePlan: $3" >&2; return 1 ;;
    esac
    jq -n --arg name "$3" --arg auto "$AUTO" '{
      metadata: {name: $name, labels: {"release.appstudio.openshift.io/auto-release": $auto}},
      spec: {application: "demo"}
    }'

  elif [[ "$1" == "get" && "$2" == "releases" ]]; then
    case "$*" in
      *pr-snapshot-uid=uid-pr-snapshot-existing,*)
        echo '{"items": [{"metadata": {"name": "release-pr-snapshot-existing"}}]}' ;;
      *pr-snapshot-uid=uid-pr-snapshot-duplicate,*)
        echo '{"items": [{"metadata": {"name": "release-a"}}, {"metadata": {"name": "release-b"}}]}' ;;
      *) echo '{"items": []}' ;;
    esac

  elif [[ "$1" == "create" ]]; then
    REQUEST=$(cat)
    # Check that the Release is labeled so it can be found again on re-runs
    if ! jq -e '
      .kind == "Release" and
      .spec.releasePlan == "dev-plan" and
      .metadata.labels["community-catalog.konflux-ci.dev/pr-snapshot-uid"] == ("uid-" + .spec.snapshot) and
      .metadata.labels["community-catalog.konflux-ci.dev/pr-release-plan"] == "dev-plan"
    ' <<< "$REQUEST" > /dev/null; then
      echo "Error: Unexpected Release request: $REQUEST" >&2
      return 1
    fi
    echo -n "release-$(jq -r '.spec.snapshot' <<< "$REQUEST")"

  elif [[ "$1" == "get" && "$2" == "release" ]]; then
    # Report Progressing on the first poll so the wait loop is exercised
    POLL_FILE="/tmp/polls-$3"
    POLLS=$(cat "$POLL_FILE" 2> /dev/null || echo 0)
    echo $((POLLS + 1)) > "$POLL_FILE"
    if [[ "$POLLS" -eq 0 || "$3" == "release-pr-snapshot-stuck" ]]; then
      STATUS=False; REASON=Progressing
    elif [[ "$3" == "release-pr-snapshot-failed" ]]; then
      STATUS=False; REASON=Failed
    else
      STATUS=True; REASON=Succeeded
    fi
    jq -n --arg status "$STATUS" --arg reason "$REASON" '{
      status: {conditions: [{type: "Released", status: $status, reason: $reason, message: "mock"}]}
    }'

  else
    echo "Error: Unexpected kubectl call: $*" >&2
    return 1
  fi
}
