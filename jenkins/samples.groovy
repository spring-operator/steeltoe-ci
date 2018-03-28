/**
 * Jenkins DSL for Steeltoe Samples
 */

job('steeltoe-samples-configuration-simple') {
    displayName('Steeltoe Samples : Configuration : Simple')
    wrappers {
        credentialsBinding {
            usernamePassword 'STEELTOE_PCF_CREDENTIALS', 'steeltoe-pcf'
        }
        preBuildCleanup()
    }
    label('steeltoe')
    scm {
        git {
            remote {
                github('SteeltoeOSS/Samples', 'https')
                branch('dev')
            }
        }
    }
    steps {
        shell('ci/jenkins.sh Configuration/src/AspDotNetCore/Simple')
    }
    publishers {
            mailer('ccheetham@pivotal.io', true, false)
    }
    logRotator {
        numToKeep 5
    }
}

// vim: et sw=4 sts=4