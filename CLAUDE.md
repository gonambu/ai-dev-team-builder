# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

AI Dev Team Builder is a bash-based orchestration tool that creates an AI-powered development team using tmux and AI CLI tools. It dynamically creates tmux panes with different AI instances, each assigned a specific role (manager, developer, tech lead, etc.) to collaborate on software development projects.

## Key Commands

### Running the Tool

```bash
# Default execution
./setup-team.sh

# With worktree support
./setup-team.sh <worktree-name>
```

### Environment Setup

Required environment variables:
- `REPO_BASE_DIR`: Base directory for repositories
- `GITHUB_ORG`: GitHub organization name  
- `SPEC_REPO_NAME`: Specification repository name
- `IMPL_REPO_NAME`: Implementation repository name
- `ROLE_DIR`: Role files directory (default: `./roles`)

Configure via `.env` file (copy from `.env.example`) or export in shell.

### Testing Changes

Since this is a bash script project with no build/test framework:
1. Ensure bash syntax is valid: `bash -n setup-team.sh`
2. Test script execution in a clean tmux session
3. Verify all role files are properly loaded
4. Check that panes are created correctly

## Architecture

### Core Components

1. **setup-team.sh**: Main orchestration script
   - Validates environment variables
   - Discovers role files dynamically
   - Creates tmux panes based on available roles
   - Launches AI CLI instances with role assignments
   - Sets up inter-pane communication

2. **Role Definition System**: 
   - Role files in `ROLE_DIR` (`.md` files)
   - Team composition defined in `team-config.yml`
   - Files containing `{{IMPL_REPO}}` launch in implementation repo
   - Others launch in specification repo

3. **Tmux Pane Management**:
   - Pane 1: Control panel (user commands)
   - Panes 2-N: Created based on team-config.yml
   - Tiled layout for organized view
   - Pre-configured inter-pane communication commands

### Key Design Decisions

- **Dynamic Role Discovery**: Roles are not hardcoded; any `.md` file in `ROLE_DIR` becomes a role
- **Repository Context**: Each role can work in either spec or implementation repository based on file content
- **Git Worktree Support**: Allows parallel work on different features/branches
- **No Build System**: Pure bash script requiring only system dependencies (tmux, git, AI CLI tools)

## Development Workflow

1. **Adding New Roles**: Create a new `.md` file in `roles/`
2. **Modifying Script Behavior**: Edit `setup-team.sh` directly
3. **Testing Changes**: Run script in a fresh tmux session to verify functionality
4. **Environment Variables**: Update `.env.example` when adding new configuration options

## Important Notes

- The script requires tmux to be running with exactly one pane before execution
- All role files must be valid markdown with proper formatting
- Inter-pane communication uses `tmux send-keys` commands
- The tool assumes AI CLI tools are installed globally