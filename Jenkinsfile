
import groovy.json.JsonOutput

/**
 * Notify the Atomist services about the status of a build based from a
 * git repository.
 */
def notifyAtomist(String workspaceIds, String buildTag, String buildStatus, String buildPhase="FINALIZED") {
    if (!workspaceIds) {
        echo 'No Atomist workspace IDs, not sending build notification'
        return
    }
    def payload = JsonOutput.toJson(
        [
            name: env.JOB_NAME,
            duration: currentBuild.duration,
            build: [
                number: buildTag,
                phase: buildPhase,
                status: buildStatus,
                full_url: env.BUILD_URL,
                scm: [
                    url: env.GIT_URL,
                    branch: env.GIT_BRANCH,
                    commit: env.GIT_COMMIT
                ]
            ]
        ]
    )
    workspaceIds.split(',').each { workspaceId ->
        String endpoint = "https://webhook.atomist.com/atomist/jenkins/teams/${workspaceId}"
        sh "curl -x http://app-proxy:3128 --silent -X POST -H 'Content-Type: application/json' -d '${payload}' ${endpoint}"
    }
}

/**
 * Send Image-link event to Atomist to associate the new image to the commit
 */
def sendImageLink(
    String workspaceIds,
    String owner,
    String repo,
    String commit,
    String image
) {
    if (!workspaceIds) {
        echo 'No Atomist workspace IDs, not sending image-link event'
        return
    }

    def payload = JsonOutput.toJson(
        [
            git: [ owner: owner, repo: repo, sha: commit ],
            docker: [ image: image ],
            type: "link-image",
        ]
    )
    workspaceIds.split(',').each { workspaceId ->
        String endpoint = "https://webhook.atomist.com/atomist/link-image/teams/${workspaceId}"
        sh "curl --silent -X POST -H 'Content-Type: application/json' -d '${payload}' ${endpoint}"
    }
};

pipeline {

    agent {
        docker {
            image '4oh4/jenkins-docker:latest'
            args  '-v /var/run/docker.sock:/var/run/docker.sock -e http_proxy=http://app-proxy:3128 -e https_proxy=http://app-proxy:3128 -e HTTP_PROXY=http://app-proxy:3128 -e HTTPS_PROXY=http://app-proxy:3128'
        }
    }
    environment {
        DOCKER_BUILD_ARGS = '--pull --no-cache'
        DOCKER_REGISTRY = 'registry.docker.io'
        IMAGE_NAME = 'docker-base-dotnet'
        REQUESTS_CA_BUNDLE = '/etc/ssl/certs/ca-certificates.crt'
        ATOMIST_WORKSPACES = 'AMD5LEAQB'
        BUILD_TAG = sh(script: 'echo $(cat VERSION)-$(date "+%Y%m%d%H%M%S")', , returnStdout: true).trim()
        GH_OWNER = 'valyria-poc-urth'
        GH_REPO = 'docker-base-dotnet'
    }
    stages {
       stage('Notify') {
            steps {
                echo 'Sending build start...'
                notifyAtomist(env.ATOMIST_WORKSPACES, env.BUILD_TAG, 'STARTED', 'STARTED')
            }
        }
        stage('build') {
            steps { 
                sh 'docker build --build-arg http_proxy=http://app-proxy:3128 --build-arg https_proxy=http://app-proxy:3128 -t ${IMAGE_NAME} .' 
            }
        }

        stage('release') {
            when {
              anyOf { branch 'master'; branch 'develop' }
            }
            steps {
                withCredentials([
                    usernamePassword(credentialsId: 'dockerhub', usernameVariable: 'DOCKER_CREDENTIALS_USR', passwordVariable: 'DOCKER_CREDENTIALS_PSW')]){
                        sh "docker login -u ${DOCKER_CREDENTIALS_USR} -p '${DOCKER_CREDENTIALS_PSW}'"
                        sh 'docker tag ${IMAGE_NAME} ${DOCKER_CREDENTIALS_USR}/${IMAGE_NAME}:${BUILD_TAG}'
                        sh 'docker tag ${IMAGE_NAME} ${DOCKER_CREDENTIALS_USR}/${IMAGE_NAME}:latest'
                        sh 'docker push ${DOCKER_CREDENTIALS_USR}/${IMAGE_NAME}:${BUILD_TAG}'
                        sh 'docker push ${DOCKER_CREDENTIALS_USR}/${IMAGE_NAME}:latest'
                        sendImageLink(
                            env.ATOMIST_WORKSPACES,
                            env.GH_OWNER,
                            env.GH_REPO,
                            env.GIT_COMMIT,
                            '${DOCKER_CREDENTIALS_USR}/${IMAGE_NAME}:${BUILD_TAG}'
                        )
                }
            }
        }
    }
    post {
        always {
            echo 'Post notification...'
            notifyAtomist(env.ATOMIST_WORKSPACES, env.BUILD_TAG, currentBuild.currentResult)
        }
    }
}
