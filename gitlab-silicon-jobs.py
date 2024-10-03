#!/usr/bin/python3

import gitlab, os

CI_HOST = os.getenv("CI_SERVER_HOST")
if CI_HOST is None:
    CI_HOST = "git.libretro.com"

PRIVATE_TOKEN = os.getenv("PRIVATE_TOKEN")
if PRIVATE_TOKEN is None:
    print("Missing token!", flush=True)

gl = gitlab.Gitlab(url='https://' + CI_HOST, private_token=PRIVATE_TOKEN)

ci_groups = gl.groups.list(all=True)

for ci_group in ci_groups:
    try:
        group = gl.groups.get(ci_group.id)
    except Exception as e:
        continue

    ci_available_projects = group.projects.list(all=True)

    for project in ci_available_projects:
        try:
            parsed_project = gl.projects.get(project.id)
        except Exception as e:
            # print("Failed to fetch project: " + project.name, flush=True)
            # print(str(e), flush=True)
            continue

        try:
            pipeline = parsed_project.pipelines.latest()
        except Exception as e:
            # print("Failed to list pipelines for project: " + project.name, flush=True)
            # print(str(e), flush=True)
            continue

        jobs = pipeline.jobs.list(all=True)

        for job in jobs:
            try:
                if job.runner['id'] == 18 or job.runner['id'] == 14:
                    print(str(job.runner['id']) + ": " + group.name + "/" + project.name + ": " + job.name)

            except Exception as e:
                # print("Failed to deal with job: " + job.name + " for project: " + project.name, flush=True)
                # print(str(e), flush=True)
                continue
