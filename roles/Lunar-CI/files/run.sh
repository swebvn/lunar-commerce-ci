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
                sudo composer install --no-dev --optimize-autoloader --no-ansi --no-interaction || { notice_fail "$domain"; continue; }
                sudo pnpm install && sudo pnpm build || { notice_fail "$domain"; continue; }
                sudo php artisan migrate --force || { notice_fail "$domain"; continue; }
                sudo php artisan optimize || { notice_fail "$domain"; continue; }
                sudo php artisan icon:cache || { notice_fail "$domain"; continue; }
                sudo php artisan page-cache:clear || { notice_fail "$domain"; continue; }
                sudo php artisan horizon:terminate || { notice_fail "$domain"; continue; }
                sudo chown $user:$user -R "$domain_dir"/* || { notice_fail "$domain"; continue; }
                sudo chown $user:$user -R "$domain_dir"/.* || { notice_fail "$domain"; continue; }
                sudo systemctl reload php8.2-fpm || { notice_fail "$domain"; continue; }
                echo "Finish build on $domain!" && curl --location 'https://ping2.me/@daudau/sweb-stuff' \
                --data-urlencode "message=$domain deployed"
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
