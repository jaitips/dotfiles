#!/bin/bash
# ============================================================
# Claude Code Skills Installer for Keyspace IoT Platform
# - Multi-skill per repo -- single clone
# - Non-interactive -- -g -a claude-code -y
# - Skips installed skills
# - Updates outdated skills
# - Installation report saved to file
# ============================================================

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
GRAY='\033[0;90m'
CYAN='\033[0;36m'
NC='\033[0m'

log() { echo -e "${GREEN}[OK]${NC} $1"; }
info() { echo -e "${BLUE}-->${NC} $1"; }
warn() { echo -e "${YELLOW}[!!]${NC} $1"; }
skip() { echo -e "${GRAY}[SKIP]${NC} $1"; }
upd() { echo -e "${CYAN}[UPD]${NC} $1"; }

# --- Report tracking ---
INSTALLED=()
SKIPPED=()
FAILED=()
UPDATED=()

# ============================================================
echo ""
echo "============================================================"
echo "  Claude Code Skills Installer -- Keyspace IoT Platform"
echo "============================================================"
echo ""

if ! command -v npx &>/dev/null; then
  echo -e "${RED}[ERR]${NC} npx not found. Install Node.js first."
  exit 1
fi

log "npx found"

# --- Build installed skills cache ---
info "Scanning installed skills..."
INSTALLED_CACHE=$(npx skills list -g 2>/dev/null || echo "")
echo ""

skill_exists() {
  local name="$1"
  if echo "${INSTALLED_CACHE}" | grep -qw "${name}"; then
    return 0
  fi
  for dir in "$HOME/.agents/skills" ".agents/skills" "$HOME/.claude/skills" ".claude/skills"; do
    if [ -d "${dir}/${name}" ] || [ -L "${dir}/${name}" ]; then
      return 0
    fi
  done
  return 1
}

# Install multiple skills from one repo
# Usage: install_repo "owner/repo" skill1 skill2 ...
install_repo() {
  local repo="$1"
  shift
  local all_skills=("$@")
  local to_install=()

  for skill in "${all_skills[@]}"; do
    if skill_exists "${skill}"; then
      skip "${skill}"
      SKIPPED+=("${skill}")
    else
      to_install+=("${skill}")
    fi
  done

  if [ ${#to_install[@]} -eq 0 ]; then
    return
  fi

  local skill_flags=""
  for skill in "${to_install[@]}"; do
    skill_flags="${skill_flags} --skill ${skill}"
  done

  info "Installing from ${repo}: ${to_install[*]}"
  if npx skills add "https://github.com/${repo}" ${skill_flags} -g -a claude-code -y; then
    for skill in "${to_install[@]}"; do
      if skill_exists "${skill}"; then
        log "${skill}"
        INSTALLED+=("${skill}")
      else
        warn "Failed: ${skill}"
        FAILED+=("${skill}")
      fi
    done
  else
    for skill in "${to_install[@]}"; do
      if skill_exists "${skill}"; then
        log "${skill}"
        INSTALLED+=("${skill}")
      else
        warn "Failed: ${skill}"
        FAILED+=("${skill}")
      fi
    done
  fi
  echo ""
}

# ----------------------------------------------------------
# Install skills grouped by repo
# ----------------------------------------------------------

echo -e "${BLUE}--- [1/11] Jeffallan/claude-skills ---${NC}"
install_repo "Jeffallan/claude-skills" \
  nestjs-expert \
  monitoring-expert

echo -e "${BLUE}--- [2/11] kadajett/agent-nestjs-skills ---${NC}"
install_repo "kadajett/agent-nestjs-skills" \
  nestjs-best-practices

echo -e "${BLUE}--- [3/11] hoodini/ai-agents-skills ---${NC}"
install_repo "hoodini/ai-agents-skills" \
  mongodb

echo -e "${BLUE}--- [4/11] vercel-labs/agent-skills ---${NC}"
install_repo "vercel-labs/agent-skills" \
  vercel-react-best-practices \
  web-design-guidelines

echo -e "${BLUE}--- [5/11] vercel-labs/next-skills ---${NC}"
install_repo "vercel-labs/next-skills" \
  next-best-practices

echo -e "${BLUE}--- [6/11] vercel-labs/agent-browser ---${NC}"
install_repo "vercel-labs/agent-browser" \
  agent-browser \
  dogfood

echo -e "${BLUE}--- [7/11] figma/mcp-server-guide ---${NC}"
install_repo "figma/mcp-server-guide" \
  figma-implement-design \
  figma-code-connect-components \
  figma-create-design-system-rules \
  figma-use

echo -e "${BLUE}--- [8/11] anthropics/skills ---${NC}"
install_repo "anthropics/skills" \
  frontend-design

echo -e "${BLUE}--- [9/11] microsoft/azure-skills ---${NC}"
install_repo "microsoft/azure-skills" \
  azure-aks \
  azure-app-service \
  azure-container-apps \
  azure-cosmos-db \
  azure-functions \
  azure-kubernetes-service \
  azure-monitor \
  azure-resource-graph \
  azure-storage

echo -e "${BLUE}--- [10/11] Code quality ---${NC}"
install_repo "vdustr/vp-claude-code-marketplace" \
  typescript-best-practices

install_repo "awesome-skills/code-review-skill" \
  code-review-excellence

install_repo "sickn33/antigravity-awesome-skills" \
  lint-and-validate

install_repo "currents-dev/playwright-best-practices-skill" \
  playwright-best-practices

echo -e "${BLUE}--- [11/11] Debugging & Planning ---${NC}"
install_repo "obra/superpowers" \
  systematic-debugging

install_repo "OthmanAdi/planning-with-files" \
  planning-with-files

# ----------------------------------------------------------
# Update check for already installed skills
# ----------------------------------------------------------
echo ""
echo -e "${BLUE}--- Checking for updates on installed skills ---${NC}"
echo ""

UPDATE_OUTPUT=$(npx skills check 2>/dev/null || echo "")

if echo "${UPDATE_OUTPUT}" | grep -q "update"; then
  echo "${UPDATE_OUTPUT}"
  echo ""
  info "Updating all outdated skills..."
  if npx skills update 2>/dev/null; then
    # Parse updated skill names from output
    while IFS= read -r line; do
      if echo "${line}" | grep -qi "updated\|Updated"; then
        skill_name=$(echo "${line}" | grep -oP '(?:Updated |updated )(\S+)' | awk '{print $NF}')
        if [ -n "${skill_name}" ]; then
          upd "${skill_name}"
          UPDATED+=("${skill_name}")
        fi
      fi
    done <<<"$(npx skills update 2>/dev/null)"
    if [ ${#UPDATED[@]} -eq 0 ]; then
      upd "Update command ran -- check npx skills list for changes"
      UPDATED+=("see-npx-skills-list")
    fi
  else
    warn "npx skills update had issues -- run manually: npx skills update"
  fi
else
  log "All installed skills are up to date"
fi

# ============================================================
# Installation Report
# ============================================================
TOTAL=$((${#INSTALLED[@]} + ${#SKIPPED[@]} + ${#FAILED[@]}))
REPORT_FILE="$HOME/.claude/skill-install-report.txt"
mkdir -p "$(dirname "${REPORT_FILE}")"

echo ""
echo "============================================================"
echo "  INSTALLATION REPORT"
echo "============================================================"
echo ""
printf "  %-18s %s\n" "Total skills:" "${TOTAL}"
printf "  ${GREEN}%-18s %s${NC}\n" "New installs:" "${#INSTALLED[@]}"
printf "  ${GRAY}%-18s %s${NC}\n" "Already there:" "${#SKIPPED[@]}"
printf "  ${CYAN}%-18s %s${NC}\n" "Updated:" "${#UPDATED[@]}"
printf "  ${RED}%-18s %s${NC}\n" "Failed:" "${#FAILED[@]}"
echo ""

if [ ${#INSTALLED[@]} -gt 0 ]; then
  echo -e "  ${GREEN}Newly installed:${NC}"
  for s in "${INSTALLED[@]}"; do echo -e "    ${GREEN}+${NC} ${s}"; done
  echo ""
fi

if [ ${#SKIPPED[@]} -gt 0 ]; then
  echo -e "  ${GRAY}Already installed:${NC}"
  for s in "${SKIPPED[@]}"; do echo -e "    ${GRAY}= ${s}${NC}"; done
  echo ""
fi

if [ ${#UPDATED[@]} -gt 0 ]; then
  echo -e "  ${CYAN}Updated:${NC}"
  for s in "${UPDATED[@]}"; do echo -e "    ${CYAN}^ ${s}${NC}"; done
  echo ""
fi

if [ ${#FAILED[@]} -gt 0 ]; then
  echo -e "  ${RED}Failed:${NC}"
  for s in "${FAILED[@]}"; do echo -e "    ${RED}x ${s}${NC}"; done
  echo ""
  echo "  Debug: npx skills add https://github.com/REPO --list"
  echo ""
fi

echo "------------------------------------------------------------"
echo "  MANUAL STEPS"
echo "------------------------------------------------------------"
echo ""
echo "  Browser CLI: npm install -g agent-browser && agent-browser install"
echo "  Figma MCP:   claude plugin install figma@claude-plugins-official"
echo "  TS lint:     npm install -g @juanpprieto/claude-lsp"
echo ""
echo "  Built-in:    /simplify  /review"
echo "  Missing:     MQTT/EMQX, NATS, KNX -- custom skill needed"
echo ""

# Save report
{
  echo "Claude Code Skills Install Report"
  echo "Date: $(date)"
  echo "=================================="
  echo ""
  echo "Installed  ${#INSTALLED[@]}:"
  for s in "${INSTALLED[@]}"; do echo "  + ${s}"; done
  echo ""
  echo "Skipped    ${#SKIPPED[@]}:"
  for s in "${SKIPPED[@]}"; do echo "  = ${s}"; done
  echo ""
  echo "Updated    ${#UPDATED[@]}:"
  for s in "${UPDATED[@]}"; do echo "  ^ ${s}"; done
  echo ""
  echo "Failed     ${#FAILED[@]}:"
  for s in "${FAILED[@]}"; do echo "  x ${s}"; done
} >"${REPORT_FILE}"

echo "Report: ${REPORT_FILE}"
echo "Restart Claude Code to activate new skills."
echo ""
