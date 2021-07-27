pipeline {
  agent {
    kubernetes {
      label 'petclinic-cd'
      yamlFile 'jenkins-agent-pod.yaml'
    }
  }

  environment {
    REGISTRY_URL = '54.180.16.187:8000'
    REGISTRY_CREDENTIALS = 'Harbor-docker-registry'
    APP_IMAGE = null
    IMAGE_REPO = 'repo-spring-petclinic-rest'
    IMAGE_NAME = 'spring-petclinic-rest'
    IMAGE_TAG = sh(returnStdout: true, script: '(git rev-parse --short HEAD && echo "_$BUILD_NUMBER") | tr -d "\n"').trim()
    APP_URL='http://ad023ff3956274e04a524f6dfe08fbe1-3c32bf7bdf2ae59d.elb.ap-northeast-2.amazonaws.com/petclinic'
    APP_PORT=80
    PerfURL='ad023ff3956274e04a524f6dfe08fbe1-3c32bf7bdf2ae59d.elb.ap-northeast-2.amazonaws.com'
    ArgoURL='a6543a04066ce419f906c7d9db87374e-260125718.ap-northeast-2.elb.amazonaws.com'
    argocdAppPrefix='petclinic-argocd-helm'
    appWaitTimeout = 60
  }

  stages {
      stage('Build') {
          steps {
            container('maven') {
              sh 'mvn clean compile'
            }
          }
        }
        stage('Unit Test') {
          steps {
            container('maven') {
              sh 'mvn test'
            }
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
              container('maven') {
                sh 'mvn sonar:sonar -s $MAVEN_SETTINGS'
              }
            }
          }
        }
  
    stage('Package') {
      steps {
        container('maven') {
          sh 'mvn clean package -DskipTests'
          archiveArtifacts artifacts: 'target/*.jar', fingerprint: true
        }
      }
    }
    stage('Build Docker image') {
      steps {
        container('docker') {
          script {
            APP_IMAGE = docker.build("${IMAGE_REPO}/${IMAGE_NAME}:${IMAGE_TAG}")
          }
        }
      }
    }
    stage('Push Docker image') {
      steps {
        container('docker') {
          script {
            docker.withRegistry('http://' + REGISTRY_URL, REGISTRY_CREDENTIALS) {
              APP_IMAGE.push()
              APP_IMAGE.push('latest')
            }
          }
        }
      }
    }
    
   stage('Update manifest') {
    
      steps {
        sh """
          git config --global user.name 'skccdevops03'
          git config --global user.email 'skcc.devops03@sk.com'
          git config --global credential.helper cache
          git config --global push.default simple
        """
        git url: 'https://github.com/skccdevops03/petclinic-argocd-helm.git', credentialsId: 'git_skccdevops03', branch: 'main'
        sh """
          sed -i 's/tag:.*/tag: "${IMAGE_TAG}"/g' values.yaml
          git add values.yaml
          git commit -m 'Update Docker image tag: ${IMAGE_TAG}'
          git push origin main
        """
      }
    }
    
    
  
     stage('Argo'){
       steps {
       withCredentials([usernamePassword(credentialsId: 'Argocd_credential', usernameVariable: 'ARGOCD_USER', passwordVariable: 'ARGOCD_PWD')]) {
        container('argocd') {
                sh """
                yes | argocd login --insecure ${ArgoURL} --username ${ARGOCD_USER} --password ${ARGOCD_PWD}
                argocd app sync ${argocdAppPrefix}
                argocd app wait ${argocdAppPrefix} --timeout ${appWaitTimeout}
                argocd logout ${ArgoURL}
                sleep 10
                """
          }
       }
       }
     }
     stage('PerforfmanceTest') {
       steps {
       withCredentials([usernamePassword(credentialsId: 'git_skccdevops03', usernameVariable: 'GIT_USER', passwordVariable: 'GIT_PWD')]) {
         container('jmeter') {
         sh """
         git checkout origin/master
         git config remote.origin.url https://${GIT_USER}:${GIT_PWD}@github.com/skccdevops03/spring-petclinic-rest.git
         git config --global user.email 'skcc.devops03@sk.com'
         git config --global user.name '${GIT_USER}'
          """
          
         sh """
         JVM_ARGS="-Xms1G -Xmx1G" && export JVM_ARGS && /usr/local/jmeter/apache-jmeter-5.4.1/bin/jmeter.sh \
         -n -f -t PerformanceTest/TS01_TC01_AWSPipeline.jmx -Jurl=${PerfURL} \
         -l PerformanceTest/TestResult/Result_${BUILD_NUMBER}.jtl \
         -e -o PerformanceTest/TestResult/Result_html_${BUILD_NUMBER}
         mv jmeter.log PerformanceTest/TestResult/Result_html_${BUILD_NUMBER}/jmeter.log
         """
         
         sh """
         git add . && git commit -am 'Publish Jmeter result' && git push origin HEAD:master 
         """
         }
         }
         }
       post {
       always {
       perfReport 'PerformanceTest/TestResult/Result_${BUILD_NUMBER}.jtl'
       }
       }
       }
    
       stage('API Test') {
      steps {
        container('newman') {
          
          
                    
          sh """
            newman run api_test.json \
                  --env-var 'baseUrl=${APP_URL}' --env-var 'petTypeId=""'\
                  --reporters cli,junit \
                  --reporter-junit-export 'petclinic-report.xml'
          """
        }
      }
      post {
        always {
          junit 'petclinic-report.xml'
        }
      }
    }
  }
}
