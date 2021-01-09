node {
   stage('Scm checkout'){
      git 'https://github.com/Nagendra-ch/test2'
   }
   stage('maven buils'){
      sh 'mvn clean package'
   }
   stage('Docker image')
   {
      docker.withRegistry('https://registry.hub.docker.com', 'DockerHub') {

        def customImage = docker.build("my-image:${env.BUILD_ID}")

        /* Push the container to the custom Registry */
        customImage.push()
      
      /*sh 'docker build -t nagas400/my-app:1.0.0 .'*/
    }
   }
}