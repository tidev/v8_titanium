#! groovy
// Keep logs/reports/etc of last 10 builds, only keep build artifacts of last build
// (We upload to S3 on any successful build, so we really only need artifacts when testing PR builds)
properties([buildDiscarder(logRotator(numToKeepStr: '10', artifactNumToKeepStr: '1'))])

def build(scm, arch, mode) {
  return {
    def expectedLibraries = ['monolith']
    def labels = 'ninja && git && android-ndk && android-sdk && python'
    if (arch.equals('ia32') || arch.equals('arm')) {
      labels += ' && (osx && xcode-9)' // Need xcode-9 or older on mac, as 32-bit x86 was removed in xcode 10
    } else {
      // 64-bit can be built on xcode 10, so we can use linux or osx
      labels += ' && osx'
    }

    node(labels) {
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
      sh 'rm -rf build/' // Don't include old pre-built libraries/includes that may have been left around

      // patch v8 and sync dependencies
      withEnv(["PATH+DEPOT_TOOLS=${env.WORKSPACE}/depot_tools"]) {
        dir('v8') {
          sh 'rm -rf out.gn/'
          // Force a git clean on everything under v8
          sh '../depot_tools/gclient recurse git clean -fdx'
          // Then apply our patch to avoid grabbing android sdk/ndk
          sh 'git apply ../ndkr19c_7.3.patch'
          sh 'git apply ../compat.patch'
          // Now let gclient get the dependencies.
          sh '../depot_tools/gclient sync --shallow --no-history --reset --force' // needs python
        }
      } // withEnv

      // clean, but be ok with non-zero exit code
      sh returnStatus: true, script: "./build_v8.sh -n ${env.ANDROID_NDK_R19C} -s ${env.ANDROID_SDK} -c"
      // Now manually clean since that usually fails trying to clean non-existant tags dir
      sh 'rm -rf build/' // wipe any previously built libraries
      // Now build
      sh "./build_v8.sh -n ${env.ANDROID_NDK_R19C} -s ${env.ANDROID_SDK} -j8 -l ${arch} -m ${mode}"
      // Now run a sanity check to make sure we built the static libraries we expect
      // We want to fail the build overall if we didn't
      for (int l = 0; l < expectedLibraries.size(); l++) {
        def lib = expectedLibraries[l]
        def modifiedArch = arch
        if (arch.equals('ia32')) {
          modifiedArch = 'x86'
        }
        def libraryName = "build/${mode}/libs/${modifiedArch}/libv8_${lib}.a"
        if (!fileExists(libraryName)) {
          error "Failed to build expected static library: ${libraryName}"
        }
      } // for
      stash includes: "build/${mode}/**", name: "results-${arch}-${mode}"
      stash includes: 'v8/include/**/*.h', name: 'include'
    } // node
  }
}

timestamps {
  def gitRevision = '' // we calculate this later for the v8 repo
  // FIXME How do we get the current branch in a detached state?
  def gitBranch = env.BRANCH_NAME // V8 branch, we use matching names to make life easier
  if (env.BRANCH_NAME.startsWith('PR-')) {
    gitBranch = env.CHANGE_TARGET // use target branch of PR
  }
  def timestamp = '' // we generate this later
  def v8Version = '' // we calculate this later from the v8 repo
  def modes = ['release'] // 'debug'
  def arches = ['arm', 'arm64', 'ia32']

  // In parallel, check out on each node and then build
  // We used to check out once, stash and then unstash, but that is not reccomended for such large amounts of data
  stage('Build') {
    def branches = [failFast: true]
    for (int m = 0; m < modes.size(); m++) {
      def mode = modes[m];
      for (int a = 0; a < arches.size(); a++) {
        def arch = arches[a];
        branches["${arch} ${mode}"] = build(scm, arch, mode);
      }
    }
    parallel(branches)
  } // stage

  node('master') { // can be 'osx || linux', but for build time/network perf, using master means we don't need to download the pieces to the node across the network again
    stage('Package') {
      // check out again, so we can get the v8/include folder
      // FIXME Can we do a sparse checkout here? Or maybe just clone/checkout tip, grab sha of v8 submodule, then clone/checkout that specific SHA sparsely to only get the include dir?
      // i.e. gitRevision = sh(returnStdout: true, script: 'git ls-tree HEAD -- v8').trim().substring(15, 54)

      checkout([
        $class: 'GitSCM',
        branches: scm.branches,
        extensions: scm.extensions + [
          [$class: 'CleanBeforeCheckout'],
          [$class: 'SubmoduleOption', disableSubmodules: true, parentCredentials: true, recursiveSubmodules: false, reference: '', timeout: 60, trackingSubmodules: false],
          [$class: 'CloneOption', depth: 30, honorRefspec: true, noTags: true, reference: '', shallow: true]
        ],
        userRemoteConfigs: scm.userRemoteConfigs
      ])

      // Pull sha of v8 out
      gitRevision = sh(returnStdout: true, script: 'git ls-tree HEAD -- v8').trim().substring(14, 54)
      timestamp = sh(returnStdout: true, script: 'date \'+%Y-%m-%d %H:%M:%S\'').trim()

      // Now unstash v8/include/** folder only!
      unstash 'include'
      // Grab some values we need for the libv8.json file
      dir('v8') {
        // build the v8 version
        def MAJOR = sh(returnStdout: true, script: 'grep "#define V8_MAJOR_VERSION" "include/v8-version.h" | awk \'{print $NF}\'').trim()
        def MINOR = sh(returnStdout: true, script: 'grep "#define V8_MINOR_VERSION" "include/v8-version.h" | awk \'{print $NF}\'').trim()
        def BUILD = sh(returnStdout: true, script: 'grep "#define V8_BUILD_NUMBER" "include/v8-version.h" | awk \'{print $NF}\'').trim()
        def PATCH = sh(returnStdout: true, script: 'grep "#define V8_PATCH_LEVEL" "include/v8-version.h" | awk \'{print $NF}\'').trim()
        v8Version = "${MAJOR}.${MINOR}.${BUILD}.${PATCH}"
        currentBuild.displayName = "${v8Version}-#${currentBuild.number}"
      }

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
