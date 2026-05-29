// Helper: runs a command with the right shell depending on the OS
// (sh on Linux/macOS, bat on Windows). Makes the pipeline cross-platform.
def runCmd(cmd) {
    if (isUnix()) {
        sh cmd
    } else {
        bat cmd
    }
}

pipeline {
    agent any

    environment {
        // AWS credentials stored in Jenkins as two "Secret text" credentials.
        AWS_ACCESS_KEY_ID     = credentials('aws-creds-id')
        AWS_SECRET_ACCESS_KEY = credentials('aws-creds-secret')
        AWS_DEFAULT_REGION    = 'eu-central-1'
        IMAGE                 = 'hello-world-app:latest'
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Terraform Plan') {
            steps {
                dir('terraform') {
                    script {
                        if (isUnix()) {
                            sh '''
                                export TF_VAR_my_ip="$(curl -s https://api.ipify.org)/32"
                                terraform init -input=false
                                terraform plan -input=false -out=tfplan
                            '''
                        } else {
                            bat '''
                                for /f %%i in ('curl -s https://api.ipify.org') do set TF_VAR_my_ip=%%i/32
                                terraform init -input=false
                                terraform plan -input=false -out=tfplan
                            '''
                        }
                    }
                }
            }
        }

        stage('Terraform Apply') {
            // Runs only if the previous stages (including Plan) succeeded.
            steps {
                dir('terraform') {
                    script {
                        runCmd 'terraform apply -input=false tfplan'
                        if (isUnix()) {
                            env.EC2_IP = sh(returnStdout: true, script: 'terraform output -raw public_ip').trim()
                        } else {
                            env.EC2_IP = bat(returnStdout: true, script: '@terraform output -raw public_ip').trim()
                        }
                    }
                }
                echo "EC2 public IP: ${env.EC2_IP}"
            }
        }

        stage('Docker Build') {
            steps {
                dir('app') {
                    script {
                        runCmd "docker build -t ${IMAGE} ."
                    }
                }
            }
        }

        stage('Deploy') {
            steps {
                // SSH private key stored in Jenkins (ID "ec2-ssh-key"). We use
                // withCredentials + "ssh -i" instead of the sshagent step, because
                // the SSH Agent plugin is not compatible with Windows' native OpenSSH.
                withCredentials([sshUserPrivateKey(credentialsId: 'ec2-ssh-key', keyFileVariable: 'SSH_KEY', usernameVariable: 'SSH_USER')]) {

                    script {
                        if (isUnix()) {
                            sh '''
                                SSH_OPTS="-i $SSH_KEY -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"
                                docker save $IMAGE | ssh $SSH_OPTS ubuntu@$EC2_IP "sudo docker load"
                                ssh $SSH_OPTS ubuntu@$EC2_IP "sudo docker rm -f app 2>/dev/null || true"
                                ssh $SSH_OPTS ubuntu@$EC2_IP "sudo docker run -d --name app -p 80:3000 $IMAGE"
                            '''
                        } else {
                            // Jenkins may store the key with CRLF; Windows OpenSSH needs LF.
                            // Normalize to LF in a workspace file, then use it.
                            powershell '[IO.File]::WriteAllText("$env:WORKSPACE/id_deploy", ([IO.File]::ReadAllText($env:SSH_KEY) -replace "`r",""))'
                            bat '''
                                icacls "%WORKSPACE%\\id_deploy" /inheritance:r /grant:r "*S-1-5-18:F"
                                docker save %IMAGE% | ssh -i "%WORKSPACE%\\id_deploy" -o StrictHostKeyChecking=no -o UserKnownHostsFile=NUL ubuntu@%EC2_IP% "sudo docker load"
                                ssh -i "%WORKSPACE%\\id_deploy" -o StrictHostKeyChecking=no -o UserKnownHostsFile=NUL ubuntu@%EC2_IP% "sudo docker rm -f app || true"
                                ssh -i "%WORKSPACE%\\id_deploy" -o StrictHostKeyChecking=no -o UserKnownHostsFile=NUL ubuntu@%EC2_IP% "sudo docker run -d --name app -p 80:3000 %IMAGE%"
                            '''
                        }
                    }
                }
                echo "App deployed at http://${env.EC2_IP}"
            }
        }
    }
}
