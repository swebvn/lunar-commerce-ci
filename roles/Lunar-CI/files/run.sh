#!/bin/bash
ls /home | grep -v deploy | grep -Ev "`hostname`|tda|sweb" > /tmp/list_users.txt

Update_Source()
{
    filename="/tmp/list_users.txt"

    while IFS= read -r user; do
    for domain_dir in /home/"$user"/domains/*/public_html/; do
        if [ -e "$domain_dir/.env" ]; then
            cd "$domain_dir"
            sudo git config --global --add safe.directory "$domain_dir"
            sudo git pull origin main
            sudo composer install --no-dev --optimize-autoloader --no-ansi --no-interaction
            sudo pnpm install && sudo pnpm build
            sudo php artisan migrate --force
            sudo php artisan optimize
            sudo php artisan icon:cache
            sudo php artisan horizon:terminate
            sudo chown $user:$user -R $domain_dir/*
            sudo chown $user:$user -R $domain_dir/.*
            sudo systemctl restart php8.2-fpm
            echo "Finish build on $user!"
        fi
    done
done < "$filename"
    
}
Update_Source
