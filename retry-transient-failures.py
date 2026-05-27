#!/usr/bin/python3
"""
Retry failed GitLab CI jobs that appear to have transient failures
(disk space, network, docker issues) rather than compilation errors.

Usage:
    PRIVATE_TOKEN=$(cat /path/to/token) python3 retry-transient-failures.py [--dry-run]

Token permissions required: api (full API access)
"""

import gitlab
import os
import re
import sys

CI_HOST = os.getenv("CI_SERVER_HOST", "git.libretro.com")
PRIVATE_TOKEN = os.getenv("PRIVATE_TOKEN")
DRY_RUN = "--dry-run" in sys.argv

# Projects with known compilation errors - skip these entirely
SKIP_PROJECTS = {
    "squirreljme",
    "tic-80",
    "tic80",
    "fbneo",
}

# Patterns in job logs that indicate transient failures
TRANSIENT_PATTERNS = [
    # Disk space
    r"no space left on device",
    r"not enough free disk space",
    r"disk quota exceeded",
    r"ENOSPC",
    r"fatal: unable to write new index file",
    r"failed to write new configuration file",
    # Docker issues
    r"error pulling image",
    r"failed to pull image",
    r"manifest unknown",
    r"toomanyrequests",
    r"docker.+timeout",
    r"Cannot connect to the Docker daemon",
    r"error during connect",
    r"failed to create.*container",
    r"OCI runtime create failed",
    # Network
    r"Could not resolve host",
    r"Connection timed out",
    r"Connection refused",
    r"network is unreachable",
    r"Failed to connect to",
    r"curl.*error",
    r"fatal: unable to access",
    r"SSL_ERROR",
    r"connection reset by peer",
    r"Name or service not known",
    # Runner issues
    r"runner system failure",
    r"Job failed \(system failure\)",
    r"stuck or timed.out",
    r"Job timed out",
    r"ERROR: Job failed: exit code 137",  # OOM killed
    r"execution took longer than",  # job timeout, often disk I/O stall
    # Git fetch failures
    r"fatal: (fetch|clone|remote)",
    r"error: RPC failed",
    r"The remote end hung up unexpectedly",
    # NDK compiler crashes (SIGBUS/segfault, typically from disk pressure)
    r"PLEASE submit a bug report to.*ndk",
]

TRANSIENT_RE = re.compile("|".join(TRANSIENT_PATTERNS), re.IGNORECASE)


TRANSIENT_FAILURE_REASONS = {
    "runner_system_failure",
    "stuck_or_timeout_failure",
    "job_execution_timeout",
}


def is_transient_failure(job, job_trace: str) -> str | None:
    """Check if a job failed due to a transient issue.
    Returns the matched reason or None."""
    # Check GitLab's failure_reason field first
    failure_reason = getattr(job, "failure_reason", None)
    if failure_reason in TRANSIENT_FAILURE_REASONS:
        return f"failure_reason: {failure_reason}"

    # Check last 200 lines of log for known patterns
    lines = job_trace.splitlines()
    tail = "\n".join(lines[-200:])
    match = TRANSIENT_RE.search(tail)
    if match:
        return match.group(0)
    return None


def should_skip_project(project_name: str) -> bool:
    name_lower = project_name.lower()
    return any(skip in name_lower for skip in SKIP_PROJECTS)


def main():
    if not PRIVATE_TOKEN:
        print("Error: PRIVATE_TOKEN environment variable not set")
        print("Usage: PRIVATE_TOKEN=$(cat /path/to/token) python3 retry-transient-failures.py [--dry-run]")
        sys.exit(1)

    if DRY_RUN:
        print("=== DRY RUN MODE - no jobs will be retried ===\n")

    gl = gitlab.Gitlab(url=f"https://{CI_HOST}", private_token=PRIVATE_TOKEN)

    retried = []
    skipped_compile = []
    skipped_unknown = []

    # Get the libretro group
    groups = gl.groups.list(search="libretro", iterator=True)
    for ci_group in groups:
        try:
            group = gl.groups.get(ci_group.id)
        except Exception:
            continue

        projects = group.projects.list(all=True)
        for proj_entry in projects:
            if should_skip_project(proj_entry.name):
                continue

            try:
                project = gl.projects.get(proj_entry.id)
            except Exception:
                continue

            try:
                pipeline = project.pipelines.latest()
            except Exception:
                continue

            if pipeline.status != "failed":
                continue

            # Check if the failed pipeline's commit matches the last successful build
            same_commit = False
            try:
                successes = project.pipelines.list(
                    status="success", ref=pipeline.ref,
                    order_by="id", sort="desc",
                    per_page=1, get_all=False,
                )
                if successes and successes[0].sha == pipeline.sha:
                    same_commit = True
            except Exception:
                pass

            jobs = pipeline.jobs.list(all=True)
            failed_jobs = [j for j in jobs if j.status == "failed"]

            if not failed_jobs:
                continue

            for job in failed_jobs:
                job_desc = f"{project.path_with_namespace} / {job.name} (job {job.id})"

                runner = getattr(job, "runner", None)
                runner_desc = runner.get("description", runner.get("id", "unknown")) if runner else "unknown"

                try:
                    full_job = project.jobs.get(job.id)
                    trace = full_job.trace().decode("utf-8", errors="replace")
                except Exception as e:
                    skipped_unknown.append((job_desc, f"could not fetch log: {e}"))
                    continue

                likely_cause = is_transient_failure(job, trace)

                if same_commit:
                    cause_detail = f" ({likely_cause})" if likely_cause else ""
                    reason = f"same commit as last successful build{cause_detail}"
                else:
                    reason = likely_cause

                if reason:
                    if DRY_RUN:
                        print(f"WOULD RETRY: {job_desc}")
                        print(f"  runner: {runner_desc}")
                        print(f"  reason: {reason}\n")
                    else:
                        try:
                            full_job.retry()
                            print(f"RETRIED: {job_desc}")
                            print(f"  runner: {runner_desc}")
                            print(f"  reason: {reason}\n")
                        except Exception as e:
                            print(f"RETRY FAILED: {job_desc}: {e}\n")
                    retried.append((job_desc, reason))
                else:
                    skipped_unknown.append((job_desc, "no transient pattern matched"))

    print("=" * 60)
    print(f"Retried:             {len(retried)}")
    print(f"Skipped (unknown):   {len(skipped_unknown)}")
    if skipped_unknown:
        print("\nFailed jobs NOT retried (may be real build failures):")
        for desc, reason in skipped_unknown:
            print(f"  {desc}")


if __name__ == "__main__":
    main()
