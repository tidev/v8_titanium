
def build(arch, mode) {
  return {
    // FIXME Technically we could build on linux as well!
    node('osx && git && android-ndk') {
      unstash 'sources'
      sh "./build_v8.sh -n ${env.ANDROID_NDK_R11C} -j8 -l ${arch} -m ${mode}"
      stash includes: "build/${mode}/**", name: "results-${arch}-${mode}"
    }
  }
}

timestamps {
  def gitRevision = '' // we calculate this later for the v8 repo
  // FIXME How do we get the current branch in a detached state?
  def gitBranch = '5.9-lkgr'
  def timestamp = '' // we generate this later
  def v8Version = '' // we calculate this later from the v8 repo
  def modes = ['release', 'debug']
  def arches = ['arm', 'ia32']

  node('osx && git && android-ndk && python') {
    stage('Checkout') {
      // checkout scm
      // Hack for JENKINS-37658 - see https://support.cloudbees.com/hc/en-us/articles/226122247-How-to-Customize-Checkout-for-Pipeline-Multibranch
      checkout([
        $class: 'GitSCM',
        branches: scm.branches,
        extensions: scm.extensions + [
          [$class: 'CleanBeforeCheckout'],
          [$class: 'SubmoduleOption', disableSubmodules: false, parentCredentials: true, recursiveSubmodules: false, reference: '', timeout: 60, trackingSubmodules: false],
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

      // Grab some values we need for the libv8.json file when we package at the end
      dir('v8') {
        gitRevision = sh(returnStdout: true, script: 'git rev-parse HEAD').trim()
        timestamp = sh(returnStdout: true, script: 'date \'+%Y-%m-%d %H:%M:%S\'').trim()
        // build the v8 version
        def MAJOR = sh(returnStdout: true, script: 'grep "#define V8_MAJOR_VERSION" "include/v8-version.h" | awk \'{print $NF}\'').trim()
        def MINOR = sh(returnStdout: true, script: 'grep "#define V8_MINOR_VERSION" "include/v8-version.h" | awk \'{print $NF}\'').trim()
        def BUILD = sh(returnStdout: true, script: 'grep "#define V8_BUILD_NUMBER" "include/v8-version.h" | awk \'{print $NF}\'').trim()
        def PATCH = sh(returnStdout: true, script: 'grep "#define V8_PATCH_LEVEL" "include/v8-version.h" | awk \'{print $NF}\'').trim()
        v8Version = "${MAJOR}.${MINOR}.${BUILD}.${PATCH}"
      }

      // patch v8 and sync dependencies
      withEnv(["PATH+DEPOT_TOOLS=${env.WORKSPACE}/depot_tools"]) {
        dir('v8') {
          sh 'git apply ../ndk11c_5.9.patch'
          sh '../depot_tools/gclient sync --shallow --no-history --reset --force' // needs python
        }
      }

      // stash everything but depot_tools in 'sources'
      stash excludes: 'depot_tools/**', name: 'sources'
      stash includes: 'v8/include/**', name: 'include'
    } // stage
  } // node

  stage('Build') {
    def branches = [failFast: true]
    for (int m = 0; m < modes.size(); m++) {
      def mode = modes[m];
      for (int a = 0; a < arches.size(); a++) {
        def arch = arches[a];
        branches["${arch} ${mode}"] = build(arch, mode);
      }
    }
    parallel(branches)
  } // stage

  node('osx || linux') {
    stage('Package') {
      // unstash v8/include/**
      unstash 'include'
      // Unstash the build artifacts for each arch/mode combination
      for (int m = 0; m < modes.size(); m++) {
        def mode = modes[m];
        for (int a = 0; a < arches.size(); a++) {
          def arch = arches[a];
          unstash "results-${arch}-${mode}"
        }
      }

      // Package each mode
      for (int m = 0; m < modes.size(); m++) {
        def mode = modes[m];

        // write out a JSON file with some metadata about the build
        writeFile file: "build/${mode}/libv8.json", text: """{
	"version": "${v8Version}",
	"git_revision": "${gitRevision}",
	"git_branch": "${gitBranch}",
	"svn_revision": "",
	"timestamp": "${timestamp}"
}
"""
        sh "mkdir -p 'build/${mode}/libs' 'build/${mode}/include' 2>/dev/null"
        sh "cp -R 'v8/include' 'build/${mode}'"
        dir("build/${mode}") {
          echo "Building libv8-${v8Version}-${mode}.tar.bz2..."
          sh "tar -cvj -f libv8-${v8Version}-${mode}.tar.bz2 libv8.json libs include"
          archiveArtifacts "libv8-${v8Version}-${mode}.tar.bz2"
        }
      }
    } // stage

    stage('Publish') {
      if (!env.BRANCH_NAME.startsWith('PR-')) {
        // Publish each mode to S3
        for (int m = 0; m < modes.size(); m++) {
          def mode = modes[m];
          def filename = "build/${mode}/libv8-${v8Version}-${mode}.tar.bz2"
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
      }
    } // stage
  } // node
} // timestamps
