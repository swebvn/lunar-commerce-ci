## Run deploy script
```bash
ansible-playbook -i hosts.txt main.yml -u deploy --private-key /opt/key_deploy/id_rsa_deploy
```