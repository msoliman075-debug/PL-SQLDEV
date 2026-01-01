"""
Git Operations for PL/SQL source control
"""
import os
from datetime import datetime
from pathlib import Path
from typing import Optional

from git import Repo, InvalidGitRepositoryError


class GitOperations:
    """Git operations for PL/SQL code versioning."""

    def __init__(self, repo_path: str = None, branch_prefix: str = "ai-dev/"):
        self.repo_path = Path(repo_path or os.getenv("GIT_REPO_PATH", "."))
        self.branch_prefix = branch_prefix
        self.repo = None

        try:
            self.repo = Repo(self.repo_path)
        except InvalidGitRepositoryError:
            pass

    def init_repo(self) -> dict:
        """Initialize a new git repository."""
        if self.repo:
            return {"status": "exists", "path": str(self.repo_path)}

        self.repo = Repo.init(self.repo_path)
        return {"status": "created", "path": str(self.repo_path)}

    def save_plsql(
        self,
        object_name: str,
        object_type: str,
        code: str,
        owner: str = "APPS",
        message: str = None,
    ) -> dict:
        """Save PL/SQL code to file and optionally commit."""
        if not self.repo:
            return {"status": "failed", "error": "No git repository"}

        # Determine file path
        type_folder = object_type.lower().replace(" ", "_")
        file_path = self.repo_path / owner.lower() / type_folder / f"{object_name.lower()}.sql"

        # Create directories
        file_path.parent.mkdir(parents=True, exist_ok=True)

        # Add header comment
        header = f"""-- Object: {owner}.{object_name}
-- Type: {object_type}
-- Generated: {datetime.now().isoformat()}
-- ============================================

"""

        # Write file
        file_path.write_text(header + code)

        return {
            "status": "saved",
            "file": str(file_path),
            "relative_path": str(file_path.relative_to(self.repo_path)),
        }

    def commit_changes(
        self, message: str, files: list = None, author: str = "AI Agent"
    ) -> dict:
        """Commit changes to repository."""
        if not self.repo:
            return {"status": "failed", "error": "No git repository"}

        try:
            if files:
                self.repo.index.add(files)
            else:
                # Add all changes
                self.repo.index.add("*")

            # Check if there are changes to commit
            if not self.repo.index.diff("HEAD") and not self.repo.untracked_files:
                return {"status": "no_changes", "message": "Nothing to commit"}

            commit = self.repo.index.commit(message, author=f"{author} <ai@agent.local>")

            return {
                "status": "committed",
                "sha": commit.hexsha[:8],
                "message": message,
            }
        except Exception as e:
            return {"status": "failed", "error": str(e)}

    def create_branch(self, branch_name: str, from_branch: str = "main") -> dict:
        """Create a new branch for changes."""
        if not self.repo:
            return {"status": "failed", "error": "No git repository"}

        full_name = f"{self.branch_prefix}{branch_name}"

        try:
            # Check if branch exists
            if full_name in self.repo.heads:
                self.repo.heads[full_name].checkout()
                return {"status": "exists", "branch": full_name}

            # Create and checkout new branch
            base = self.repo.heads[from_branch]
            new_branch = self.repo.create_head(full_name, base)
            new_branch.checkout()

            return {"status": "created", "branch": full_name}
        except Exception as e:
            return {"status": "failed", "error": str(e)}

    def get_file_history(self, file_path: str, limit: int = 10) -> list:
        """Get commit history for a specific file."""
        if not self.repo:
            return []

        history = []
        try:
            for commit in self.repo.iter_commits(paths=file_path, max_count=limit):
                history.append(
                    {
                        "sha": commit.hexsha[:8],
                        "message": commit.message.strip(),
                        "author": str(commit.author),
                        "date": commit.committed_datetime.isoformat(),
                    }
                )
        except Exception:
            pass

        return history

    def get_diff(self, file_path: str = None, staged: bool = False) -> str:
        """Get diff of changes."""
        if not self.repo:
            return ""

        try:
            if staged:
                diff = self.repo.index.diff("HEAD")
            else:
                diff = self.repo.index.diff(None)

            if file_path:
                for d in diff:
                    if file_path in d.a_path or file_path in d.b_path:
                        return d.diff.decode("utf-8", errors="ignore")
                return ""

            return "\n".join(
                d.diff.decode("utf-8", errors="ignore") for d in diff
            )
        except Exception as e:
            return f"Error: {e}"

    def get_status(self) -> dict:
        """Get repository status."""
        if not self.repo:
            return {"status": "no_repo"}

        return {
            "branch": self.repo.active_branch.name,
            "modified": [item.a_path for item in self.repo.index.diff(None)],
            "staged": [item.a_path for item in self.repo.index.diff("HEAD")],
            "untracked": self.repo.untracked_files,
            "is_dirty": self.repo.is_dirty(),
        }

    def list_branches(self) -> list:
        """List all branches."""
        if not self.repo:
            return []

        return [
            {
                "name": branch.name,
                "is_active": branch == self.repo.active_branch,
            }
            for branch in self.repo.heads
        ]

    def checkout_file(self, file_path: str, commit: str = "HEAD") -> dict:
        """Restore a file from a specific commit."""
        if not self.repo:
            return {"status": "failed", "error": "No git repository"}

        try:
            self.repo.git.checkout(commit, "--", file_path)
            return {"status": "restored", "file": file_path, "from": commit}
        except Exception as e:
            return {"status": "failed", "error": str(e)}
