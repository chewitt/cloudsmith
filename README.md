# cloudsmith
Scripts and actions for the Tvheadend package repo at Cloudsmith

`cloudsmith-quota.sh` checks the Cloudsmith open-source plan limit (50GB) then dumps info on all files to calculate the current repo size. If current size is greater than 90% of the plan limit, it deletes the oldest file until current repo size is under 90% again. The script is designed to be run nightly as a scheduled GitHub action with repository secrets providing CLOUDSMITH_API_KEY, CLOUDSMITH_OWNER, and CLOUDSMITH_REPO details.
