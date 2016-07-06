# Schedulable Pattern

### Problem
Originally, it was advisable to avoid using scheduled Apex. This is because when you had a class scheduled using scheduled Apex, it was impossible to update that class. The class was locked because the platform internally stores a serialized instance of that class. Worse, the platform also prevented updates to any classes that were referenced by the scheduled class. This meant that many of your code updates required the additional step of deleting any scheduled jobs and then restarting them after the update.

The problem was even worse if you were building an AppExchange package. It made it virtually impossible to push patches and updates to your users.

Recently Salesforce added a new option called “Deployment Settings” which offers the option shown in figure
(figure omitted here).

Checking this option allows you to deploy updates even if Apex jobs are pending, at the risk of them failing. This option is off by default.

If you attempt or reach these settings on a developer org, you may get an “Insufficient Privileges” error message (meaning, this error appears at the time of publication, but is scheduled to be fixed in Winter 16). As a workaround, you can reach the deployment settings on a developer org by navigating directly to the following URL:

/changemgmt/deploymentSettings.Apexp?retURL=%2Fui%2Fsetup%2FSetup%3Fsetupid%3DDeploy&setupid =DeploymentSettings

### Pattern Solution
You can eliminate the need to select this option by adopting the following design pattern for all scheduled Apex classes. The idea is to create a simple Apex class that is schedulable, that will call into other code, but not reference that code. This schedulable class will be locked when scheduled, but it won’t lock any other code in your application. With luck, it will never need to be updated. What’s more, package installations and upgrades are intelligent enough to recognize that a class has not changed, and will not attempt to update it – thus the fact that the class is locked will not interfere with package deployments and push updates.

```javascript
global class ScheduledDispatcher2 Implements Schedulable {

	public Interface IScheduleDispatched
    {
        void execute(SchedulableContext sc);
    }

    global void execute(SchedulableContext sc)
    {
        Type targetType = Type.forName('GoingAsync5');   
        if(targetType!=null) {
            IScheduleDispatched obj =
            	(IScheduleDispatched)targettype.newInstance();
            obj.execute(sc);   
        }
    }
}
```
The class defines an interface that can be referenced by another class. When the system scheduler calls the execute method, the code uses the Type.forName method to first obtain the type object for the class that will implement the desired functionality, then uses the newInstance method to create an instance of that class. As long as the class implements the IScheduleDispatched interface, you will be able to call its execute method.

In this example, the delegated class is the GoingAsync5 class. The scheduled operation starts the GoingAsync4 batch and aborts the scheduled job. You can use this approach to implement some of the design ideas suggested earlier. You could use it as a backup to queue the GoingAsync4 class if chaining completely fails. You could use it as part of a mechanism for scheduling AsyncRequest__c objects, setting the target scheduled time based on the earliest non-immediate request.

```javascript
public class GoingAsync5
	implements ScheduledDispatcher2.IScheduleDispatched {

    public void execute(SchedulableContext sc)
    {
      	// When used as a backup to start the asnyc framework
      	system.enqueueJob(new GoingAsync4());
      	// Always abort the job on completion
        system.abortJob(sc.getTriggerID());
    }

    public static String getSchedulerExpression(Datetime dt) {
    	// Don't try to schedule Apex before current time + buffer
    	if(dt < DateTime.Now().AddMinutes(1))
    		dt = DateTime.Now().AddMinutes(1);
        return ('' + dt.second() + ' ' + dt.minute() + ' ' +
        	dt.hour() + ' ' + dt.day() + ' ' +
        	dt.month() + ' ? ' + dt.year());
    }

    public static void startScheduler(DateTime scheduledTime, String jobName)
    {

        // Is the job already running?
        List<CronTrigger> jobs =
        	[SELECT Id, CronJobDetail.Name, State, NextFireTime
             FROM CronTrigger
             WHERE CronJobDetail.Name= :jobName];
    	if(jobs.size()>0 && jobs[0].state!='COMPLETED' &&
           jobs[0].state!='ERROR' && jobs[0].state!='DELETED')
    	{
            // It's already running/scheduled

			// Depending on your design you might want to exit,
			// or abort and reschedule if the requested start time
			// is earlier
			return;            
        }

        // If the job exists, it needs to be deleted
        if(jobs.size()>0) system.abortJob(jobs[0].id);


        try
        {
	        System.schedule(jobName,
	                        getSchedulerExpression(scheduledTime),
	                        new ScheduledDispatcher2());
        } catch(Exception ex)
        {
        	system.Debug(ex.getMessage());
        	// Log the error?
        	// Or throw the error to the caller?
        }
    }
}
```
The only tricky part of this code is the startScheduler function – a utility function intended to be called externally. It begins by checking if the scheduled job already exists – you can’t create a new scheduled job with the same name as one that is running. If a job with this name is already running, you have a number of choices. You can just exit, assuming the existing job will serve the same purpose as the current request. You can throw an error. Or you can check the current scheduled time against the requested time, and abort the current job if the requested time is earlier than the scheduled time of the existing job.

Even if the existing job has been completed, you need to delete it if you wish to create a new job with the same name – that’s the job of the system.abortJob call.

Finally, the System.schedule method creates the scheduled Apex job. The getSchedulerExpression function returns a properly formatted expression for the System.schedule method. It also ensures that the scheduled time is after the current time, adding a buffer of one minute. It is essential that you never schedule an Apex job before the current time – doing so will not only fail with an exception, it has been known to create asynchronous job entries that are stuck forever in the queued state, making it impossible to update or delete the scheduled Apex entry point (in this case the ScheduledDispatcher2 class) even if you’ve configured the system to allow updating of classes with jobs in progress (Astute readers may suspect that the reason the sample entry class is named ScheduledDispatcher2 instead of ScheduledDispatcher might relate to the discovery of this phenomena. You would be right).

At this point it is unlikely that the call will fail, as the code has already tested for the most common error conditions. However, there is a limit to the number of jobs that can be scheduled at once, and exceeding that limit will cause an exception. You should consider how you want to handle that situation.

### Changes to Scheduled Apex

**The previous edition of this book described design patterns for use with scheduled Apex that are now obsolete and should be avoided.

Those patterns related to the use of scheduled Apex to chain asynchronous calls. Because it is safe to start a scheduled job in a batch or future call, and safe to start a batch process or make a future call from within a scheduled execute method, it is possible to alternate between them to infinitely chain asynchronous operations. You can also restart a scheduled operation – scheduling the new one for a few seconds after the existing one to implement chaining.

With native chaining support built in to queueable Apex, there is no longer a need to use scheduled Apex in this manner. In fact, with the launch of queueable Apex, Salesforce modified the behavior of scheduled Apex to enforce a minimum time between scheduled executions regardless of the scheduled time you specify. The queueable design patterns described earlier in this chapter are more reliable, impose a lighter system load, and are much faster than previous methods based on scheduled Apex.**
