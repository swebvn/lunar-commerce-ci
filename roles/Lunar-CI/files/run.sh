#!/bin/bash
ls /home | grep -v deploy | grep -Ev "`hostname`|tda|sweb" > /tmp/list_users.txt

Update_Source()
{
    filename="/tmp/list_users.txt"

    while IFS= read -r user; do
        for domain_dir in /home/"$user"/domains/*/public_html; do
            if [ -e "$domain_dir/.env" ]; then
                domain=$(basename $(dirname "$domain_dir"))
                sudo git config --global --add safe.directory "$domain_dir"
                cd "$domain_dir" || continue
                sudo git pull origin main || { notice_fail "$domain"; continue; }

                # we only run when the composer.lock changed
                if git diff --name-only HEAD@{1} HEAD | grep -qE 'composer\.json|composer\.lock'; then
                    sudo composer install --no-dev --optimize-autoloader --no-ansi --no-interaction || { notice_fail "$domain"; continue; }
                fi

                # check if
                if git diff --name-only HEAD@{1} HEAD | grep -qE 'package\.json|pnpm-lock\.yaml|\.js|\.css|\.blade\.php'; then
                    sudo pnpm install && sudo pnpm run build || { notice_fail "$domain"; continue; }
                fi
                sudo php artisan migrate --force || { notice_fail "$domain"; continue; }
                sudo php artisan optimize || { notice_fail "$domain"; continue; }
                sudo php artisan icon:cache || { notice_fail "$domain"; continue; }
                sudo php artisan filament:cache-components || { notice_fail "$domain"; continue; }
                sudo php artisan deploy:cleanup || { notice_fail "$domain"; continue; }
                sudo php artisan horizon:terminate || { notice_fail "$domain"; continue; }
                sudo chown $user:$user -R "$domain_dir"/* || { notice_fail "$domain"; continue; }
                sudo chown $user:$user -R "$domain_dir"/.* || { notice_fail "$domain"; continue; }
                sudo systemctl reload php8.2-fpm || { notice_fail "$domain"; continue; }
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
