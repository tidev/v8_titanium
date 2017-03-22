
def build(arch) {
  return {
    // FIXME Technically we could build on linux as well!
    node('osx && git && android-ndk') {
      unstash 'sources'
      sh "./build_v8.sh -n /opt/android-ndk-r11c -j8 -l ${arch}"
      stash includes: 'build/**/*', name: "results-${arch}"
    }
  }
}

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
      // FIXME Don't hack this and let it grab the Android SDK/NDK it's configured to be built with, then pass that along!
      sh 'git apply 0000-hack-gclient-for-travis.patch'
      withEnv(["PATH+DEPOT_TOOLS=${env.WORKSPACE}/depot_tools"]) {
        dir('v8') {
          // TODO Grab the git/svn revision, timestamp, and git branch for libv8.json here!
          sh '../depot_tools/gclient sync --shallow --no-history --reset' // needs python
        } // dir
      } // withEnv
      sh 'git apply 0001-Fix-cross-compilation-for-Android-from-a-Mac.patch'
      sh 'git apply 0002-Create-standalone-static-libs.patch'
      // stash everything but depot_tools
      stash excludes: 'depot_tools/**', name: 'sources'
    } // stage
  } // node

  stage('Build') {
    parallel(
      'ARM': build('arm'),
      'x86': build('ia32'),
      failFast: true
    )
  } // stage

  node('osx && git') {
    stage('Package') {
      // unstash v8 and build scripts
      // FIXME Technically we only need v8/include/** and build_v8.sh
      unstash 'sources'
      // unstash the built parts
      unstash 'results-arm'
      unstash 'results-ia32'
      sh './build_v8.sh -t'
      archiveArtifacts 'build/*/libv8-*.tar.bz2'
    } // stage

    stage('Publish') {
      if (!env.BRANCH_NAME.startsWith('PR-')) {
        def filename = sh(returnStdout: true, script: 'ls build/*/libv8-*.tar.bz2').trim()
        step([
          $class: 'S3BucketPublisher',
          consoleLogLevel: 'INFO',
          entries: [[
            bucket: 'timobile.appcelerator.com/libv8',
            gzipFiles: false,
            selectedRegion: 'us-east-1',
            sourceFile: filename,
            uploadFromSlave: true,
            userMetadata: []
          ]],
          profileName: 'Jenkins',
          pluginFailureResultConstraint: 'FAILURE',
          userMetadata: []])
      }
    } // stage
  } // node
} // timestamps
