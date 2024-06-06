test:
	ansible-playbook -i hosts.local main.yml -u deploy --private-key ~/.ssh/deploy_rsa.pem

health:
	ansible-playbook health.yml -i hosts.ini -f 20 -u deploy --private-key ~/.ssh/deploy_rsa.pem

deploy:
	ansible-playbook main.yml -i hosts.init -f 5 -u deploy --private-key ~/.ssh/deploy_rsa.pem