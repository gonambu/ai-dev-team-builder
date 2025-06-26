#!/bin/bash

# Claude Workflow Setup Script
# 
# このスクリプトは、tmuxを使用してClaude開発チームのワークフローをセットアップします。
# ROLE_DIR内のファイル数に応じて動的にpaneを作成します。
#
# 必須環境変数:
#   REPO_BASE_DIR   - リポジトリのベースディレクトリ (例: $HOME/ghq/github.com)
#   GITHUB_ORG      - GitHubの組織名
#   SPEC_REPO_NAME  - 仕様リポジトリ名
#   IMPL_REPO_NAME  - 実装リポジトリ名
#
# オプション環境変数:
#   ROLE_DIR        - ロール定義ファイルのディレクトリ (デフォルト: $HOME/claude-workflow-roles)
#
# 使用例:
#   # 環境変数を設定してから実行
#   export REPO_BASE_DIR=$HOME/ghq/github.com
#   export GITHUB_ORG=myorg
#   export SPEC_REPO_NAME=myorg-specifications
#   export IMPL_REPO_NAME=myorg-app
#   ./setup-claude-workflow.sh              # デフォルトのリポジトリを使用
#   ./setup-claude-workflow.sh 2            # worktree 2を使用

# .envファイルが存在する場合は読み込む
if [ -f .env ]; then
    echo ".envファイルを読み込み中..."
    # .envファイルを読み込む（export文を評価）
    set -a
    source .env
    set +a
fi

# 環境変数の確認（必須）
if [ -z "$REPO_BASE_DIR" ]; then
    echo "エラー: REPO_BASE_DIR 環境変数を設定してください"
    echo "例: export REPO_BASE_DIR=\$HOME/ghq/github.com"
    exit 1
fi

if [ -z "$GITHUB_ORG" ]; then
    echo "エラー: GITHUB_ORG 環境変数を設定してください"
    echo "例: export GITHUB_ORG=your-org-name"
    exit 1
fi

if [ -z "$SPEC_REPO_NAME" ]; then
    echo "エラー: SPEC_REPO_NAME 環境変数を設定してください"
    echo "例: export SPEC_REPO_NAME=your-spec-repo"
    exit 1
fi

if [ -z "$IMPL_REPO_NAME" ]; then
    echo "エラー: IMPL_REPO_NAME 環境変数を設定してください"
    echo "例: export IMPL_REPO_NAME=your-impl-repo"
    exit 1
fi

# ROLE_DIRのデフォルト値設定（オプション）
: ${ROLE_DIR:="./claude-workflow-roles"}

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
echo "環境変数の設定:"
echo "  REPO_BASE_DIR: $REPO_BASE_DIR"
echo "  GITHUB_ORG: $GITHUB_ORG"
echo "  SPEC_REPO_NAME: $SPEC_REPO_NAME"
echo "  IMPL_REPO_NAME: $IMPL_REPO_NAME"
echo "  ROLE_DIR: $ROLE_DIR"
echo ""

# リポジトリの存在確認
if [ ! -d "$SPEC_REPO" ]; then
    echo "エラー: 仕様リポジトリが見つかりません: $SPEC_REPO"
    exit 1
fi

if [ ! -d "$IMPL_REPO" ]; then
    echo "エラー: 実装リポジトリが見つかりません: $IMPL_REPO"
    exit 1
fi

# ロールファイルディレクトリの存在確認
if [ ! -d "$ROLE_DIR" ]; then
    echo "エラー: ロール定義ディレクトリが見つかりません: $ROLE_DIR"
    exit 1
fi

# ロールファイルを検索（.mdファイルのみ）
ROLE_FILES=($(find "$ROLE_DIR" -maxdepth 1 -name "*.md" -type f | sort))

if [ ${#ROLE_FILES[@]} -eq 0 ]; then
    echo "エラー: $ROLE_DIR にロール定義ファイル（*.md）が見つかりません"
    exit 1
fi

echo "見つかったロールファイル: ${#ROLE_FILES[@]}個"
for file in "${ROLE_FILES[@]}"; do
    echo "  - $(basename "$file")"
done
echo ""

# 現在のウィンドウとセッション情報を取得
CURRENT_SESSION=$(tmux display-message -p '#S')
CURRENT_WINDOW=$(tmux display-message -p '#I')

# 現在のpane数を確認
PANE_COUNT=$(tmux list-panes | wc -l)

if [ $PANE_COUNT -ne 1 ]; then
    echo "エラー: このスクリプトはpaneが1つの状態で実行してください。"
    exit 1
fi

# pane1はコントロール用として残す
echo "paneを作成中..."

# 各ロールファイルに対してpaneを作成
PANE_NUMBER=2
# 順序を保証するために通常の配列を使用
declare -a PANE_NUMBERS
declare -A PANE_ROLES
declare -A PANE_REPOS
declare -A PANE_ROLE_NAMES

for role_file in "${ROLE_FILES[@]}"; do
    # ファイル名から情報を抽出
    filename=$(basename "$role_file")
    
    # ファイルから役割名を抽出（最初の#見出しから取得）
    role_name=$(grep -m 1 "^# " "$role_file" | sed 's/^# //')
    if [ -z "$role_name" ]; then
        role_name=$(basename "$role_file" .md)
    fi
    
    # ファイル内容から必要なリポジトリを判定
    # {{IMPL_REPO}}を含むファイルはIMPL_REPO、それ以外はSPEC_REPOを使用
    if grep -q "{{IMPL_REPO}}" "$role_file"; then
        target_repo="$IMPL_REPO"
        repo_type="実装リポジトリ"
    else
        target_repo="$SPEC_REPO"
        repo_type="仕様リポジトリ"
    fi
    
    # paneを作成（常に垂直分割）
    tmux split-window -h -c "$target_repo"
    
    # Claudeを起動
    tmux send-keys -t "$CURRENT_SESSION:$CURRENT_WINDOW.$PANE_NUMBER" "claude --dangerously-skip-permissions" C-m
    sleep 3
    
    # pane情報を保存
    PANE_NUMBERS+=($PANE_NUMBER)
    PANE_ROLES[$PANE_NUMBER]="$role_file"
    PANE_REPOS[$PANE_NUMBER]="$repo_type"
    PANE_ROLE_NAMES[$PANE_NUMBER]="$role_name"
    
    PANE_NUMBER=$((PANE_NUMBER + 1))
done

# すべてのpaneが作成された後、レイアウトを調整して幅を均等にする
echo "paneの幅を調整中..."
tmux select-layout -t "$CURRENT_SESSION:$CURRENT_WINDOW" even-horizontal

echo "チーム構成情報を作成中..."

# チーム構成の概要を作成
TEAM_OVERVIEW="=== チーム構成 ===
このtmuxセッションには以下のメンバーが参加しています：

コントロールパネル (Pane 1)
  - 役割: 全体の制御とコマンド実行
  - 他のメンバーへのメッセージ送信を担当
"

# 各メンバーの情報を追加
for pane_num in "${PANE_NUMBERS[@]}"; do
    role_name="${PANE_ROLE_NAMES[$pane_num]}"
    repo_type="${PANE_REPOS[$pane_num]}"
    
    TEAM_OVERVIEW="${TEAM_OVERVIEW}
${role_name} (Pane ${pane_num})
  - 作業ディレクトリ: ${repo_type}"
done

TEAM_OVERVIEW="${TEAM_OVERVIEW}

==================="

echo "ロールを割り当て中..."

# 各paneにロールを送信
for pane_num in "${PANE_NUMBERS[@]}"; do
    role_file="${PANE_ROLES[$pane_num]}"
    
    # コミュニケーションコマンドセクションを作成
    COMM_SECTION="

## 他のメンバーへのコマンド送信方法

以下のように役割名を使ってメッセージを送信できます：

"
    # コントロールパネルへの送信コマンド
    COMM_SECTION="${COMM_SECTION}- コントロールパネルへ: \`tmux send-keys -t ${CURRENT_SESSION}:${CURRENT_WINDOW}.1 \"echo '[\\$(date +%H:%M:%S)] メッセージ'\" C-m\`
"
    
    # 他の各役割への送信コマンド
    for target_pane in "${PANE_NUMBERS[@]}"; do
        if [ $target_pane -ne $pane_num ]; then
            target_role="${PANE_ROLE_NAMES[$target_pane]}"
            COMM_SECTION="${COMM_SECTION}- ${target_role}へ: \`tmux send-keys -t ${CURRENT_SESSION}:${CURRENT_WINDOW}.${target_pane} \$'メッセージ' ; sleep 3; tmux send-keys -t ${CURRENT_SESSION}:${CURRENT_WINDOW}.${target_pane} C-m\`
"
        fi
    done
    
    # 役割名とpane番号のマッピング情報を追加
    COMM_SECTION="${COMM_SECTION}
### 役割とpane番号の対応表

| 役割名 | Pane番号 |
|--------|----------|
| コントロールパネル | 1 |"
    
    for mapping_pane in "${PANE_NUMBERS[@]}"; do
        mapping_role="${PANE_ROLE_NAMES[$mapping_pane]}"
        COMM_SECTION="${COMM_SECTION}
| ${mapping_role} | ${mapping_pane} |"
    done
    
    # セッション情報セクションを作成
    SESSION_INFO="

## セッション情報

- 現在のセッション: ${CURRENT_SESSION}
- 現在のウィンドウ: ${CURRENT_WINDOW}
- 自分のpane番号: ${pane_num}"
    
    # ロール内容を読み込み、変数を置換
    ROLE_CONTENT=$(sed -e "s/{{SESSION}}/$CURRENT_SESSION/g" \
                      -e "s/{{WINDOW}}/$CURRENT_WINDOW/g" \
                      -e "s|{{IMPL_REPO}}|$IMPL_REPO|g" \
                      -e "s|{{SPEC_REPO}}|$SPEC_REPO|g" \
                      "$role_file")
    
    # 既存のコミュニケーションセクションとセッション情報セクションを削除
    ROLE_CONTENT=$(echo "$ROLE_CONTENT" | sed '/^## 他のpaneへのコマンド送信方法/,/^## セッション情報/d' | sed '/^## セッション情報/,/^##\|$/d')
    
    # チーム構成情報とロール情報を結合
    FULL_CONTENT="${TEAM_OVERVIEW}

${ROLE_CONTENT}${COMM_SECTION}${SESSION_INFO}"
    
    # すべての情報を一度に送信
    tmux send-keys -t "$CURRENT_SESSION:$CURRENT_WINDOW.$pane_num" "$FULL_CONTENT"
    sleep 3
    tmux send-keys -t "$CURRENT_SESSION:$CURRENT_WINDOW.$pane_num" C-m
    
    echo "  Pane $pane_num: ${PANE_ROLE_NAMES[$pane_num]} を割り当てました"
done

echo ""
echo "セットアップが完了しました！"
if [ -n "$SUFFIX" ]; then
    echo "worktree: $SUFFIX"
fi
echo ""
echo "各paneの設定："
echo "  Pane 1: コントロール用（tmux send-keysコマンドを実行）"

# 各paneの情報を表示
for pane_num in "${PANE_NUMBERS[@]}"; do
    role_name="${PANE_ROLE_NAMES[$pane_num]}"
    repo_type="${PANE_REPOS[$pane_num]}"
    echo "  Pane $pane_num: ${role_name} - $repo_type"
done

echo ""
echo "pane1から各paneにメッセージを送信できます："
for pane_num in "${PANE_NUMBERS[@]}"; do
    role_name="${PANE_ROLE_NAMES[$pane_num]}"
    echo "  tmux send-keys -t $CURRENT_SESSION:$CURRENT_WINDOW.$pane_num 'メッセージ' C-m  # ${role_name}へ"
done

echo ""
echo "役割定義ファイル："
for role_file in "${ROLE_FILES[@]}"; do
    echo "  $role_file"
done
