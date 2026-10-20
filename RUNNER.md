# Local runner

Arch WSL runner for `.github/workflows/build-local.yml`.

```bash
sudo pacman -S --needed --noconfirm base-devel git python gh
mkdir -p ~/actions-runner && cd ~/actions-runner
ver=$(gh api repos/actions/runner/releases/latest --jq .tag_name | sed 's/^v//')
curl -fLO "https://github.com/actions/runner/releases/download/v$ver/actions-runner-linux-x64-$ver.tar.gz"
tar xzf "actions-runner-linux-x64-$ver.tar.gz"
token=$(gh api -X POST repos/minhmc2007/LunchStorage/actions/runners/registration-token --jq .token)
./config.sh --url https://github.com/minhmc2007/LunchStorage --token "$token" --labels lunchbox --unattended --replace
./run.sh
```

The runner user needs passwordless sudo:

```bash
echo "$USER ALL=(ALL) NOPASSWD: ALL" | sudo tee /etc/sudoers.d/90-actions-runner
```

To keep it running after logout, use `./svc.sh install` and `./svc.sh start` (systemd) or run `./run.sh` inside tmux.
