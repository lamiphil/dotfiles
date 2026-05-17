function dcrf --description "docker compose: restart filebeat"
    docker compose down filebeat
    docker compose up filebeat -d
end
