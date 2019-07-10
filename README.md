# Making the production data available in non production environments for Azure VM based solutions
In the world of devops artifacts flow from non production environments to production environments and data flow from production to non production environments

Making a sanitized version of production data available for non production environments is key in keeping the code quality high. Most of the database based solutions which relies on backup and restore is time consuming and usually triggered overnight to make the data available in dev and testing environments.

But we were recently in a situation where we had to migrate 1TB of data from one environment to another environment within 5 minutes.So we looked into our options and found Azure disk snapshots.Azure Disk snapshots takes a snapshot of the disks with no impact on the VM.

So our idea in theory is to stop the Database services on the Database server for a minute to capture the disk snapshots and recreate the disks using this snapshots on the new environment to attach them to the target Database server

But we had some issues to overcome

We can not bring down production services to make sure the data we capture is consistent on the data disks
Snapshotting multiple disks and recreating them from portal are time consuming
The solution we found and the points to note to get the data migrated consistently are,

Always capture the data from Secondary read only service.Stopping the Secondary Database server for a minute is relatively harmless.The data will get back in sync with primary Database in relatively short time.There will be no downtime as far as Production services are concerned
Database disk layout should be designed in such a way that all the data should reside in Data disks away from OS disks.
No alt text provided for this image
Disks should be snapshotted and recreated through an automated way and preferably multi threaded to reduce the impact on the production DB server.We have successfully automated this using a powershell script and we usually run this from an Azure cloud shell. You can find the disk clone script below https://github.com/johnpaultthomas/azure/blob/master/diskClone.ps1
Once you ran the above script you will have the entire disks with data recreated and available on the target virtual machine.
To make it work you will still need to change the permissions and add/remove respective users on the DB
We highly recommend you to run a sanitization script to remove or hide any critical data from the production, based on your company policy at the end of data migration and before making it available to developers and testers
We tested this multiple times and we can migrate data in excess of 1TB in between azure subscriptions and networks in the same location under 3 minutes.But we tested this mainly for Microsoft SQL Server workloads running on Windows virtual machines.

Please feel free to use the above script and If you can contribute to make it work across different flavors of DB servers and Operating Systems that will be a great help.
