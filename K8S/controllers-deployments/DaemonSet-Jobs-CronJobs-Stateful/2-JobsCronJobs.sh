ssh aen@c1-cp1
cd ~/content/course/04/demos/

#Demo 1 - Executing tasks with Jobs, check out the file job.yaml
#Ensure you define a restartPolicy, the default of a Pod is Always, which is not compatible with a Job.
#We'll need OnFailure or Never, let's look at OnFailure
kubectl apply -f job.yaml


#Follow job status with a watch
kubectl get job --watch


#Get the list of Pods, status is Completed and Ready is 0/1
kubectl get pods


#Let's get some more details about the job...labels and selectors, Start Time, Duration and Pod Statuses
kubectl describe job hello-world-job


#Get the logs from stdout from the Job Pod
kubectl get pods -l job-name=hello-world-job 
kubectl logs PASTE_POD_NAME_HERE


#Our Job is completed, but it's up to use to delete the Pod or the Job.
kubectl delete job hello-world-job


#Which will also delete it's Pods
kubectl get pods




#Demo 2 - Show restartPolicy in action..., check out backoffLimit: 2 and restartPolicy: Never
#We'll want to use Never so our pods aren't deleted after backoffLimit is reached.
kubectl apply -f job-failure-OnFailure.yaml


#Let's look at the pods, enters a backoffloop after 2 crashes
kubectl get pods --watch


#The pods aren't deleted so we can troubleshoot here if needed.
kubectl get pods 


#And the job won't have any completions and it doesn't get deleted
kubectl get jobs 

#So let's review what the job did...Events, created...then deleted. Pods status, 3 Failed.
kubectl describe jobs | more


#Clean up this job
kubectl delete jobs hello-world-job-fail
kubectl get pods



#Demo 3 - Defining a Parallel Job
kubectl apply -f ParallelJob.yaml


#10 Pods will run in parallel up until 50 completions
kubectl get pods




#We can 'watch' the Statuses with watch
watch 'kubectl describe job | head -n 11'


#We'll get to 50 completions very quickly
kubectl get jobs


#Let's clean up...
kubectl delete job hello-world-job-parallel




#Demo 5 - Scheduling tasks with CronJobs
kubectl apply -f CronJob.yaml


#Quick overview of the job and it's schedule
kubectl get cronjobs


#But let's look closer...schedule, Concurrency, Suspend,Starting Deadline Seconds, events...there's execution history
kubectl describe cronjobs | more 


#Get a overview again...
kubectl get cronjobs


#The pods will stick around, in the event we need their logs or other inforamtion. How long?
kubectl get pods --watch


#They will stick around for successfulJobsHistoryLimit, which defaults to three
kubectl get cronjobs -o yaml


#Clean up the job...
kubectl delete cronjob hello-world-cron


#Deletes all the Pods too...
kubectl get pods 
