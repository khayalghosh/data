deb_build_image = "jcids.jfrog.io/obb-int-docker-virtual/deb-builder:0.1.0"
packageName = "jci-interface"

def copyAppFiles(){
    stage("Copy Application Files"){
        sh '''
        cp -rp interfaces/bin interfaces/debian/application/.
        cp -rp interfaces/lib interfaces/debian/application/.
        cp -rp interfaces/install.sh interfaces/debian/application/.
        cp -rp interfaces/version.txt interfaces/debian/application/.
        '''
    }
}

def buildInterfaceDeb(currentVersion, debReleaseRepo){
    stage("Build Deb package"){
		// def releaseVersion = sh(returnStdout: true, script: "grep -i 'release-version' debian/application/config.yml").toString().trim()
        // def (name, currentVersion) = "${releaseVersion}".trim().split(":") 
        println("➤ DEB release version for ${packageName} : ${currentVersion}")
        def cmd = "cd interfaces/debian && bash ./build-debian.sh ${packageName} ${currentVersion}"
        run(cmd)
    }
    stage("Publish Deb package to Jfrog"){
        println("➤ Publish ${packageName} : ${currentVersion}")
        withCredentials([string(credentialsId: "${debReleaseRepo}", variable: 'OBB_RELEASE_REPO') ,string(credentialsId: 'OBB_DEB_API_KEY', variable: 'OBB_DEB_API_KEY')]) {
            def cmd_deb = "curl -H \"X-JFrog-Art-Api:${OBB_DEB_API_KEY}\" -XPUT \"${OBB_RELEASE_REPO}/pool/${packageName}-${currentVersion}.deb;deb.distribution=focal;deb.component=main;deb.architecture=amd64\" -T interfaces/debian/target/${packageName}-${currentVersion}.deb"
            run(cmd_deb)
        }
    }
}

def run(cmd){
    withDockerRegistry(credentialsId: 'OBB_JFROG_USER_CREDENTIALS', url: 'https://jcids.jfrog.io') {
        docker.image("${deb_build_image}").inside {
            sh cmd;
        }
    }
}

def execute(currentVersion, debReleaseRepo){
    copyAppFiles()
    buildInterfaceDeb(currentVersion, debReleaseRepo)
    // publishDebPackage(currentVersion)
}
return this;