#!/usr/bin/env zsh

# Fetch and merge kubeconfigs for all GKE clusters across all your projects
function gke-GetAllCreds() {
  local project cluster_name cluster_location location_type location_flag

  for project in $(gcloud projects list --format='value(projectId)' --quiet); do
    echo -e "${GREEN}Processing project: ${BOLD}${project}${RESTORE}"
    clusters=$(gcloud container clusters list --project="$project" --format='value(name,location,locationType)' --quiet)
    for cluster in $clusters; do
      cluster_name=$(echo $cluster | awk '{print $1}')
      cluster_location=$(echo $cluster | awk '{print $2}')
      location_type=$(echo $cluster | awk '{print $3}')

      location_flag="--region"
      if [[ $location_type == "ZONAL" ]]; then
        location_flag="--zone"
      fi

      echo -e "${GREEN}Fetching credentials for cluster: ${BOLD}${cluster_name}${RESTORE} in project: ${BOLD}${project}${RESTORE} at location: ${BOLD}${cluster_location}${RESTORE}"
      gcloud container clusters get-credentials \
        "$cluster_name" $location_flag "$cluster_location" \
        --project="$project"
    done
  done
}
