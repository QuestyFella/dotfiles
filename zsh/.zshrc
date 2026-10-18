# Powerlevel10k instant prompt (keep near the top)
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# scripts from this repo (theme, cheatsheet, …)
export PATH="$HOME/.local/bin:$PATH"

# Oh My Zsh + Powerlevel10k prompt
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME=""
plugins=(git)
source "$ZSH/oh-my-zsh.sh"
source /opt/homebrew/share/powerlevel10k/powerlevel10k.zsh-theme
[[ -r "$HOME/.p10k.zsh" ]] && source "$HOME/.p10k.zsh"

alias md="mkdir -p"
alias up="cd .."
alias cl="clear"
alias src="source ~/.zshrc"
alias conf="cd ~/.config"
