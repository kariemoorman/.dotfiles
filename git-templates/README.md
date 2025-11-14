# git-secret-scan
Secret scanning on both pre-commit and pre-push using Git hooks using TruffleHog and GitLeaks

---

## Setup 

- Create a templates directory:

```
mkdir -p ~/.git-templates
mkdir -p ~/.git-templates/hooks
```

- Download files to `~/.git-templates/hooks` and make them executable:

```
cd ~/.git-templates/hooks && curl -O https://raw.githubusercontent.com/kariemoorman/.dotfiles/refs/heads/main/git-templates/pre-commit
cd ~/.git-templates/hooks && curl -O https://raw.githubusercontent.com/kariemoorman/.dotfiles/refs/heads/main/git-templates/pre-push

chmod +x ~/.git-templates/hooks/*
```

- Add template directory to global git config:

```
git config --global init.templatedir ~/.git-templates
```

- Verify:

```
git config --global --get init.templatedir
```
