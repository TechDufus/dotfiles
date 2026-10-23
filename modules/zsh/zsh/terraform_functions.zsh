#!/usr/bin/env zsh
function tapm() {
  export TAPM_ST=$(date)
  export TAPM_SE=$(date +"%s")
  terraform apply --auto-approve
  export TAPM_ED=$(date)
  export TAPM_EE=$(date +"%s")
  export TAPM_TC=$(expr $TAPM_EE - $TAPM_SE)
  echo -e "${ARROW} ${GREEN}tapm: Terraform Apply Plan & Measure${NC}"
  echo -e "${RIGHT_ANGLE} ${YELLOW}START: ${CYAN}$TAPM_ST${NC}"
  echo -e "${RIGHT_ANGLE} ${YELLOW}END:   ${CYAN}$TAPM_ED${NC}"
}
