timestamps {
  node('osx && git && android-ndk && python') {
    stage('Checkout') {
      // checkout scm
      // Hack for JENKINS-37658 - see https://support.cloudbees.com/hc/en-us/articles/226122247-How-to-Customize-Checkout-for-Pipeline-Multibranch
      checkout([
        $class: 'GitSCM',
        branches: scm.branches,
        extensions: scm.extensions + [
          [$class: 'CleanBeforeCheckout'],
          [$class: 'SubmoduleOption', disableSubmodules: false, parentCredentials: true, recursiveSubmodules: true, reference: '', timeout: 60, trackingSubmodules: false],
          [$class: 'CloneOption', depth: 30, honorRefspec: true, noTags: true, reference: '', shallow: true]
        ],
        userRemoteConfigs: scm.userRemoteConfigs
      ])
      if (!fileExists('depot_tools')) {
        sh 'mkdir depot_tools'
        dir('depot_tools') {
          git 'https://chromium.googlesource.com/chromium/tools/depot_tools.git'
        }
      }
    } // stage

    stage('Setup') {
      sh 'git apply 0000-hack-gclient-for-travis.patch'
      withEnv(["PATH+DEPOT_TOOLS=${env.WORKSPACE}/depot_tools"]) {
        dir('v8') {
          sh '../depot_tools/gclient sync' // needs python
        } // dir
      } // withEnv
      sh 'git apply 0001-Fix-cross-compilation-for-Android-from-a-Mac.patch'
      sh 'git apply 0002-Create-standalone-static-libs.patch'
    }

    stage('ARM') {
      sh './build_v8.sh -n /opt/android-ndk-r11c -j8 -l arm'
    }

    stage('x86') {
      sh './build_v8.sh -n /opt/android-ndk-r11c -j8 -l ia32'
    }

    stage('Package') {
      sh './build_v8.sh -t'
      archiveArtifacts 'libv8-*.tar.bz2'
    }
  } // node
} // timestamps
