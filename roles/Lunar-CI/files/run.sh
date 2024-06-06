#!/bin/bash
ls /home | grep -v deploy | grep -Ev "`hostname`|tda|sweb" > /tmp/list_users.txt

Update_Source()
{
    filename="/tmp/list_users.txt"
    deploy_key="/root/.ssh/deploy_rsa.pem"

    while IFS= read -r user; do
        # check if user has the deploy key yet in /home/$user/.ssh/
        if [ -e "$user_deploy_key" ]; then
            cp "$deploy_key" "/home/$user/.ssh/deploy_rsa.pem"
            chown $user:$user "/home/$user/.ssh/deploy_rsa.pem"
            chmod 600 "/home/$user/.ssh/deploy_rsa.pem"
        fi
        user_deploy_key="/home/$user/.ssh/deploy_rsa.pem"

        for domain_dir in /home/"$user"/domains/*/public_html; do
            if [ -e "$domain_dir/.env" ]; then
                domain=$(basename $(dirname "$domain_dir"))
                sudo git config --global --add safe.directory "$domain_dir"
                cd "$domain_dir" || continue

                su - "$user" -c "
                    GIT_SSH_COMMAND=\"ssh -i $user_deploy_key\" git pull origin main
                    if git diff --name-only HEAD@{1} HEAD | grep -qE 'composer\.json|composer\.lock'; then
                        composer install --no-dev --optimize-autoloader --no-ansi --no-interaction
                    fi
                    if git diff --name-only HEAD@{1} HEAD | grep -qE 'package\.json|pnpm-lock\.yaml|\.js|\.css|\.blade\.php'; then
                        pnpm install && pnpm run build
                    fi
                    php artisan migrate --force
                    php artisan optimize
                    php artisan icon:cache
                    php artisan filament:cache-components
                    php artisan deploy:cleanup
                    php artisan horizon:terminate
                " || { notice_fail "$domain" && continue; }

                systemctl reload php8.2-fpm

                echo "Finish build on $domain!" && curl --location 'https://ping2.me/@daudau/sweb-stuff' \
                --data-urlencode "message=$domain deployed" > /dev/null
            fi
        done
    done < "$filename"
}

notice_fail()
{
    domain="$1"
    curl --location 'https://ping2.me/@daudau/sweb-stuff' \
    --data-urlencode "message=$domain deploy failed"
}

Update_Source
