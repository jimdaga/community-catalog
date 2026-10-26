# request-release-from-pr-snapshot

Create a Release for a pull request Snapshot and wait for it to complete.

Intended to run as an IntegrationTestScenario so that pull request builds
can be published (for example to a development registry) by an existing
tenant ReleasePlan. The task itself holds no registry credentials; the
ReleasePlan's pipeline and service account do the publishing.

Guards:
- The Snapshot must come from a pull_request event
- The ReleasePlan must belong to the same application as the Snapshot
- The ReleasePlan must be labeled release.appstudio.openshift.io/auto-release: "false"
  so that it cannot be a ReleasePlan used for regular releases

A Release already created for the same Snapshot UID and ReleasePlan is
reused, so re-running the test does not create duplicate Releases.
The task succeeds or fails based on the Release's Released condition.

The TaskRun service account needs get access to Snapshots and ReleasePlans
and create, get, and list access to Releases in the namespace

## Parameters

| Name            | Description                                                                   | Optional | Default value |
|-----------------|-------------------------------------------------------------------------------|----------|---------------|
| SNAPSHOT        | Name of the pull request Snapshot in the TaskRun namespace                    | No       | -             |
| RELEASE_PLAN    | Name of the ReleasePlan in the TaskRun namespace to release the Snapshot with | No       | -             |
| TIMEOUT_SECONDS | How long to wait for the Release to complete                                  | Yes      | 3600          |
