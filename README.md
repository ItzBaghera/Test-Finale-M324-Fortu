# M324 – Test finale

CI/CD: provisioning di un'istanza AWS EC2 con Terraform e deploy di un'app Node.js
containerizzata tramite Jenkins.

## Struttura
- `terraform/` — VPC, subnet pubblica, Security Group (porta 80, SSH 22 solo dal proprio IP),
  istanza EC2 `t2.micro` Ubuntu chiamata `jenkins-agent`. La chiave pubblica usata per l'istanza
  è committata in `terraform/deployer.pub`. Output: IP pubblico.
- `app/` — app Node.js "Hello world" + Dockerfile (utente non-root, porta 3000).
- `Jenkinsfile` — pipeline: checkout → terraform plan → terraform apply → docker build → deploy SSH.
  È cross-platform (`sh` su Linux, `bat` su Windows).

## Cosa serve sull'host Jenkins
- `terraform`, `docker`, `aws-cli` raggiungibili nel PATH del servizio Jenkins
- Plugin Jenkins: Pipeline, Git
- Su Windows: il servizio Jenkins deve poter usare Docker Desktop e l'OpenSSH (`ssh`)

## Configurazione (da fare prima di lanciare)

1. **Credenziali AWS in Jenkins** (tipo "Secret text"):
   - ID `aws-creds-id` → AWS Access Key ID
   - ID `aws-creds-secret` → AWS Secret Access Key

2. **Chiave SSH:**
   - La chiave **pubblica** è già nel repo (`terraform/deployer.pub`): Terraform la carica
     sull'istanza in automatico.
   - In Jenkins crea una credenziale "SSH Username with private key", ID `ec2-ssh-key`,
     username `ubuntu`, e incolla la chiave **privata corrispondente** (incl. le righe
     `-----BEGIN OPENSSH PRIVATE KEY-----` / `-----END OPENSSH PRIVATE KEY-----`).
   - Se vuoi usare una coppia tua: `ssh-keygen -t rsa -b 4096 -f m324-key`, poi sostituisci
     `terraform/deployer.pub` con il contenuto di `m324-key.pub` e usa `m324-key` come privata.

3. **`my_ip`**: nessuna configurazione. La pipeline rileva da sola l'IP pubblico dell'host Jenkins
   (`curl https://api.ipify.org`) e lo passa a Terraform come `TF_VAR_my_ip`, così il Security Group
   apre la porta 22 solo verso quell'IP.

## Lancio
Crea una Pipeline in Jenkins di tipo "Pipeline script from SCM" che punta a questo repository
(branch `main`, Script Path `Jenkinsfile`) e avvia **Build Now**.
Al termine l'app risponde su `http://<IP-pubblico-istanza>` (l'IP è nell'output di Terraform e nei
log dello stage Apply, porta 80).

## Verifica locale dell'app (facoltativa)
```bash
cd app
docker build -t hello-world-app .
docker run -d -p 8080:3000 hello-world-app
curl localhost:8080   # -> Hello world
```
