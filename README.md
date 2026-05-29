# M324 – Test finale

CI/CD: provisioning di un'istanza AWS EC2 con Terraform e deploy di un'app Node.js
containerizzata tramite Jenkins.

## Struttura
- `terraform/` — VPC, subnet pubblica, Security Group (porta 80, SSH 22 solo dal proprio IP),
  istanza EC2 `t2.micro` Ubuntu chiamata `jenkins-agent`. Output: IP pubblico.
- `app/` — app Node.js "Hello world" + Dockerfile (utente non-root, porta 3000).
- `Jenkinsfile` — pipeline: checkout → terraform plan → terraform apply → docker build → deploy SSH.

## Cosa serve sull'host Jenkins
- `terraform`, `docker`, `aws-cli`
- Plugin Jenkins: SSH Agent, Pipeline, Git

## Configurazione (da fare prima di lanciare)

1. **Credenziali AWS in Jenkins** (tipo "Secret text"):
   - ID `aws-creds-id` → AWS Access Key ID
   - ID `aws-creds-secret` → AWS Secret Access Key

2. **Chiave SSH:**
   - Genera una coppia: `ssh-keygen -t rsa -b 4096 -f m324-key`
   - In Jenkins crea un credential "SSH Username with private key", ID `ec2-ssh-key`,
     username `ubuntu`, e incolla la chiave **privata** (`m324-key`).

3. **Variabili Terraform** — crea il file `terraform/terraform.tfvars`:
   ```hcl
   my_ip           = "<IP-PUBBLICO-DELL-HOST-JENKINS>/32"
   public_key_path = "<percorso-della-chiave-pubblica m324-key.pub>"
   ```
   > `my_ip` deve essere l'IP da cui Jenkins fa l'SSH, perché il Security Group
   > apre la porta 22 solo verso quell'IP.

## Lancio
Crea una Pipeline in Jenkins che punta a questo repository (legge il `Jenkinsfile`) e avvia la build.
Al termine l'app risponde su `http://<IP-pubblico-istanza>` (l'IP è negli output di Terraform).

## Verifica locale dell'app (facoltativa)
```bash
cd app
docker build -t hello-world-app .
docker run -d -p 8080:3000 hello-world-app
curl localhost:8080   # -> Hello world
```
