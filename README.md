# dotfiles

Ces instructions sont destinés à la configuration d'un Ubuntu.

## 0. Création de la structure de fichiers

```bash
cd ~
mkdir -p code/perso
mkdir downloads
```

## 1. Configuration de l'environnement SSH
- [ ] 1.1 Créer clé SSH [doc](https://docs.github.com/en/authentication/connecting-to-github-with-ssh/generating-a-new-ssh-key-and-adding-it-to-the-ssh-agent)
```bash
ssh-keygen -t ed25519 -C "philippelamy98@outlook.com"
```

- [ ] 1.1.1 Entrer les informations suivantes (modifier `{user}`):
```bash
Generating public/private ed25519 key pair.
Enter file in which to save the key (/home/{user}/.ssh/id_ed25519): /home/{user}/.ssh/github
Enter passphrase (empty for no passphrase):
Enter same passphrase again:
```
- [ ] 1.1.2 Ajouter la clé publique dans Github [keys](https://github.com/settings/keys)
- [ ] 1.1.3 Créer la configuration SSH:
```bash
touch ~/.ssh/config
```
- [ ] 1.1.4 Ajouter la configuration suivante:
```ssh
Host github
    Hostname github.com
    IdentityFile ~/.ssh/github
    IdentitiesOnly yes
    AddKeysToAgent yes
```

- [ ] 1.2 Cloner le dépôt [dotfiles](https://github.com/lamiphil/dotfiles):
```bash
cd ~
git clone git@github.com:lamiphil/dotfiles.git
```

## 2. Installation des packages

- [ ] 2.1 Exécuter le script *dotfiles/scripts/install.sh*
```bash
cd ~/dotfiles/scripts
sudo ./install_packages.sh
```

- [ ] 2.2 Cloner [tree-sitter-logstash](https://github.com/Preston-PLB/tree-sitter-logstash.git) (optionnel)
```bash
cd ~/dotfiles/repos
git clone https://github.com/Preston-PLB/tree-sitter-logstash.git
```

- [ ] 2.3 Installer lsd
```bash
wget https://github.com/lsd-rs/lsd/releases/download/v1.1.5/lsd-musl_1.1.5_amd64.deb
sudo dpkg -i lsd-musl_1.1.5_amd64.deb
```

- [ ] 2.4 Installer [neovim 0.10.0](https://github.com/neovim/neovim/releases/) (ou une version plus récente)
```bash
wget https://github.com/neovim/neovim/releases/download/v0.10.0/nvim-linux64.tar.gz
tar xzvf nvim-linux64.tar.gz
sudo mv nvim-linux64 /opt/nvim sudo ln -s /opt/nvim/bin/nvim /usr/local/bin/nvim
```

- [ ] 2.5 Installer Starship
```bash
curl -sS https://starship.rs/install.sh | sh 
```

- [ ] 2.6 Installer NVChad
```bash
git clone https://github.com/NvChad/starter ~/.config/nvim && nvim
```
- [ ] 2.6.1 Exécuter :LazyInstall dans neovim

- [ ] 2.7 Installer Tmux Package Manager
```bash
git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm
```
- [ ] 2.7.1 Dans Tmux, faire *PREFIX (CTRL + SPACE) + I (i majuscule)*  afin d'installer les plugins

- [ ] 2.8 Installer [kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl-linux/)
```bash
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
```

## 3. Configuration des fichiers de configuration

- [ ] 3.1 Exécuter stow 
```bash
cd ~/dotfiles
stow .
```

## 4. Configuration de l'interface de l'application *Terminal*
- [ ] 4.1 Télécharger et installer le font [JetBrains Mono Nerd Font](https://github.com/ryanoasis/nerd-fonts/releases/download/v3.3.0/JetBrainsMono.zip)
- [ ] 4.2 Choisir le profil *Ubuntu*
- [ ] 4.3 Dans l'onglet *Color Scheme*, choisir le thème **One Half Dark**
- [ ] 4.4 Choisir la *Font face* **JetBrains Mono Nerd Font**
- [ ] 4.5 Choisir *Font weight* à **Semi-Bold**













