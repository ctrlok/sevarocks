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
