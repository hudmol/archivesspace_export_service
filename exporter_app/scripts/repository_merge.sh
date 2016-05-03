#!/usr/bin/env bash

set -euf -o pipefail

mkdir -p "$WORKSPACE_DIRECTORY"

cd "$WORKSPACE_DIRECTORY"

if [ ! -d .git ]; then
    git init

    touch .gitignore
    git add .gitignore
    git commit -m "Initial import"
fi

for workspace in  ${1+"$@"}; do
    repo_path="${workspace}/${EXPORTED_DIRECTORY}"
    repo_name="$(basename $workspace)"

    if [ ! -d "${repo_path}/.git" ]; then
        echo "No git repo found for repository: ${repo_path}.  Skipping this one."
        continue;
    fi

    # This will fail if we've already got the remote, and that's fine
    git remote add "$repo_name" "$repo_path" 2>/dev/null || true
    git fetch "$repo_name"

    if [ ! `git branch --list _${repo_name}` ]; then
        # Create a local branch mirroring our remote, prefixed with an _
        #
        # Initially we'll start this off on the first commit for the
        # branch, which will be an empty "initial import" one anyway.

        target_commit=$(git rev-list --reverse "$repo_name/master" | head -1)

        git checkout -b "_${repo_name}" "$target_commit"
    fi

    # Now _branchname contains the last commit we cherry-picked into
    # this repository.  We'll use that branch to track our state.

    # Cherry pick the commits we need--anything added to master since our last pull
    git checkout master

    if [ `git rev-list "_${repo_name}".."${repo_name}/master"` ]; then
        git cherry-pick $(git rev-list "_${repo_name}".."${repo_name}/master")
    fi

    # Now reset our tracking branch to the latest commit we've (just) cherry picked
    git checkout "_${repo_name}"
    git reset --hard "${repo_name}/master"
    git checkout master
done

# Now we're fully up to date.  Push to git!
git remote rm origin 2>&1 || true
git remote add origin "$GIT_REMOTE"

#git push origin master
