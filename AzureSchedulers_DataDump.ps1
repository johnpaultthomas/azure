param (
    [string] $SubcriptionID = "",
    [string] $ResourceGroup = "",
)

# If you are not already authenticated to Azure
# Connect-AzureRMAccount


Select-AzureRMSubscription -SubscriptionId $SubcriptionID


$JobCollections=Get-AzureRmSchedulerJobCollection -ResourceGroupName $ResourceGroup


$jc=Get-AzureRmSchedulerJob -ResourceGroupName $ResourceGroup -JobCollectionName $JobCollections.JobCollectionName[0]

ForEach($jcname in $JobCollections.JobCollectionName){
$jc = Get-AzureRmSchedulerJob -ResourceGroupName $ResourceGroup -JobCollectionName $jcname
$k=0

    ForEach ($i in $jc)
    {
       $k=$k+1
       Try
        {
                if($i.JobAction.JobActionType -eq "ServiceBusQueue")
                {
                    ($jcname + "," + $k.tostring() + "," + $i.JobName.ToString() + "," + $i.JobAction.ServiceBusMessage.ToString() + "," + $i.JobAction.ServiceBusQueueName.ToString() + "," + $i.Recurrence.ToString()) >> schedulers_servicebus.csv
                }
      
                else 
                {
                    ($jcname + "," + $i.JobName.ToString() + "," + $i.JobAction.URI.ToString() + "," + $i.JobAction.RequestMethod.ToString() + ","+ $i.Recurrence.ToString())  >> schedulers_http.csv
                }
        }
        Catch
        {
              $i.JobName
              $i.JobAction.RequestMethod 
              $i.JobAction.URI 
        }
   }

}


