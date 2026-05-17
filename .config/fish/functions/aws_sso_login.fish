function aws_sso_login --description "Interactive AWS SSO login with profile selection"
    set config_file $AWS_CONFIG_FILE
    if test -z "$config_file"
        set config_file $HOME/.aws/config
    end

    if not test -f $config_file
        echo "❌ Fichier de config introuvable à : $config_file"
        return 1
    end

    echo "📜 Profils AWS SSO disponibles :"
    set profiles (grep -E '^\[profile ' $config_file | string replace -r '^\[profile (.+)\]' '$1')

    if test (count $profiles) -eq 0
        echo "⚠️ Aucun profil SSO trouvé dans le fichier de config."
        return 1
    end

    for i in (seq (count $profiles))
        echo "  $i) $profiles[$i]"
    end

    read -P "Choisir un profil SSO [1-"(count $profiles)"]: " choice

    if test -n "$profiles[$choice]"
        set profile $profiles[$choice]
        echo "🔐 Connexion au profil SSO : $profile ..."
        aws sso login --profile $profile

        aws sts get-caller-identity --profile $profile > /dev/null 2>&1
        if test $status -ne 0
            echo "❌ Échec de la validation du profil AWS : $profile"
            return 1
        end

        set -Ux AWS_PROFILE $profile
        echo "✅ Connecté et profil actif : $AWS_PROFILE"
    else
        echo "⚠️ Sélection invalide. Réessaie."
        return 1
    end
end

# Hyphen alias for bash parity
alias aws-sso-login="aws_sso_login"
