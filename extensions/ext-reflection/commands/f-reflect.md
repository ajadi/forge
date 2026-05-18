Run post-task reflection via the reflect subagent.

$ARGUMENTS

If a task file path was provided as argument, use it. Otherwise, find the most recently modified file in `tasks/archive/` and use that.

Pass the task file path to the reflect subagent for analysis.

Invoke the `reflect` subagent to analyze the completed task and propose framework improvements.
Use subagent: reflect
Mode: bypassPermissions