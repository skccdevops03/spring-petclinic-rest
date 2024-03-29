pipeline {
    agent any
    
    environment {
            GIT_COMMIT_SHORT = sh(returnStdout: true, script: 'git rev-parse --short HEAD').trim()
            APP_IMAGE = null
            IMAGE_REPO = 'repo-spring-petclinic-rest'
            IMAGE_NAME = 'spring-petclinic-rest'
            //IMAGE_TAG = '${BUILD_ID}_${BUILD_NUMBER}'
            IMAGE_TAG = sh(returnStdout: true, script: '(git rev-parse --short HEAD && echo "_$BUILD_NUMBER") | tr -d "\n"').trim()
            REGISTRY_URL = 'http://3.38.12.213:8000'
            REGISTRY_CREDENTIALS = 'credential_harbor'
        }
    
    stages {
        stage('Build') {
            steps {
                sh './mvnw clean compile'
            }
        }
        stage('Unit Test') {
    		steps {
        		sh './mvnw test'
    		}
    		post {
        		always {
            		junit 'target/surefire-reports/*.xml'
            		step([ $class: 'JacocoPublisher' ])
        		}
    		}
		}
	stage('Static Code Analysis') {
    		steps {
        		configFileProvider([configFile(fileId: 'maven-settings', variable: 'MAVEN_SETTINGS')]) {
            	sh './mvnw sonar:sonar -s $MAVEN_SETTINGS'
           
        		}
    		}
		}
	stage('Package') {
            steps {
                sh "./mvnw package -DskipTests"
                archiveArtifacts artifacts: 'target/*.jar', fingerprint: true
            }
        }
        stage('Build Docker image') {
            steps {
                   
                script {
                        APP_IMAGE = docker.build("${IMAGE_REPO}/${IMAGE_NAME}:${BUILD_NUMBER}")
                }   
              
            }
        }
        stage('Push Docker image') {
            steps {
              
                script {
                    docker.withRegistry(REGISTRY_URL, REGISTRY_CREDENTIALS) {
                    APP_IMAGE.push()
                        APP_IMAGE.push('latest')
                    }
                }
                      
            }
        }
        
    }    
}
