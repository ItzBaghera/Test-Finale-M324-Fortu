pipeline {
    agent any

    environment {
        // AWS credentials stored in Jenkins as "Username with password"
        // (Access Key ID = username, Secret Access Key = password) with ID "aws-creds".
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
                    sh 'terraform init -input=false'
                    sh 'terraform plan -input=false -out=tfplan'
                }
            }
        }

        stage('Terraform Apply') {
            // Runs only if the previous stages (including Plan) succeeded.
            steps {
                dir('terraform') {
                    sh 'terraform apply -input=false tfplan'
                    script {
                        env.EC2_IP = sh(
                            returnStdout: true,
                            script: 'terraform output -raw public_ip'
                        ).trim()
                    }
                }
                echo "EC2 public IP: ${env.EC2_IP}"
            }
        }

        stage('Docker Build') {
            steps {
                dir('app') {
                    sh "docker build -t ${IMAGE} ."
                }
            }
        }

        stage('Deploy') {
            steps {
                // SSH private key matching the public key uploaded by Terraform,
                // stored in Jenkins as an SSH credential with ID "ec2-ssh-key".
                sshagent(['ec2-ssh-key']) {
                    sh '''
                        # Wait until SSH is up and Docker has finished installing (via user_data)
                        for i in $(seq 1 30); do
                            if ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 ubuntu@$EC2_IP "command -v docker" >/dev/null 2>&1; then
                                echo "Docker is ready on the instance"
                                break
                            fi
                            echo "Waiting for the instance to be ready... ($i/30)"
                            sleep 10
                        done

                        docker save $IMAGE | ssh -o StrictHostKeyChecking=no ubuntu@$EC2_IP "sudo docker load"
                        ssh -o StrictHostKeyChecking=no ubuntu@$EC2_IP "sudo docker rm -f app 2>/dev/null || true"
                        ssh -o StrictHostKeyChecking=no ubuntu@$EC2_IP "sudo docker run -d --name app -p 80:3000 $IMAGE"
                    '''
                }
                echo "App deployed at http://${env.EC2_IP}"
            }
        }
    }
}
