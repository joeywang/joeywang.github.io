#!/usr/bin/env bash
set -euo pipefail

# Setup Codex compatibility for blog workflow
# Run this if you want to use Google Codex in addition to Claude Code

echo "🔧 Setting up Codex compatibility..."

# Create Codex directories
echo "📁 Creating .codex directories..."
mkdir -p .codex/skills .codex/agents

# Copy skills from Claude to Codex
echo "📋 Copying skills..."
if [ -d ".claude/skills" ]; then
  cp -r .claude/skills/* .codex/skills/
  echo "  ✅ Skills copied"
else
  echo "  ⚠️  No .claude/skills directory found"
fi

# Copy agents
echo "📋 Copying agents..."
if [ -d ".claude/agents" ]; then
  cp -r .claude/agents/* .codex/agents/
  echo "  ✅ Agents copied"
else
  echo "  ⚠️  No .claude/agents directory found"
fi

# Create Codex config
echo "⚙️  Creating .codex/config.json..."
cat > .codex/config.json << 'EOF'
{
  "project": {
    "name": "joeywang.github.io",
    "type": "jekyll-blog",
    "language": "markdown"
  },
  "permissions": {
    "allowedCommands": [
      "bundle",
      "bundle exec jekyll",
      "git",
      "ls",
      "cat"
    ],
    "allowedPaths": [
      "_posts/**/*.md",
      "static/**/*.md",
      "_drafts/**/*.md"
    ]
  },
  "hooks": {
    "afterFileWrite": {
      "_posts/*.md": "echo '\n✅ Blog post created! Preview: bundle exec jekyll serve'"
    },
    "beforeFileEdit": {
      "_config.yml": "echo '⚠️  Editing main Jekyll config. Continue? (y/n)'",
      ".github/workflows/*": "echo '⚠️  Editing GitHub Actions. Continue? (y/n)'"
    }
  }
}
EOF
echo "  ✅ Config created"

# Verify setup
echo ""
echo "✅ Codex setup complete!"
echo ""
echo "Directory structure:"
tree -L 2 .codex/ 2>/dev/null || ls -la .codex/

echo ""
echo "📚 Next steps:"
echo ""
echo "1. Test Codex:"
echo "   codex chat"
echo "   > /blog-workflow"
echo ""
echo "2. Read Codex guide:"
echo "   cat CODEX.md"
echo ""
echo "3. (Optional) Commit Codex config:"
echo "   git add .codex/ CODEX.md setup-codex.sh"
echo "   git commit -m 'Add Codex compatibility'"
echo ""
echo "4. Or symlink to keep skills in sync:"
echo "   rm -rf .codex/skills .codex/agents"
echo "   ln -s .claude/skills .codex/skills"
echo "   ln -s .claude/agents .codex/agents"
echo ""
