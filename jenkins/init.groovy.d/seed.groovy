import jenkins.model.*
import org.jenkinsci.plugins.workflow.job.WorkflowJob
import org.jenkinsci.plugins.workflow.cps.CpsScmFlowDefinition
import hudson.plugins.git.*
import hudson.triggers.TimerTrigger

def j = Jenkins.instance
def name = 'DevSecOps-ESPRIT'
if (j.getItem(name) == null) {
  WorkflowJob job = j.createProject(WorkflowJob, name)
  def scm = new GitSCM('https://github.com/Safwen-amaira/DevSecOps-ESPRIT.git')
  scm.branches = [new BranchSpec('*/master')]
  job.definition = new CpsScmFlowDefinition(scm, 'pipeline/Jenkinsfile')
  job.addTrigger(new TimerTrigger('H/5 * * * *'))
  job.save()
}
