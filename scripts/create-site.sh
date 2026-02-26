#!/bin/bash
#
# Push this site to GitHub and enable GitHub Pages deployment
# Usage: ./scripts/create-site.sh
#
# This will:
# 1. Initialize git (if needed) and commit all files
# 2. Create a new repo in the wangenconsulting organization
# 3. Push the initial commit
# 4. Enable GitHub Pages with GitHub Actions as the source
#

set -e

GITHUB_ORG="wangenconsulting"
SITE_NAME="parken-treningssenter"
SITE_DIR="$(cd "$(dirname "$0")/.." && pwd)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[0;33m'
NC='\033[0m'

print_step() {
    echo -e "${BLUE}==>${NC} $1"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}!${NC} $1"
}

# Check if gh CLI is available and authenticated
if ! command -v gh &> /dev/null; then
    print_error "GitHub CLI (gh) is not installed. Install it with: brew install gh"
    exit 1
fi

if ! gh auth status &> /dev/null; then
    print_error "Not authenticated with GitHub CLI. Run: gh auth login"
    exit 1
fi

# Check if user has access to the organization
if ! gh org list 2>/dev/null | grep -q "$GITHUB_ORG"; then
    print_error "You don't have access to the $GITHUB_ORG organization"
    exit 1
fi

cd "$SITE_DIR"

echo ""
echo "Deploying: $SITE_NAME"
echo "─────────────────────────────────────"
echo ""

# Step 1: Initialize git if needed
if [ ! -d .git ]; then
    print_step "Initializing git repository..."
    git init -q
    print_success "Git repository initialized"
else
    print_success "Git repository already initialized"
fi

# Step 2: Commit all files
print_step "Staging and committing files..."
git add .
if git diff --cached --quiet 2>/dev/null; then
    print_warning "No new changes to commit"
else
    git commit -q -m "Initial commit"
    print_success "Files committed"
fi

# Step 3: Create GitHub repo and push
print_step "Creating GitHub repository in $GITHUB_ORG..."
if gh repo view "$GITHUB_ORG/$SITE_NAME" &>/dev/null; then
    print_warning "Repository already exists, pushing to existing repo..."
    git remote remove origin 2>/dev/null || true
    git remote add origin "https://github.com/$GITHUB_ORG/$SITE_NAME.git"
    git push -u origin main
    print_success "Pushed to existing repository"
else
    if gh repo create "$GITHUB_ORG/$SITE_NAME" --public --source=. --push; then
        print_success "GitHub repository created and pushed"
    else
        print_error "Failed to create GitHub repository"
        exit 1
    fi
fi

# Step 4: Enable GitHub Pages with Actions as source
print_step "Enabling GitHub Pages..."
if gh api \
    --method POST \
    -H "Accept: application/vnd.github+json" \
    "/repos/$GITHUB_ORG/$SITE_NAME/pages" \
    -f "build_type=workflow" 2>/dev/null; then
    print_success "GitHub Pages enabled (source: GitHub Actions)"
else
    # Pages might already be enabled, try updating instead
    if gh api \
        --method PUT \
        -H "Accept: application/vnd.github+json" \
        "/repos/$GITHUB_ORG/$SITE_NAME/pages" \
        -f "build_type=workflow" 2>/dev/null; then
        print_success "GitHub Pages updated (source: GitHub Actions)"
    else
        print_warning "Could not enable Pages via API. Enable manually:"
        print_warning "  Settings → Pages → Source → GitHub Actions"
    fi
fi

echo ""
echo "─────────────────────────────────────"
echo ""
print_success "Site deployed successfully!"
echo ""
echo "  Repo:  https://github.com/$GITHUB_ORG/$SITE_NAME"
echo "  Site:  https://$GITHUB_ORG.github.io/$SITE_NAME/"
echo ""
echo "The site will auto-deploy when you push to main."
echo ""
