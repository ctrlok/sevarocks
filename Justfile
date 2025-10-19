# Justfile for sevarocks

# Sync static/images folder and favicon with Cloudflare R2
sync-static:
    rclone sync static/images/ cloudflare:/static-sevarocks/images
    rclone sync static/icon/ cloudflare:/static-sevarocks/icon

# Check for image links in posts that are not using static.seva.rocks
check-images:
    @grep -rn "!\[.*\](" content/posts/ | grep -v "https://static.seva.rocks/" | grep -E '\.(png|jpg|jpeg|gif|webp|svg)' || echo "All images use static.seva.rocks"

# Replace local image paths with https://static.seva.rocks/images/
fix-images:
    find content/posts/ -type f -name "*.md" -exec sed -i '' 's|!\[\([^]]*\)\](/images/\([^)]*\))|![\1](https://static.seva.rocks/images/\2)|g' {} \;

# Link pechersk theme from ../zola-pechersk
link-theme:
    rm -rf themes/pechersk
    ln -s ../../../zola-pechersk themes/pechersk

# Check if the pechersk theme submodule has updates available
check-theme-updates:
    #!/usr/bin/env bash
    set -euo pipefail

    echo "🔍 Checking pechersk theme status..."

    # Navigate to the submodule directory
    # Just runs from the directory containing the Justfile
    cd "../zola-pechersk"

    # Get remote main commit
    REMOTE_MAIN=$(jj log -r 'main@origin' --no-graph --template 'commit_id' 2>/dev/null || echo "unknown")
    if [ "$REMOTE_MAIN" = "unknown" ]; then
        echo "❌ Error: Cannot find remote/main. Make sure the submodule is properly initialized."
        exit 1
    fi

    # Get local main commit
    LOCAL_MAIN=$(jj log -r 'main' --no-graph --template 'commit_id' 2>/dev/null )
    if [ "$LOCAL_MAIN" = "unknown" ]; then
        echo "❌ Error: Cannot find local main branch."
        exit 1
    fi

    REMOTE_MAIN_SHORT=$(echo "$REMOTE_MAIN" | cut -c1-8)
    LOCAL_MAIN_SHORT=$(echo "$LOCAL_MAIN" | cut -c1-8)
    echo "Remote main: $REMOTE_MAIN_SHORT"
    echo "Local main:  $LOCAL_MAIN_SHORT"

    # Check if local main differs from remote main
    if [ "$LOCAL_MAIN" != "$REMOTE_MAIN" ]; then
        echo "❌ Error: Local main differs from remote/main!"
        echo "   This means there are unpushed changes in the submodule."
        echo "   Push them first: cd themes/pechersk && git push origin main"
        exit 1
    fi

    # Check current commit status
    CURRENT_EMPTY=$(jj log -r @ --no-graph --template 'empty' 2>/dev/null || echo "unknown")

    if [ "$CURRENT_EMPTY" = "true" ]; then
        # If current commit is empty, check the parent
        echo "Current commit is empty (jj working copy)"
        PARENT_COMMIT=$(jj log -r @- --no-graph --template 'commit_id' 2>/dev/null || echo "unknown")
        CHECK_COMMIT="$PARENT_COMMIT"
        PARENT_SHORT=$(echo "$PARENT_COMMIT" | cut -c1-8)
        echo "Checking parent: $PARENT_SHORT"
    else
        # If current commit is not empty, use it
        CURRENT_COMMIT=$(jj log -r @ --no-graph --template 'commit_id' 2>/dev/null || echo "unknown")
        CHECK_COMMIT="$CURRENT_COMMIT"
        CURRENT_SHORT=$(echo "$CURRENT_COMMIT" | cut -c1-8)
        echo "Checking current: $CURRENT_SHORT"
    fi

    # Check if the commit matches remote/main
    if [ "$CHECK_COMMIT" = "$REMOTE_MAIN" ]; then
        echo "✅ Submodule is up to date with remote/main"
    else
        echo "❌ Remote repo has not pushed commits"
        exit 2
    fi

# Update the pechersk theme submodule to the latest version
update-submodule: check-theme-updates
    #!/usr/bin/env bash
    set -euo pipefail

    echo "📦 Updating pechersk theme submodule..."

    # Store the current jj commit for reference
    CURRENT_JJ_COMMIT=$(jj log -r @ --no-graph --template 'change_id' 2>/dev/null)
    echo "Current jj commit: $CURRENT_JJ_COMMIT"

    # Find the nearest ancestor with a git branch/bookmark
    # This handles cases where you have multiple commits after the branch point
    echo "Looking for nearest ancestor with a git branch..."

    # Get the first ancestor (including current and parent) that has a bookmark
    # This will walk back through the history until it finds a commit with a branch
    PARENT_BRANCH=$(jj log -r 'ancestors(@) & bookmarks()' --no-graph --template 'bookmarks' --limit 1 2>/dev/null)

    # If no bookmarks found in ancestors, this is a problem
    if [ -z "$PARENT_BRANCH" ] || [ "$PARENT_BRANCH" = "(no bookmarks set)" ]; then
        echo "❌ Error: No git branch found in ancestors. Make sure you're on a branch."
        echo "   You may need to create a branch first with: jj bookmark create <branch-name>"
        exit 1
    fi

    echo "Found branch: $PARENT_BRANCH"

    # Checkout the branch to make sure git is at the right commit
    git checkout "$PARENT_BRANCH"

    # Update the submodule
    echo "Updating submodule..."
    git submodule update --init --recursive --remote

    # Check if there are changes
    if git status --porcelain | grep -q "themes/pechersk"; then
        echo "✅ Submodule has updates, committing..."
        git commit -a -m "update submodule"

        # Get the new git commit that was created
        NEW_GIT_COMMIT=$(git rev-parse HEAD)
        echo "New git commit: $(echo $NEW_GIT_COMMIT | cut -c1-8)"

        # Find the jj change for the new git commit
        NEW_JJ_CHANGE=$(jj log --no-graph --template 'change_id' -r "commit_id(\"$NEW_GIT_COMMIT\")" 2>/dev/null)

        echo "Squashing update into current jj commit..."
        echo "From: $NEW_JJ_CHANGE"
        echo "Into: $CURRENT_JJ_COMMIT"

        # # Squash the new commit into the current one
        echo "Example command for squashing:"
        echo jj squash --from "$NEW_JJ_CHANGE" --into "$CURRENT_JJ_COMMIT"

        echo "✅ Submodule updated and squashed into current commit!"
    else
        echo "ℹ️  No submodule updates needed"
    fi

    echo "🎉 Done!"
