function dcrd --description "docker compose: restart detached"
    docker compose down
    and docker compose up -d
end
