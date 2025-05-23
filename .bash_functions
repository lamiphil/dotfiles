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

function aws-sso-login() {
    local config_file="${AWS_CONFIG_FILE:-$HOME/.aws/config}"

    if [[ ! -f "$config_file" ]]; then
        echo "❌ Fichier de config introuvable à : $config_file"
        return 1
    fi

    echo "📜 Profils AWS SSO disponibles :"
    local profiles=($(grep -E '^\[profile ' "$config_file" | sed -E 's/^\[profile (.+)\]/\1/'))

    if [ ${#profiles[@]} -eq 0 ]; then
        echo "⚠️ Aucun profil SSO trouvé dans le fichier de config."
        return 1
    fi

    select profile in "${profiles[@]}"; do
        if [[ -n "$profile" ]]; then
            echo "🔐 Connexion au profil SSO : $profile ..."
            aws sso login --profile "$profile"

            # Vérification immédiate que tout est OK
            aws sts get-caller-identity --profile "$profile" >/dev/null 2>&1
            if [[ $? -ne 0 ]]; then
                echo "❌ Échec de la validation du profil AWS : $profile"
                return 1
            fi

            export AWS_PROFILE="$profile"
            echo "✅ Connecté et profil actif : $AWS_PROFILE"
            break
        else
            echo "⚠️ Sélection invalide. Réessaie."
        fi
    done
}
