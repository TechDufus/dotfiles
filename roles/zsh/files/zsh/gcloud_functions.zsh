#!/usr/bin/env zsh

# Fetch and merge kubeconfigs for all GKE clusters across all your projects
function gke-GetAllCreds() {
  local project cluster_name cluster_location location_type location_flag

  while IFS= read -r project; do
    [[ -n "$project" ]] || continue
    echo -e "${GREEN}Processing project: ${BOLD}${project}${RESTORE}"
    while IFS=$'\t' read -r cluster_name cluster_location location_type; do
      [[ -n "$cluster_name" ]] || continue

      location_flag="--region"
      if [[ $location_type == "ZONAL" ]]; then
        location_flag="--zone"
      fi

      echo -e "${GREEN}Fetching credentials for cluster: ${BOLD}${cluster_name}${RESTORE} in project: ${BOLD}${project}${RESTORE} at location: ${BOLD}${cluster_location}${RESTORE}"
      gcloud container clusters get-credentials \
        "$cluster_name" $location_flag "$cluster_location" \
        --project="$project"
    done < <(gcloud container clusters list --project="$project" --format='value(name,location,locationType)' --quiet)
  done < <(gcloud projects list --format='value(projectId)' --quiet)
}
