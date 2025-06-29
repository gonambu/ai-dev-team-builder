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

- **yq**: YAML処理ツール（チーム構成ファイルの読み込みに必要）
  ```bash
  # macOS
  brew install yq
  
  # Ubuntu/Debian
  sudo apt-get install yq
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

### 2. チーム構成の定義

`team-config.yml`ファイルでチーム構成を定義します：

```bash
# サンプルをコピーして編集
cp team-config.example.yml team-config.yml
vi team-config.yml  # またはお好みのエディタで編集
```

`team-config.yml`の例：
```yaml
# 標準的なチーム構成（開発者2名）
team:
  - manager      # プロジェクトマネージャー
  - techlead     # テックリード兼レビュー担当
  - developer    # 開発者1
  - developer    # 開発者2

# 大規模チーム（開発者4名）の例
# team:
#   - manager
#   - techlead
#   - developer
#   - developer
#   - developer
#   - developer
```

同じ役割を複数回リストすることで、その役割の複数インスタンスを作成できます。

### 3. 役割定義ファイルの準備

`claude-workflow-roles`ディレクトリに以下の役割定義ファイルが含まれています：

- `manager.md` - プロジェクトマネージャー
- `techlead.md` - テックリード兼レビュー担当
- `developer.md` - 開発者

### 4. 環境変数の設定

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
# ROLE_DIR="./claude-workflow-roles"
# TEAM_CONFIG="./team-config.yml"
```

#### 方法2: シェルの環境変数として設定

```bash
# 必須環境変数
export REPO_BASE_DIR="$HOME/ghq/github.com"  # リポジトリのベースディレクトリ
export GITHUB_ORG="your-org"                   # GitHub組織名
export SPEC_REPO_NAME="your-specifications"    # 仕様リポジトリ名
export IMPL_REPO_NAME="your-app"              # 実装リポジトリ名

# オプション環境変数
export ROLE_DIR="./claude-workflow-roles"      # 役割定義ファイルのディレクトリ
export TEAM_CONFIG="./team-config.yml"         # チーム構成ファイル
```

**注意**: `.env`ファイルと`team-config.yml`は`.gitignore`に含まれているため、Gitにコミットされません。

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
git worktree add -b feature-auth ../your-specifications-feature-auth

# 実装リポジトリ
cd $REPO_BASE_DIR/$GITHUB_ORG/$IMPL_REPO_NAME
git worktree add -b feature-auth ../your-app-feature-auth

# その後、スクリプトを実行
./setup-claude-workflow.sh feature-auth
```

## チーム構成

スクリプトは`team-config.yml`に基づいてpaneを作成します。同じ役割の複数インスタンスがサポートされており、自動的に番号が付けられます。

例：開発者4名のチーム構成
```
+--------+--------+--------+--------+--------+--------+
| Pane 1 | Pane 2 | Pane 3 | Pane 4 | Pane 5 | Pane 6 |
|        |        |        |        |        |        |
|Control |Manager |TechLead|Dev 1   |Dev 2   |Dev 3   |
|        |        |        |        |        |        |
+--------+--------+--------+--------+--------+--------+
```

- **Pane 1**: コントロールパネル（ユーザーがコマンドを実行）
- **Pane 2-N**: `team-config.yml`の定義に基づいて作成
- 各paneの幅は自動的に均等に調整されます

## 共通ルール

すべての役割に以下の共通ルールが自動的に適用されます：

### 報告義務
- 作業開始時: `[Role] Starting: [task]`
- 作業完了時: `[Role] Completed: [task and result]`
- エラー発生時: `[Role] Error: [error details]`

### コミュニケーション原則
- 指示元への報告を優先
- 簡潔で要点を絞った報告
- トークン効率を考慮したメッセージ

## pane間のコミュニケーション

### コントロールパネルから各paneへ

```bash
# Pane 2（マネージャー）へ
tmux send-keys -t session:window.2 'タスクを開始してください' C-m

# Pane 3（開発者1）へ
tmux send-keys -t session:window.3 '実装を進めてください' C-m
```

### pane間の直接通信

各paneには、他のpaneと通信するためのコマンドが自動的に提供されます。

## カスタマイズ

### 新しい役割の追加

1. `claude-workflow-roles/`に新しい`.md`ファイルを作成
2. ファイル名は役割を表すものに（例: `qa-engineer.md`）
3. `team-config.yml`に新しい役割を追加

### 役割ファイルの形式

```markdown
# Role Name

Role description and primary responsibilities.

## Responsibilities

- Specific responsibility 1
- Specific responsibility 2
...

## Important

- Key behaviors
- Constraints
```

`{{IMPL_REPO}}`を含む役割は実装リポジトリで、それ以外は仕様リポジトリで起動します。

## トラブルシューティング

### エラー: yqが見つかりません

```bash
# macOS
brew install yq

# その他のプラットフォーム
https://github.com/mikefarah/yq#install
```

### エラー: team-config.ymlが見つかりません

```bash
cp team-config.example.yml team-config.yml
vi team-config.yml  # チーム構成を定義
```

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