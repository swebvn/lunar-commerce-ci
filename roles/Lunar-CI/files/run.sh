#!/bin/bash
ls /home | grep -v deploy | grep -Ev "`hostname`|tda|sweb" > /tmp/list_users.txt

Update_Source()
{
    filename="/tmp/list_users.txt"
    deploy_key="/root/.ssh/deploy_rsa.pem"

    while IFS= read -r user; do
        # check if user has the deploy key yet in /home/$user/.ssh/
        user_deploy_key="/home/$user/.ssh/deploy_rsa.pem"

        if [ ! -d "/home/$user/.ssh" ]; then
            mkdir -p "/home/$user/.ssh"
            chown $user:$user "/home/$user/.ssh"
            chmod 700 "/home/$user/.ssh"
        fi

        if [ ! -f "$user_deploy_key" ]; then
            cp "$deploy_key" "$user_deploy_key"
            chown $user:$user "$user_deploy_key"
            chmod 600 "$user_deploy_key"
        fi

        for domain_dir in /home/"$user"/domains/*/public_html; do
            if [ -e "$domain_dir/.env" ]; then
                domain=$(basename $(dirname "$domain_dir"))

                su - "$user" -c "{
                    echo "Start building on $domain_dir"
                    cd $domain_dir
                    GIT_SSH_COMMAND=\"ssh -i $user_deploy_key -o StrictHostKeyChecking=no\" git pull origin main
                    if git diff --name-only HEAD@{1} HEAD | grep -qE 'composer\.json|composer\.lock'; then
                        composer install --no-dev --optimize-autoloader --no-ansi --no-interaction
                    fi
                    if git diff --name-only HEAD@{1} HEAD | grep -qE 'package\.json|pnpm-lock\.yaml|\.js|\.css|\.blade\.php'; then
                        CI=1 pnpm install && pnpm run build
                    fi
                    php artisan migrate --force
                    php artisan optimize
                    php artisan route:clear
                    php artisan icon:cache
                    php artisan filament:cache-components
                    php artisan deploy:cleanup
                    php artisan horizon:terminate
                }" || { notice_fail "$domain" && continue; }

                systemctl reload php8.2-fpm

                # echo "Finish build on $domain!" && curl --location 'https://ping2.me/@daudau/sweb-stuff' \
                # --data-urlencode "message=$domain deployed" > /dev/null
            fi
        done

        # remove the deploy key from user's home directory
        if [ -f "$user_deploy_key" ]; then
            rm -f "$user_deploy_key"
        fi
    done < "$filename"
}

notice_fail()
{
    domain="$1"
    echo "Deploy failed on $domain!" && curl --location 'https://ping2.me/@daudau/sweb-stuff' \
    --data-urlencode "message=$domain deploy failed"
}

Update_Source
