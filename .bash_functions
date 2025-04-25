
# Run ls after running cd 
function cd {
  builtin cd "$@" && ls -F
}


# Yazi
function y() {
	local tmp="$(mktemp -t "yazi-cwd.XXXXXX")" cwd
	yazi "$@" --cwd-file="$tmp"
	if cwd="$(command cat -- "$tmp")" && [ -n "$cwd" ] && [ "$cwd" != "$PWD" ]; then
		builtin cd -- "$cwd"
	fi
	rm -f -- "$tmp"
}

# Switch AWS Profile
function aws-switch-profile() {
    local credentials_file="${AWS_SHARED_CREDENTIALS_FILE:-$HOME/.aws/credentials}"

    if [[ ! -f "$credentials_file" ]]; then
        echo "❌ Fichier de credentials introuvable à : $credentials_file"
        return 1
    fi

    echo "📜 Profils AWS disponibles :"
    local profiles=($(grep '^\[' "$credentials_file" | sed 's/\[\|\]//g'))

    select profile in "${profiles[@]}"; do
        if [[ -n "$profile" ]]; then
            export AWS_PROFILE="$profile"
            echo "✅ Profil actif : $AWS_PROFILE"
            break
        else
            echo "⚠️ Sélection invalide. Réessaie."
        fi
    done
}

