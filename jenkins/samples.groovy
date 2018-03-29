/**
 * Jenkins DSL for Steeltoe Samples
 */

recipients = [
    'ccheetham',
]

samplePaths = [
    'Connectors/src/AspDotNetCore/PostgreSql',
    'Connectors/src/AspDotNetCore/PostgreEFCore',
    'Connectors/src/AspDotNetCore/Redis',
    'Connectors/src/AspDotNetCore/MySqlEFCore',
    'Connectors/src/AspDotNetCore/MySqlEF6',
    'Connectors/src/AspDotNetCore/RabbitMQ',
    'Connectors/src/AspDotNetCore/MySql/MySql',
    'Configuration/src/AspDotNetCore/CloudFoundry',
    'Configuration/src/AspDotNetCore/Simple',
    'Configuration/src/AspDotNetCore/SimpleCloudFoundry',
    'Security/src/CloudFoundrySingleSignon',
    'Management/src/AspDotNetCore/CloudFoundry',
]

def sample2Job(def sample) {
    "steeltoe-samples-${sample.split('/').findAll { !(it in ['src']) }.collect { it.toLowerCase() }.join('-')}"
}

samplePaths.each { samplePath ->
    job(sample2Job(samplePath)) {
        wrappers {
            credentialsBinding {
                usernamePassword('STEELTOE_PCF_CREDENTIALS', 'steeltoe-pcf')
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
        triggers {
            scm('H/15 * * * *')
        }
        steps {
            ansiColor('xterm') {
                shell("ci/jenkins.sh ${samplePath}")
            }
        }
        publishers {
            archiveArtifacts('test.log')
            mailer(recipients.collect { "${it}@pivotal.io" }.join(' '), true, false)
        }
        logRotator {
            numToKeep(5)
        }
    }
}

// vim: et sw=4 sts=4
