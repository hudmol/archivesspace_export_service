#!/usr/bin/env bash
#
# This script takes one or more paths to git repositories and produces
# a new git repository (under $WORKSPACE_DIRECTORY) which is the
# result of merging those repositories together.  If
# $WORKSPACE_DIRECTORY is already populated, it will work out which
# commits need to be integrated and merge them in.
#
# The mechanism for doing this is as follows:
#
#   * Our target repository has a local branch corresponding to each
#     source repository.  This is used to keep track of the last
#     commit we have applied from each source.
#
#   * We fetch from each source repository, and determine which
#     commits were added since we last merged.  We can do this by
#     comparing our local branch to the remote branch.
#
#   * We then cherry pick this range of commits onto our target
#     branch.
#
#   * Finally, we update our local branch to match the remote, marking
#     those commits as having been merged.
#
# One potential for problems is if we get interrupted halfway through
# the process of cherry-picking the commits, as we could end up with a
# state where our target's master branch contains some commits but not
# others (which would cause subsequent runs to re-merge those commits
# and create merge conflicts).
#
# We get around this by writing a "snapshot" file at the beginning of
# the whole process.  This records a copy of all of our branches at a
# known good state and, if we're interrupted at any point, we use this
# file to roll back.

set -euf -o pipefail

mkdir -p "$WORKSPACE_DIRECTORY"
cd "$WORKSPACE_DIRECTORY"

REPO_SNAPSHOT_FILE="$WORKSPACE_DIRECTORY/.snapshot"

# Create our git repo if it doesn't exist yet
if [ ! -d .git ]; then
    git init

    echo "/$(basename $REPO_SNAPSHOT_FILE)" > .gitignore
    git add .gitignore
    git commit -m "Initial import"
fi

# If a snapshot file is present, we were interrupted.  Roll back now.
if [ -e "$REPO_SNAPSHOT_FILE" ]; then
    echo "Rolling back to snapshot before we start"

    # Abort any in-progress cherry picks
    git cherry-pick --quit 2>/dev/null || true
    git cherry-pick --abort 2>/dev/null || true

    # Clear any existing branches
    git checkout master
    git for-each-ref --format='%(refname)' 'refs/heads/_*' | while read branch_ref; do
                                                                 branch=$(echo "$branch_ref" | sed 's/^.*\///')
                                                                 git branch -D "$branch"
                                                             done

    # and recreate them
    cat "$REPO_SNAPSHOT_FILE" | while read branch_ref commit; do
                                    branch=$(echo "$branch_ref" | sed 's/^.*\///')

                                    if [ "$branch" = "master" ]; then
                                        git checkout master
                                        git reset --hard "$commit"
                                    else
                                        git checkout -b "$branch" "$commit"
                                    fi
                                done


    rm -f "$REPO_SNAPSHOT_FILE"
fi

# Produce our snapshot file to allow for rollback if anything goes wrong
git for-each-ref --format='%(refname) %(objectname)' 'refs/heads/_*' 'refs/heads/master' > "$REPO_SNAPSHOT_FILE"

# For each repository we're merging into this one, figure out which
# commits we need and then apply them.
#
for workspace in  ${1+"$@"}; do
    echo "Working on $workspace"
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

        target_commit=$(git rev-list --reverse "$repo_name/master" | sed -n 1p)

        git checkout -b "_${repo_name}" "$target_commit"
        echo "done"
    fi

    # Now _branchname contains the last commit we cherry-picked into
    # this repository.  We'll use that branch to track our state.

    # Cherry pick the commits we need--anything added to master since our last pull
    git checkout master

    if [ "`git rev-list --reverse "_${repo_name}".."${repo_name}/master"`" ]; then
        git rev-list --reverse "_${repo_name}".."${repo_name}/master" | xargs git cherry-pick
    fi

    # Now reset our tracking branch to the latest commit we've (just) cherry picked
    git checkout "_${repo_name}"
    git reset --hard "${repo_name}/master"
    git checkout master
done

# Fully consistent again
rm -f "$REPO_SNAPSHOT_FILE"

# Now we're fully up to date.  Push to git!
git remote rm origin 2>/dev/null || true
git remote add origin "$GIT_REMOTE"

#git push origin master
