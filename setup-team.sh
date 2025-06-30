#!/bin/bash

# AI Team Setup Script
# 
# Sets up AI development team workflow using tmux.
# Creates panes based on team-config.yml configuration.
#
# Required environment variables:
#   REPO_BASE_DIR   - Base directory for repositories (e.g. $HOME/ghq/github.com)
#   GITHUB_ORG      - GitHub organization name
#   SPEC_REPO_NAME  - Specification repository name
#   IMPL_REPO_NAME  - Implementation repository name
#
# Optional environment variables:
#   ROLE_DIR        - Directory for role definition files (default: ./roles)
#   TEAM_CONFIG     - Path to team configuration file (default: ./team-config.yml)
#
# Usage:
#   # Set environment variables before running
#   export REPO_BASE_DIR=$HOME/ghq/github.com
#   export GITHUB_ORG=myorg
#   export SPEC_REPO_NAME=myorg-specifications
#   export IMPL_REPO_NAME=myorg-app
#   ./setup-team.sh              # Use default repositories
#   ./setup-team.sh 2            # Use worktree 2

# .envファイルが存在する場合は読み込む
if [ -f .env ]; then
    echo "Loading .env file..."
    # .envファイルを読み込む（export文を評価）
    set -a
    source .env
    set +a
fi

# 環境変数の確認（必須）
if [ -z "$REPO_BASE_DIR" ]; then
    echo "Error: Please set REPO_BASE_DIR environment variable"
    echo "Example: export REPO_BASE_DIR=\$HOME/ghq/github.com"
    exit 1
fi

if [ -z "$GITHUB_ORG" ]; then
    echo "Error: Please set GITHUB_ORG environment variable"
    echo "Example: export GITHUB_ORG=your-org-name"
    exit 1
fi

if [ -z "$SPEC_REPO_NAME" ]; then
    echo "Error: Please set SPEC_REPO_NAME environment variable"
    echo "Example: export SPEC_REPO_NAME=your-spec-repo"
    exit 1
fi

if [ -z "$IMPL_REPO_NAME" ]; then
    echo "Error: Please set IMPL_REPO_NAME environment variable"
    echo "Example: export IMPL_REPO_NAME=your-impl-repo"
    exit 1
fi

# Set default values for optional variables
: ${ROLE_DIR:="./roles"}
: ${TEAM_CONFIG:="./team-config.yml"}

# 引数チェック
if [ $# -eq 0 ]; then
    # 引数なしの場合はデフォルト
    SUFFIX=""
else
    # 引数ありの場合は数字を付加
    SUFFIX="$1"
fi

# リポジトリのパス（環境変数から構築）
SPEC_REPO="${REPO_BASE_DIR}/${GITHUB_ORG}/${SPEC_REPO_NAME}${SUFFIX}"
IMPL_REPO="${REPO_BASE_DIR}/${GITHUB_ORG}/${IMPL_REPO_NAME}${SUFFIX}"

# 環境変数の設定状況を表示
echo "Environment variables:"
echo "  REPO_BASE_DIR: $REPO_BASE_DIR"
echo "  GITHUB_ORG: $GITHUB_ORG"
echo "  SPEC_REPO_NAME: $SPEC_REPO_NAME"
echo "  IMPL_REPO_NAME: $IMPL_REPO_NAME"
echo "  ROLE_DIR: $ROLE_DIR"
echo "  TEAM_CONFIG: $TEAM_CONFIG"
echo ""

# リポジトリの存在確認
if [ ! -d "$SPEC_REPO" ]; then
    echo "Error: Specification repository not found: $SPEC_REPO"
    exit 1
fi

if [ ! -d "$IMPL_REPO" ]; then
    echo "Error: Implementation repository not found: $IMPL_REPO"
    exit 1
fi

# Check role directory exists
if [ ! -d "$ROLE_DIR" ]; then
    echo "Error: Role definition directory not found: $ROLE_DIR"
    exit 1
fi

# Check team config exists
if [ ! -f "$TEAM_CONFIG" ]; then
    echo "Error: Team configuration file not found: $TEAM_CONFIG"
    echo "Please create a team-config.yml file or copy team-config.example.yml"
    exit 1
fi

# Check for yq (YAML processor)
if ! command -v yq &> /dev/null; then
    echo "Error: yq is required to parse YAML files"
    echo "Install with: brew install yq (macOS) or see https://github.com/mikefarah/yq"
    exit 1
fi

# Read team configuration
echo "Reading team configuration from $TEAM_CONFIG..."

# Read roles into array (compatible with older bash versions)
ROLES=()
while IFS= read -r role; do
    ROLES+=("$role")
done < <(yq e '.team[]' "$TEAM_CONFIG" 2>/dev/null)

if [ ${#ROLES[@]} -eq 0 ]; then
    echo "Error: No roles defined in $TEAM_CONFIG"
    echo "Please check your team-config.yml file format"
    exit 1
fi

echo "Found ${#ROLES[@]} roles in configuration:"
for i in "${!ROLES[@]}"; do
    echo "  Pane $((i+2)): ${ROLES[$i]}"
done
echo ""

# 現在のウィンドウとセッション情報を取得
CURRENT_SESSION=$(tmux display-message -p '#S')
CURRENT_WINDOW=$(tmux display-message -p '#I')

# 現在のpane数を確認
PANE_COUNT=$(tmux list-panes | wc -l)

if [ $PANE_COUNT -ne 1 ]; then
    echo "Error: This script must be run with exactly one pane."
    exit 1
fi

# pane1 is reserved for control
echo "Creating panes..."

# Create panes for each role in config
PANE_NUMBER=2
# Arrays to store pane information
declare -a PANE_NUMBERS
declare -A PANE_ROLES
declare -A PANE_REPOS
declare -A PANE_ROLE_NAMES
declare -A PANE_ROLE_FILES

# Track role instance numbers for duplicate roles
declare -A ROLE_COUNTS

for role in "${ROLES[@]}"; do
    echo "Processing role: $role"
    
    # Find the role file
    role_file="$ROLE_DIR/${role}.md"
    
    if [ ! -f "$role_file" ]; then
        echo "Error: Role file not found: $role_file"
        exit 1
    fi
    
    # Increment role instance count
    if [ -z "${ROLE_COUNTS[$role]}" ]; then
        ROLE_COUNTS[$role]=1
    else
        ROLE_COUNTS[$role]=$((ROLE_COUNTS[$role] + 1))
    fi
    
    # Extract role name from file
    role_name=$(grep -m 1 "^# " "$role_file" | sed 's/^# //')
    if [ -z "$role_name" ]; then
        role_name=$role
    fi
    
    # Add instance number if multiple instances
    if [ ${ROLE_COUNTS[$role]} -gt 1 ]; then
        role_name="${role_name} ${ROLE_COUNTS[$role]}"
    fi
    
    # ファイル内容から必要なリポジトリを判定
    # {{IMPL_REPO}}を含むファイルはIMPL_REPO、それ以外はSPEC_REPOを使用
    if grep -q "{{IMPL_REPO}}" "$role_file"; then
        target_repo="$IMPL_REPO"
        repo_type="implementation repository"
    else
        target_repo="$SPEC_REPO"
        repo_type="specification repository"
    fi
    
    # paneを作成（常に垂直分割）
    tmux split-window -h -c "$target_repo"
    
    # Claudeを起動
    tmux send-keys -t "$CURRENT_SESSION:$CURRENT_WINDOW.$PANE_NUMBER" "claude --dangerously-skip-permissions" C-m
    sleep 3
    
    # Save pane information
    PANE_NUMBERS+=($PANE_NUMBER)
    PANE_ROLES[$PANE_NUMBER]="$role"
    PANE_ROLE_FILES[$PANE_NUMBER]="$role_file"
    PANE_REPOS[$PANE_NUMBER]="$repo_type"
    PANE_ROLE_NAMES[$PANE_NUMBER]="$role_name"
    
    PANE_NUMBER=$((PANE_NUMBER + 1))
done

# Adjust layout to tiled format for better organization
echo "Adjusting pane layout to tiled..."
tmux select-layout -t "$CURRENT_SESSION:$CURRENT_WINDOW" tiled

echo "Assigning roles..."

# Send roles to each pane
for pane_num in "${PANE_NUMBERS[@]}"; do
    role_file="${PANE_ROLE_FILES[$pane_num]}"
    
    # Create communication section
    COMM_SECTION="

## Team Members and Communication

To send messages: \`tmux send-keys -t ${CURRENT_SESSION}:${CURRENT_WINDOW}.[pane] 'message'\` then \`tmux send-keys -t ${CURRENT_SESSION}:${CURRENT_WINDOW}.[pane] C-m\`

### Role-Pane Mapping

| Role Name | Pane Number |
|-----------|-------------|
| Control Panel | 1 |"
    
    for mapping_pane in "${PANE_NUMBERS[@]}"; do
        mapping_role="${PANE_ROLE_NAMES[$mapping_pane]}"
        COMM_SECTION="${COMM_SECTION}
| ${mapping_role} | ${mapping_pane} |"
    done
    
    # Create session info section
    SESSION_INFO="

## Session Information

- Current session: ${CURRENT_SESSION}
- Current window: ${CURRENT_WINDOW}
- Your pane number: ${pane_num}"
    
    # ロール内容を読み込み、変数を置換
    ROLE_CONTENT=$(sed -e "s/{{SESSION}}/$CURRENT_SESSION/g" \
                      -e "s/{{WINDOW}}/$CURRENT_WINDOW/g" \
                      -e "s|{{IMPL_REPO}}|$IMPL_REPO|g" \
                      -e "s|{{SPEC_REPO}}|$SPEC_REPO|g" \
                      "$role_file")
    
    # Remove existing communication and session info sections
    ROLE_CONTENT=$(echo "$ROLE_CONTENT" | sed '/^## Communication/,/^## Session Info/d' | sed '/^## Session Info/,/^##\|$/d')
    
    # Combine role information with common rules
    FULL_CONTENT="<system_instruction>
<critical_initial_state>WAITING MODE - DO NOT START ANY WORK</critical_initial_state>

<waiting_mode_rules>
<current_status>You are in WAITING MODE and must not take any action</current_status>
<prohibited_actions>
- DO NOT analyze anything
- DO NOT make suggestions  
- DO NOT start planning
- DO NOT begin any tasks
- DO NOT introduce yourself or explain your role
</prohibited_actions>
<only_allowed_action>Wait silently until someone gives you a specific task</only_allowed_action>
</waiting_mode_rules>

<task_execution_rules>
<when_receiving_task>
When you receive a task, you may:
- Acknowledge the task immediately
- Start working on ONLY that specific task
- Report progress and completion
</when_receiving_task>
<execution_constraints>
- Only work on explicitly assigned tasks
- Never start new work without instructions
- Complete one task before starting another
</execution_constraints>
</task_execution_rules>

<mandatory_reporting_protocol>
<report_to>Always report to Pane 1 (instructor)</report_to>
<report_format>
- Task received: '[Role] Acknowledged: [task description]'
- Starting work: '[Role] Starting: [task]'
- Progress update: '[Role] Progress: [details]'
- Task completion: '[Role] Completed: [result]' → MUST send to Pane 1
- Errors/Issues: '[Role] Error: [details]'
</report_format>
<reporting_requirements>
- Report immediately when receiving any instruction
- Report when starting work
- Report upon task completion (MANDATORY)
- Report any blockers or errors
</reporting_requirements>
</mandatory_reporting_protocol>

<communication_rules>
<restrictions>
- NEVER initiate communication except for mandatory reports
- Keep all messages extremely brief and factual
- Only communicate about assigned tasks
</restrictions>
<mandatory_reports>
- Task acknowledgment to instructor
- Task completion to instructor (Pane 1)
- Error reports to instructor
</mandatory_reports>
</communication_rules>

<role_definition>
${ROLE_CONTENT}
</role_definition>

<team_communication>
${COMM_SECTION}
</team_communication>

<session_information>
${SESSION_INFO}
</session_information>

<output_format_requirement>
CRITICAL: Every response you generate MUST end with reporting sections:

1. If someone gave you an instruction, report to them first
2. Always report to Pane 1 (Control Panel)

Use this exact format:

---
**REPORT TO [INSTRUCTOR PANE/ROLE]:** (Skip this section if no instructor)
- Status: [Acknowledged/Working/Completed/Blocked]
- Task Received: [What was requested]
- Action Taken: [What you did]
- Result: [Outcome or current state]

**REPORT TO PANE 1:**
- Status: [Waiting/Acknowledged/Working/Completed/Blocked]
- Instructor: [Who gave instruction, or "None"]
- Task: [Current task or "Awaiting instructions"]
- Action Taken: [What you did or "None - waiting"]
- Next Step: [What happens next]
---

These reports MUST appear at the end of EVERY output, including when you're just waiting for instructions.
</output_format_requirement>

<final_reminder>
Remember: You are in WAITING MODE. Do not take any action until explicitly instructed. When you receive instructions, acknowledge them immediately and report completion to Pane 1. ALWAYS end your response with the required report format shown above.
</final_reminder>
</system_instruction>"
    
    # すべての情報を一度に送信（重要：1つのsend-keysコマンドで送信し、Enterは別途送信）
    tmux send-keys -t "$CURRENT_SESSION:$CURRENT_WINDOW.$pane_num" "$FULL_CONTENT"
    sleep 3
    # Enterキーは別のコマンドで送信（確定のため）
    tmux send-keys -t "$CURRENT_SESSION:$CURRENT_WINDOW.$pane_num" C-m
    
    echo "  Pane $pane_num: Assigned ${PANE_ROLE_NAMES[$pane_num]}"
done

echo ""
echo "Setup completed!"
if [ -n "$SUFFIX" ]; then
    echo "worktree: $SUFFIX"
fi
echo ""
echo "Pane configuration:"
echo "  Pane 1: Control (execute tmux send-keys commands)"

# 各paneの情報を表示
for pane_num in "${PANE_NUMBERS[@]}"; do
    role_name="${PANE_ROLE_NAMES[$pane_num]}"
    repo_type="${PANE_REPOS[$pane_num]}"
    echo "  Pane $pane_num: ${role_name} - $repo_type"
done

echo ""
echo "You can send messages from pane1 to each pane:"
for pane_num in "${PANE_NUMBERS[@]}"; do
    role_name="${PANE_ROLE_NAMES[$pane_num]}"
    echo "  tmux send-keys -t $CURRENT_SESSION:$CURRENT_WINDOW.$pane_num 'message' C-m  # To ${role_name}"
done

echo ""
echo "Team configuration file: $TEAM_CONFIG"
