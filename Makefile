test:
	ansible-playbook -i hosts.local main.yml -u deploy --private-key ~/.ssh/deploy_rsa.pem