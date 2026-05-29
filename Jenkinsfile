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
                        runCmd 'terraform init -input=false'
                        runCmd 'terraform plan -input=false -out=tfplan'
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
                // SSH private key matching the public key uploaded by Terraform,
                // stored in Jenkins as an SSH credential with ID "ec2-ssh-key".
                sshagent(['ec2-ssh-key']) {
                    // Give the new instance time to boot and install Docker (via user_data).
                    sleep(time: 90, unit: 'SECONDS')
                    script {
                        if (isUnix()) {
                            sh '''
                                docker save $IMAGE | ssh -o StrictHostKeyChecking=no ubuntu@$EC2_IP "sudo docker load"
                                ssh -o StrictHostKeyChecking=no ubuntu@$EC2_IP "sudo docker rm -f app 2>/dev/null || true"
                                ssh -o StrictHostKeyChecking=no ubuntu@$EC2_IP "sudo docker run -d --name app -p 80:3000 $IMAGE"
                            '''
                        } else {
                            bat '''
                                docker save %IMAGE% | ssh -o StrictHostKeyChecking=no ubuntu@%EC2_IP% "sudo docker load"
                                ssh -o StrictHostKeyChecking=no ubuntu@%EC2_IP% "sudo docker rm -f app || true"
                                ssh -o StrictHostKeyChecking=no ubuntu@%EC2_IP% "sudo docker run -d --name app -p 80:3000 %IMAGE%"
                            '''
                        }
                    }
                }
                echo "App deployed at http://${env.EC2_IP}"
            }
        }
    }
}
