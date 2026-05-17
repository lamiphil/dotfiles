function aws_switch_profile --description "Switch AWS credentials profile interactively"
    set credentials_file $AWS_SHARED_CREDENTIALS_FILE
    if test -z "$credentials_file"
        set credentials_file $HOME/.aws/credentials
    end

    if not test -f $credentials_file
        echo "❌ Fichier de credentials introuvable à : $credentials_file"
        return 1
    end

    echo "📜 Profils AWS disponibles :"
    set profiles (grep '^\[' $credentials_file | string replace -r '\[|\]' '')

    if test (count $profiles) -eq 0
        echo "⚠️ Aucun profil trouvé."
        return 1
    end

    for i in (seq (count $profiles))
        echo "  $i) $profiles[$i]"
    end

    read -P "Choisir un profil [1-"(count $profiles)"]: " choice

    if test -n "$profiles[$choice]"
        set -Ux AWS_PROFILE $profiles[$choice]
        echo "✅ Profil actif : $AWS_PROFILE"
    else
        echo "⚠️ Sélection invalide. Réessaie."
        return 1
    end
end

# Hyphen alias for bash parity
alias aws-switch-profile="aws_switch_profile"
