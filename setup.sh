#/bin/zsh

# Run this script from the root directory of the repository

echo "Installing pre-commit hook"
rm -f .git/hooks/pre-commit
ln -s ../../util/hooks/pre-commit .git/hooks/pre-commit
