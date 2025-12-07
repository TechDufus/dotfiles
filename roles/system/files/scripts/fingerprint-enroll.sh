#!/usr/bin/env bash
# Fingerprint enrollment helper script
# Registers fingerprints for system authentication (sudo, login, etc.)

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_header() {
    echo -e "${BLUE}╔════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║${NC}         ${GREEN}Fingerprint Enrollment Helper${NC}                   ${BLUE}║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════╝${NC}"
    echo
}

print_info() {
    echo -e "${BLUE}ℹ${NC}  $1"
}

print_success() {
    echo -e "${GREEN}✓${NC}  $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC}  $1"
}

print_error() {
    echo -e "${RED}✗${NC}  $1"
}

# Check if fprintd is installed
check_fprintd() {
    if ! command -v fprintd-enroll &>/dev/null; then
        print_error "fprintd is not installed."
        print_info "Run 'dotfiles -t system' to install fingerprint support."
        exit 1
    fi
}

# Check if fingerprint reader is detected
check_device() {
    print_info "Checking for fingerprint reader..."

    if ! fprintd-list "$USER" &>/dev/null; then
        # Try to start the service first
        if sudo systemctl is-active fprintd &>/dev/null || sudo systemctl start fprintd &>/dev/null; then
            sleep 1
            if ! fprintd-list "$USER" &>/dev/null; then
                print_error "No fingerprint reader detected or fprintd service is not running."
                print_info "Ensure your fingerprint reader is connected and supported."
                exit 1
            fi
        else
            print_error "Could not start fprintd service."
            exit 1
        fi
    fi

    print_success "Fingerprint reader detected!"
}

# List currently enrolled fingerprints
list_enrolled() {
    echo
    print_info "Currently enrolled fingerprints:"
    fprintd-list "$USER" 2>/dev/null || echo "  (none)"
    echo
}

# Enroll a finger
enroll_finger() {
    local finger="$1"
    echo
    print_info "Enrolling ${finger}..."
    print_info "Please swipe your ${finger} on the fingerprint reader multiple times."
    echo

    if fprintd-enroll -f "$finger"; then
        print_success "${finger} enrolled successfully!"
    else
        print_error "Failed to enroll ${finger}. Please try again."
        return 1
    fi
}

# Delete enrolled fingerprints
delete_fingerprints() {
    echo
    print_warning "This will delete ALL enrolled fingerprints for $USER."
    read -rp "Are you sure? (y/N): " confirm

    if [[ "${confirm,,}" == "y" ]]; then
        if fprintd-delete "$USER"; then
            print_success "All fingerprints deleted."
        else
            print_error "Failed to delete fingerprints."
        fi
    else
        print_info "Operation cancelled."
    fi
}

# Verify fingerprint
verify_fingerprint() {
    echo
    print_info "Place your finger on the reader to verify..."

    if fprintd-verify; then
        print_success "Fingerprint verified successfully!"
    else
        print_error "Fingerprint verification failed."
    fi
}

# Interactive menu
show_menu() {
    echo
    echo "What would you like to do?"
    echo
    echo "  1) Enroll right index finger (recommended)"
    echo "  2) Enroll left index finger"
    echo "  3) Enroll all common fingers"
    echo "  4) List enrolled fingerprints"
    echo "  5) Verify fingerprint"
    echo "  6) Delete all fingerprints"
    echo "  7) Exit"
    echo
    read -rp "Choice [1-7]: " choice

    case "$choice" in
        1) enroll_finger "right-index-finger" ;;
        2) enroll_finger "left-index-finger" ;;
        3)
            for finger in right-index-finger left-index-finger right-middle-finger left-middle-finger; do
                enroll_finger "$finger" || true
                echo
            done
            ;;
        4) list_enrolled ;;
        5) verify_fingerprint ;;
        6) delete_fingerprints ;;
        7)
            print_info "Goodbye!"
            exit 0
            ;;
        *)
            print_warning "Invalid choice. Please try again."
            ;;
    esac
}

# Main
main() {
    print_header
    check_fprintd
    check_device
    list_enrolled

    # If run with --enroll flag, just enroll right index and exit
    if [[ "${1:-}" == "--enroll" ]]; then
        enroll_finger "right-index-finger"
        exit 0
    fi

    # Interactive mode
    while true; do
        show_menu
    done
}

main "$@"
