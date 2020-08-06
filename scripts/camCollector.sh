#!/bin/bash
#
#Licensed Materials - Property of IBM
#5737-E67
#(C) Copyright IBM Corporation 2016-2020 All Rights Reserved.
#US Government Users Restricted Rights - Use, duplication or
#disclosure restricted by GSA ADP Schedule Contract with IBM Corp.
#

usage() { echo "Usage: $0" 1>&2; exit 1; }

collectDiagnosticsData() {
    echo "******************************* Manage Services diagnostics data collected on ${ms_diagnostic_collection_date} *******************************"
    echo -e "\n"

    infrastructure_management_ns="management-infrastructure-management"
    common_services_ns="ibm-common-services"
    podLogsLocation="/var/camlog"

    echo "**********************************************************"
    echo "GET OpenShift Client version"
    echo "**********************************************************"
    oc version
    echo -e "\n"
    
    echo "**********************************************************"
    echo "GET OpenShift namespaces"
    echo "**********************************************************"
    oc get namespaces
    echo -e "\n"

    echo "**********************************************************"
    echo "GET Persistent Volume Claims in $infrastructure_management_ns namespace"
    echo "**********************************************************"
    oc get persistentvolumeclaims --namespace=$infrastructure_management_ns
    echo -e "\n"

    echo "**********************************************************"
    echo "DESCRIBE Persistent Volume Claims in $infrastructure_management_ns namespace"
    echo "**********************************************************"
    echo -e "\n"

    getPersistentVolumeClaimsResult=$(oc get persistentvolumeclaims --namespace=$infrastructure_management_ns -o custom-columns=NAME:.metadata.name --no-headers)
    echo "Running DESCRIBE for the following Persistent Volume Claims"
    echo "-----------------------------------------------------------"
    echo "${getPersistentVolumeClaimsResult}"
    echo -e "\n"

    echo "$getPersistentVolumeClaimsResult" |
    while read persistentVolumeClaim; do
        oc describe persistentvolumeclaims $persistentVolumeClaim --namespace=$infrastructure_management_ns
        echo -e "----------------------------------------------------------------\n"
    done
    echo -e "\n"

    echo "**********************************************************"
    echo "GET Manage Service Persistent Volumes"
    echo "**********************************************************"
    getPersistentVolumeResult=$(oc get persistentvolumeclaims --namespace=$infrastructure_management_ns -o custom-columns=PVNAME:spec.volumeName --no-headers)
    echo "Running DESCRIBE for the following Persistent Volume"
    echo "-----------------------------------------------------------"
    echo "${getPersistentVolumeResult}"
    echo -e "\n"

    echo "$getPersistentVolumeResult" |
    while read persistentVolume; do
        oc describe persistentvolume $persistentVolume
        echo -e "----------------------------------------------------------------\n"
    done
    echo -e "\n"

    echo "**********************************************************"
    echo "GET ConfigMaps in $infrastructure_management_ns namespace"
    echo "**********************************************************"
    oc get configmaps --namespace=$infrastructure_management_ns
    echo -e "\n"

    echo "**********************************************************"
    echo "DESCRIBE OAUTH-CLIENT-MAP ConfigMap in $infrastructure_management_ns namespace"
    echo "**********************************************************"
    oc describe configmaps oauth-client-map --namespace=$infrastructure_management_ns
    echo -e "\n"

    echo "**********************************************************"
    echo "GET OpenShift Pods in $infrastructure_management_ns namespace"
    echo "**********************************************************"
    oc get pods --namespace=$infrastructure_management_ns
    echo -e "\n"

    echo "**********************************************************"
    echo "DESCRIBE OpenShift Pods in $infrastructure_management_ns namespace"
    echo "**********************************************************"
    echo -e "\n"

    getMSPodsResult=$(oc get pods --namespace=$infrastructure_management_ns -o custom-columns=NAME:.metadata.name --no-headers)
    echo "Running DESCRIBE for the following pods"
    echo "---------------------------------------"
    echo "${getMSPodsResult}"
    echo -e "\n"

    echo "$getMSPodsResult" |
    while read msPodName; do
        oc describe pods $msPodName --namespace=$infrastructure_management_ns
        echo -e "----------------------------------------------------------------\n"
    done
    echo -e "\n"

    echo "**********************************************************"
    echo "Downloading logs from Manage Services pods"
    echo "**********************************************************"
    echo "$getMSPodsResult" |
    while read msPodName; do
        echo "Downloading logs from pod ${msPodName}"
        if [[ $msPodName = *"mongo"* ]]; then
            oc cp ${msPodName}:/var/log/mongodb ${ms_diagnostic_data_folder}/${msPodName} --namespace=$infrastructure_management_ns 2>&1
            echo "Successfully downloaded logs from pod ${msPodName}"
        elif [[ $msPodName != "cam-controller-"* ]] && [[ $msPodName != "cam-proxy-"* ]] && [[ $msPodName = "cam-"* ]]; then
            podHostname=$(oc exec ${msPodName} hostname)
            echo "pod Hostname is: $podHostname"
            oc cp ${msPodName}:${podLogsLocation}/${podHostname}/${msPodName} ${ms_diagnostic_data_folder}/${msPodName} --namespace=$infrastructure_management_ns 2>&1
            echo "Successfully downloaded logs from pod ${msPodName}"
        fi
    done
    echo -e "\n"
   
    echo "**********************************************************"
    echo "GET OpenShift Pods in $common_services_ns namespace"
    echo "**********************************************************"
    oc get pods --namespace=$common_services_ns
    echo -e "\n"

    echo "**********************************************************"
    echo "DESCRIBE OpenShift Pods in $common_services_ns namespace"
    echo "**********************************************************"
    echo -e "\n"
    
    getCommonServicesPodsResult=$(oc get pods --namespace=$common_services_ns -o custom-columns=NAME:.metadata.name --no-headers)
    echo "Running DESCRIBE for the following pods"
    echo "---------------------------------------"
    echo "${getCommonServicesPodsResult}"
    echo -e "\n"

    echo "$getCommonServicesPodsResult" |
    while read podName; do
        oc describe pods $podName --namespace=$common_services_ns
        echo -e "----------------------------------------------------------------\n"
    done
}

#########################################################################################
#                                MAIN
#########################################################################################

echo "**********************************************************"
echo "Checking for OpenShift Client"
echo "**********************************************************"
if ! which oc; then
    echo "oc command not found. Ensure that you have oc installed."
    exit 1
fi
echo -e "\n"

echo "**********************************************************"
echo "Checking whether user has logged in to the OpenShift Cluster"
echo "**********************************************************"
if ! oc get namespaces > /dev/null; then
    echo "Ensure that you have logged in to your OpenShift Cluster before running this command."
    exit 1
else
  echo "User $(oc whoami) is logged in to the OpenShift Cluster."
fi
echo -e "\n"

ms_diagnostic_collection_date=`date +"%d_%m_%y_%H_%M_%S"`
echo "******************************* Manage Services diagnostics data collected on ${ms_diagnostic_collection_date} *******************************"
echo ""

tempFolder="/tmp"
ms_diagnostic_data_folder_name="manage_services_diagnostic_data_${ms_diagnostic_collection_date}"
ms_diagnostic_data_folder="${tempFolder}/${ms_diagnostic_data_folder_name}"
ms_diagnostic_data_log="${ms_diagnostic_data_folder}/manage-services-diagnostics-data.log"
ms_diagnostic_data_zipped_file="${ms_diagnostic_data_folder}.tgz"
echo "Creating temporary folder ${ms_diagnostic_data_folder}"
if `mkdir ${ms_diagnostic_data_folder}`; then
    echo "Successfully created temporary folder ${ms_diagnostic_data_folder}"
else
    echo "Failed creating temporary folder ${ms_diagnostic_data_folder}"
    exit 1
fi

echo "Collecting Manage Services Diagnostics data. Please wait...."
collectDiagnosticsData $@ > ${ms_diagnostic_data_log}
if [ $? -eq 0 ]; then
    echo "Successfully collected Manage Services diagnostics data"
else
    echo "Error occurred while trying to collect Manage Services diagnostics data. Check ${ms_diagnostic_data_log} for details"
    exit 1
fi

echo "Zipping up Diagnostics data from ${ms_diagnostic_data_folder}"
tar cfz ${ms_diagnostic_data_zipped_file} --directory ${tempFolder} ${ms_diagnostic_data_folder_name}
if [ $? -eq 0 ]; then
    echo "Cleaning up temporary folder ${ms_diagnostic_data_folder}"
    rm -rf ${ms_diagnostic_data_folder}
    echo "******************************* Successfully collected and zipped up Manage Services diagnostics data. The diagnostics data is available at ${ms_diagnostic_data_zipped_file} *******************************"
else
    echo "******************************* Failed to zip up diagnostics data. Diagnostics data folder is available at ${ms_diagnostic_data_folder} *******************************" 
fi
