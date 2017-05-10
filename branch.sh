#!/usr/bin/env bash

__die() {
    ret=$?
    message=${1-"[Failed (${ret})]"}
    echo ${message}
    exit ${ret}
}

__fail() {
    local ret=$?
    local message=${1-"[Failed (${ret})]"}
    echo ${message}
    return ${ret}
}

__warn() {
    message=$1
    echo ${message}
}

__ok() {
    echo "[OK]"
}

__requireArgument() {
    test -z "${!1}" && __die "Missing argument '${1}' ${2}"
}

start() {
    type=${1}
    id=${2}
    message=${3}
    __requireArgument 'type' '(feature or bugfix)'
    __requireArgument 'id'
    __requireArgument 'message'
    [ "$(__currentBranch)" == "$(__masterBranch)" ] || __die "Work branch must be created from \"$(__masterBranch)\""
    __fetchMasterBranch
    [ -z "$(git diff --summary FETCH_HEAD)" ] || __die "Local branch and remote diverges"
    workBranch="${type}/${id}"
    git checkout -b ${workBranch}
    __editChangesLog "${message}"
}

__info() {
    __isWorkBranch || echo "$(__currentBranch) is not a work branch"
    echo "Change log entry: $(change)"
}

qa() {
    isIntegratable || __die "QA requires branch to be integratable."
    git commit --allow-empty -m "qa!"
    publish
}

review() {
    echo "Create review branch..."
    isIntegratable || __die "Review requires branch to be integratable."
    workBranch=$(__currentBranch)
    reviewBranch=review/$workBranch
    echo -n "Fetching origin master"
    __fetchMasterBranch && __ok || __die "Failed to fetch $(__masterBranch)"
    echo -n "Creating review branch $reviewBranch: "
    git checkout -b $reviewBranch origin/$(__masterBranch) && __ok || __die "Failed to create $reviewBranch"
    echo -n "Merging $workBranch... "
    git merge --ff-only --squash ${workBranch} && __ok || __die
    echo -n "Committing... "
    git commit -m "$(change)"
    echo -n "Pushing $reviewBranch"
    git push -f -u origin $(__currentBranch)
    echo "Switching back to $workBranch"
    git checkout $workBranch
    echo "Removing local review branch"
    git branch -D $reviewBranch
}

__editChangesLog() {
    message=${1}
    __requireArgument 'message'
    logEntry="$(__currentBranch): ${message}" # TODO: Enforce max 50 char message
    tmpDir=$(mktemp -d "${TMPDIR:-/tmp}/XXXXXXXXXXXX")
    tmpFile="${tmpDir}/Changes.txt"
    echo "${logEntry}" | cat - $(__changesFile) > ${tmpFile} && mv ${tmpFile} $(__changesFile) || __die
    rm -r ${tmpDir}
    git add $(__changesFile)
    git commit -m "${logEntry}"
}

integrate() {
    echo "Integrating branch..."
    isIntegratable || __die "Branch is currently not integratable."
    workBranch=$(__currentBranch)
    reviewBranch=review/$workBranch
    echo -n "Checking out branch $(__masterBranch): "
    git checkout $(__masterBranch) && __ok || __die "Failed to check out branch $(__masterBranch)"
    echo -n "Updating branch $(__masterBranch): "
    git pull && __ok || __die "Failed to update branch $(__masterBranch)"
    echo -n "Merging into $(__masterBranch)... "
    git merge --ff-only --squash ${workBranch} && __ok || __die
    echo -n "Committing... "
    git commit -m "$(change)"
    echo -n "Pushing $(__masterBranch) with new code..."
    git push && __ok || __die
    echo -n "Deleting work branch on remote... "
    git push origin --delete ${workBranch} && __ok || __die
    echo -n "Deleting work branch locally... "
    git branch -D ${workBranch}
    echo -n "Deleting remote review branch... "
    git push origin --delete $reviewBranch && __ok || __warn
}

isIntegratable() {
    echo -n "Fetching from origin: "
    git fetch origin && __ok || { __fail; return 1; }
    workBranch=$(__currentBranch)
    echo -n "Verifying that branch ${workBranch} is a bugfix/feature branch: "
    __isWorkBranch && __ok || { echo "${workBranch} is not a bugfix/feature branch"; return 1; }
    echo -n "Verifying that branch ${workBranch} has no unstaged changes: "
    git diff-files --quiet -- && __ok || { echo "Found unstaged changes."; return 1; }
    echo -n "Verifying that branch ${workBranch} has no staged changes: "
    git diff-index --quiet --cached HEAD && __ok || { echo "Found staged changes."; return 1; }
    echo -n "Verifying that branch ${workBranch} is synchronized with remote branch: "
    __isSynchronizedWithRemote && __ok || { echo "Local branch and remote diverges"; return 1; }
    echo -n "Verifying that branch ${workBranch} contains origin/$(__masterBranch): "
    git branch --contains origin/$(__masterBranch) | grep ${workBranch} > /dev/null && __ok || { echo "No. Please run 'git merge origin/$(__masterBranch)'."; return 1; }
}

__isSynchronizedWithRemote() {
    [[ -z $(git --no-pager diff origin/$(__currentBranch)) ]]
}

__isWorkBranch() {
    [[ $(__currentBranch) =~ (bugfix|feature)/.+ ]]
}

__fetchMasterBranch() {
    git fetch -q origin $(__masterBranch) > /dev/null
}

__currentBranch() {
    git symbolic-ref --short -q HEAD
}

__masterBranch() {
    echo 'master'
}

__changesFile() {
    echo 'doc/Changes.txt'
}

change() {
    head -1 $(__changesFile)
}

publish() {
    git push -u origin $(__currentBranch)
}

usage() {
    echo "usage: $(__name) <command> [<args>]"
    echo
    echo "Available commands:"
    echo "  start TYPE ISSUE_ID MESSAGE"
    echo "      Start a new working branch of type TYPE, which will resolve the issue with id ISSUE_ID. MESSAGE will be"
    echo "      recorded in the final revision log entry in mainline. TYPE can be one of 'feature' or 'bugfix'"
    echo
    echo "  publish"
    echo "      Publish the branch so others can work on it (push to origin)."
    echo
    echo "  integrate"
    echo "      Integrate the current working branch with mainline. The working branch will then be deleted (also on origin)."
    echo
    echo "  isIntegratable"
    echo "      Check if current working branch is integratable. A non-zero exit code is returned if not."
}

__name() {
    echo "$(basename "$0")"
}

case $1 in *)
        function=$1
        shift
        if [ "function" = "$(type -t ${function})" ]
        then
            ${function} "$@"
        else
            >&2 echo "Unknown command ${function}"
            usage
        fi
        ;;
esac
