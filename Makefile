test:
	ansible-playbook -i hosts.local main.yml -u deploy --private-key ~/.ssh/deploy_rsa.pem

health:
	ansible-playbook -i hosts.init health.yml --private-key ~/.ssh/deploy_rsa.pem