#!/bin/bash

SCRIPT_PATH=$( cd "$(dirname "$0")" ; pwd )

install_dotfiles() {
    echo "Installing dotfiles..."
    pushd $SCRIPT_PATH
    DOTFILES=(ipython tmux/tmux.conf vim vimrc)
    for DOTFILE in "${DOTFILES[@]}"; do
        DOTFILE_NAME="$(basename $DOTFILE)"
        DOTFILE_SOURCE="$PWD/$DOTFILE"
        DOTFILE_TARGET="$HOME/.$DOTFILE_NAME"

        echo "cp -f $DOTFILE_SOURCE $DOTFILE_TARGET"
        cp -rf $DOTFILE_SOURCE $DOTFILE_TARGET
    done
    popd
}

install_ohmyzsh() {
    USERSHELL=$(basename $SHELL)
    if [[ "$USERSHELL" == "zsh" ]]; then
        echo "Zsh is already configured as your shell of choice."
        echo "Restart your session to load the new settings."
    else
        if [[ ! -x `which zsh` ]]; then
            echo "Zsh is missing. Installing Zsh..."
            brew install zsh
        fi

        echo "Setting Zsh as your default shell."
        if [[ -n $(which zsh | grep "/usr/local/bin/zsh") ]]; then
            if [[ -z $(cat /priviate/etc/shells | grep "/usr/local/bin/zsh") ]]; then
                echo "Adding Zsh to standard shell list."
                sudo /bin/bash -c "echo /usr/local/bin/zsh >> /private/etc/shells" 
            fi
            chsh -s /usr/local/bin/zsh
        else
            chsh -s /bin/zsh
        fi
    fi

    if [[ ! -x `which curl` ]]; then
        echo "cUrl is missing. Installing cUrl..."
        brew install curl
    fi

    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
}

install_python() {
    PYTHON_VERSION="3.8.6"

    if [[ -z $(brew list 2>/dev/null | grep "pyenv") ]]; then
        echo "Installing Pyenv to install and manage multiple versions of Python..."
        brew install pyenv
        eval "$(pyenv init -)"
        echo -e 'if command -v pyenv 1>/dev/null 2>&1; then\n  eval "$(pyenv init -)"\nfi' >> ~/.zshrc
        git clone https://github.com/pyenv/pyenv-virtualenv.git $(pyenv root)/plugins/pyenv-virtualenv
        eval "$(pyenv virtualenv-init -)"
cat >> ~/.zshrc << 'EOF'
eval "$(pyenv virtualenv-init -)"
export PYENV_VIRTUALENV_DISABLE_PROMPT=1
export BASE_PROMPT=$PS1
function updatePrompt {
    if [[ $VIRTUAL_ENV != "" ]]; then
    ¦   export PS1="(${VIRTUAL_ENV##*/}) "$BASE_PROMPT
    else
    ¦   export PS1=$BASE_PROMPT
    fi
}
export PROMPT_COMMAND='updatePrompt'
precmd() { eval '$PROMPT_COMMAND' }

EOF
    fi

    brew install zlib
    brew install readline
    brew install openssl

    if [[ ! -d "$HOME/.pyenv/versions/$PYTHON_VERSION" ]]; then
        echo "Installing Python v$PYTHON_VERSION"
        CPPFLAGS="-I$(brew --prefix zlib)/include -I$(brew --prefix readline)/include -I$(brew --prefix openssl)/include -I$(xcrun --show-sdk-path)/usr/include" \
        LDFLAGS="-L$(brew --prefix zlib)/lib -L$(brew --prefix readline)/lib -L$(brew --prefix openssl)/lib" \
        PYTHON_CONFIGURE_OPTS="--enable-shared" \
        pyenv install $PYTHON_VERSION
        pyenv global $PYTHON_VERSION
    fi
cat >> ~/.zshrc << 'EOF'
export CPPFLAGS="-I$(brew --prefix zlib)/include -I$(brew --prefix readline)/include -I$(brew --prefix openssl)/include -I$(xcrun --show-sdk-path)/usr/include"
export LDFLAGS="-L$(brew --prefix zlib)/lib -L$(brew --prefix readline)/lib -L$(brew --prefix openssl)/lib"
export PYTHON_CONFIGURE_OPTS="--enable-shared"

EOF
}

install_nodejs() {
    if [[ -z $(brew list 2>/dev/null | grep "node") ]]; then
        echo "Installing Node.js..."
        brew install node
        brew install yarn
    fi
}

install_golang() {
    if [[ -z $(brew list 2>/dev/null | grep "go") ]]; then
        echo "Installing Go..."
        brew install golang
        mkdir -p $HOME/go/{bin,src,pkg}
cat >> ~/.zshrc << 'EOF'
export GOPATH=$HOME/go
export GOBIN=$GOPATH/bin
export PATH=$PATH:/usr/local/opt/go/bin:$GOBIN

EOF
    fi
}

install_java() {
    curl -s "https://get.sdkman.io" | bash
    source "$HOME/.sdkman/bin/sdkman-init.sh"
}

install_vim() {
    brew install lua
    brew install luajit

    if [[ ! -e /usr/local/bin/vim ]]; then
        echo "Installing Vim..."
        brew install vim
    fi

    if [[ ! -e /usr/local/bin/nvim ]]; then
        echo "Installing Neovim"
        brew install neovim

        pip install --upgrade pip
        pip install pynvim

        if [[ ! -d "$HOME/.config" ]]; then
            mkdir $HOME/.config
        fi
        ln -sf $HOME/.vim $HOME/.config/nvim
        ln -sf $HOME/.vimrc $HOME/.config/nvim/init.vim
    fi

    if [ -z "$(ls -A $HOME/Library/Fonts)" ]; then
        echo "Installing patched fonts for Powerline..."
        cp -f $SCRIPT_PATH/fonts/* $HOME/Library/Fonts
    fi

    brew install cmake
    brew install ctags cscope global findutils ack

    vim +'PlugInstall --sync' +qa

cat >> ~/.zshrc << 'EOF'
alias vim="nvim"
alias vi="nvim"
alias vimdiff="nvim -d"
EOF
}

install_tmux() {
    if [[ -z $(brew list 2>/dev/null | grep "tmux") ]]; then
        echo "Installing Tmux..."
        brew install tmux
        if [[ ! -d "$HOME/.tmux/plugins/tpm" ]]; then
            git clone https://github.com/tmux-plugins/tpm $HOME/.tmux/plugins/tpm
        fi
    fi
}

install_ipython() {
    if [[ ! -x `which ipython` ]]; then
        echo "Installing IPython..."
        pip install 'ipython[zmq,qtconsole,notebook,test]'
    fi
}

PKGS=`pkgutil --pkgs`
if [[ -z $(echo "$PKGS" | grep com.apple.pkg.Xcode) ]]; then
    echo "Xcode is not installed on this system. Install from the Apple AppStore."
    exit 1
fi

if [[ -z $(echo "$PKGS" | grep com.apple.pkg.CLTools_Executables) ]]; then
    echo "CLTools is not installed on this system."
    echo "Installing Command Line Developer Tools (expect a GUI popup):"
    sudo xcode-select --install
    sleep 2
    while [[ -n $(pgrep "Install Command Line Developer Tools") ]]; do 
        sleep 1
    done
fi

if [[ -n $(brew --prefix 2>&1 | grep "not found") ]]; then
    echo "Homebrew missing. Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install.sh)"
else
    echo "Homebrew already installed."
fi

install_dotfiles
install_ohmyzsh
install_python
install_nodejs
install_golang
install_java
install_vim
install_tmux
install_ipython
