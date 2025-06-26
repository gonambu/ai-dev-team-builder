# AI Dev Team Builder

tmuxとClaude CLIを使用して、AIエージェントによる開発チームを構築するツールです。複数のClaudeインスタンスが異なる役割（プロジェクトマネージャー、開発者、テックリードなど）を担当し、協調して作業を進めます。

## 必要なツール

- **tmux**: ターミナルマルチプレクサ
  ```bash
  # macOS
  brew install tmux
  
  # Ubuntu/Debian
  sudo apt-get install tmux
  ```

- **Claude CLI**: Anthropic公式のCLIツール
  ```bash
  npm install -g @anthropic-ai/claude-cli
  ```

- **Git**: バージョン管理システム（worktree機能を使用）
  ```bash
  # 通常はプリインストールされていますが、必要に応じて
  brew install git  # macOS
  ```

## セットアップ

### 1. リポジトリのクローン

```bash
git clone https://github.com/your-username/ai-dev-team-builder.git
cd ai-dev-team-builder
```

### 2. 役割定義ファイルの準備

`claude-workflow-roles`ディレクトリに役割定義ファイル（`.md`形式）を配置します。

```bash
mkdir -p ~/claude-workflow-roles
cp claude-workflow-roles/*.md ~/claude-workflow-roles/
```

各役割ファイルは以下の形式で記述します：

```markdown
# 役割名

役割の説明...

## 役割と責任

- 責任1
- 責任2
...
```

### 3. 環境変数の設定

環境変数の設定には以下の2つの方法があります：

#### 方法1: .envファイルを使用（推奨）

```bash
# .env.exampleをコピーして編集
cp .env.example .env

# .envファイルを編集して実際の値を設定
vi .env  # またはお好みのエディタで編集
```

`.env`ファイルの内容例：
```bash
# 必須環境変数
REPO_BASE_DIR="$HOME/ghq/github.com"
GITHUB_ORG="your-organization"
SPEC_REPO_NAME="your-specifications"
IMPL_REPO_NAME="your-application"

# オプション環境変数
# ROLE_DIR="$HOME/claude-workflow-roles"
```

#### 方法2: シェルの環境変数として設定

```bash
# 必須環境変数
export REPO_BASE_DIR="$HOME/ghq/github.com"  # リポジトリのベースディレクトリ
export GITHUB_ORG="your-org"                   # GitHub組織名
export SPEC_REPO_NAME="your-specifications"    # 仕様リポジトリ名
export IMPL_REPO_NAME="your-app"              # 実装リポジトリ名

# オプション環境変数
export ROLE_DIR="$HOME/claude-workflow-roles"  # 役割定義ファイルのディレクトリ（デフォルト値あり）
```

永続的に設定する場合は`.bashrc`や`.zshrc`に追加：

```bash
# AI Dev Team Builder環境変数
export REPO_BASE_DIR="$HOME/ghq/github.com"
export GITHUB_ORG="your-org"
export SPEC_REPO_NAME="your-specifications"
export IMPL_REPO_NAME="your-app"
```

**注意**: `.env`ファイルは`.gitignore`に含まれているため、Gitにコミットされません。

## 使用方法

### 基本的な使用

```bash
# デフォルトのリポジトリでチームを起動
./setup-claude-workflow.sh

# worktreeを使用する場合（例：worktree名が "feature-1"）
./setup-claude-workflow.sh feature-1
```

### Git Worktreeの命名規則

worktreeを使用する場合、以下の命名規則を推奨します：

- **機能開発**: `feature-{機能名}` (例: `feature-auth`, `feature-payment`)
- **バグ修正**: `fix-{バグ名}` (例: `fix-login-error`)
- **実験的変更**: `experiment-{実験名}` (例: `experiment-new-ui`)
- **リファクタリング**: `refactor-{対象}` (例: `refactor-database`)

worktree作成例：

```bash
# 仕様リポジトリ
cd $REPO_BASE_DIR/$GITHUB_ORG/$SPEC_REPO_NAME
git worktree add -b feature-auth ../loglass-specifications-feature-auth

# 実装リポジトリ
cd $REPO_BASE_DIR/$GITHUB_ORG/$IMPL_REPO_NAME
git worktree add -b feature-auth ../loglass-feature-auth

# その後、スクリプトを実行
./setup-claude-workflow.sh feature-auth
```

## チーム構成

スクリプトは以下のようなtmux paneレイアウトを作成します：

```
+------------------+------------------+
|                  |                  |
|   Pane 1         |   Pane 2         |
| (コントロール)    | (マネージャー)    |
|                  |                  |
+------------------+------------------+
|                  |                  |
|   Pane 3         |   Pane 4         |
|  (開発者)        | (テックリード)    |
|                  |                  |
+------------------+------------------+
```

- **Pane 1**: コントロールパネル（ユーザーがコマンドを実行）
- **Pane 2-N**: 役割ファイルに基づいて動的に作成

## pane間のコミュニケーション

### コントロールパネルから各paneへ

```bash
# Pane 2（マネージャー）へ
tmux send-keys -t session:window.2 'タスクを開始してください' C-m

# Pane 3（開発者）へ
tmux send-keys -t session:window.3 '実装を進めてください' C-m
```

### pane間の直接通信

各paneには、他のpaneと通信するためのコマンドが自動的に提供されます。

## 役割ファイルの追加

新しい役割を追加するには：

1. `~/claude-workflow-roles/`に新しい`.md`ファイルを作成
2. ファイル名は役割を表すものに（例: `pane5-qa-engineer.md`）
3. ファイル内で`{{IMPL_REPO}}`を使用すると実装リポジトリ、それ以外は仕様リポジトリで起動

## トラブルシューティング

### エラー: リポジトリが見つかりません

環境変数が正しく設定されているか確認：

```bash
echo $REPO_BASE_DIR
echo $GITHUB_ORG
echo $SPEC_REPO_NAME
echo $IMPL_REPO_NAME
```

### エラー: paneが1つの状態で実行してください

既存のtmux paneを閉じるか、新しいウィンドウで実行：

```bash
# 新しいtmuxウィンドウを作成
tmux new-window
```

### Claude CLIが起動しない

Claude CLIが正しくインストールされているか確認：

```bash
which claude
claude --version
```

## ライセンス

このプロジェクトはMITライセンスの下で公開されています。