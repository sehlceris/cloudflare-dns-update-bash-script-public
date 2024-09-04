#!/bin/bash

# Exit immediately if any command exits with a non-zero status
set -e


# Function to detect the current public IP address
get_public_ip() {

    # IP address validation regex (IPv4)
    ipv4_regex='([01]?[0-9]?[0-9]|2[0-4][0-9]|25[0-5])\.([01]?[0-9]?[0-9]|2[0-4][0-9]|25[0-5])\.([01]?[0-9]?[0-9]|2[0-4][0-9]|25[0-5])\.([01]?[0-9]?[0-9]|2[0-4][0-9]|25[0-5])'

    # Attempt to get the IP from Cloudflare
    ip=$(curl -s -4 https://cloudflare.com/cdn-cgi/trace | grep -E '^ip'); ret=$?
    
    if [[ ! $ret == 0 ]]; then
        # If Cloudflare fails, try from other services
        ip=$(curl -s https://api.ipify.org || curl -s https://ipv4.icanhazip.com)
    else
        # Extract the IP from the Cloudflare response
        ip=$(echo $ip | sed -E "s/^ip=($ipv4_regex)$/\1/")
    fi

    # Validate the IP address format
    if [[ ! $ip =~ ^$ipv4_regex$ ]]; then
        logger -s "DDNS Updater: Failed to find a valid IP."
        exit 2
    fi

    echo "$ip"
}

update_dns_record() {
    RECORD_NAME=$1

    # Get the DNS record ID
    RECORD_ID=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/${ZONE_ID}/dns_records?type=A&name=${RECORD_NAME}" \
        -H "Authorization: Bearer ${API_TOKEN}" \
        -H "Content-Type: application/json" | grep -o '"id":"[^"]*"' | head -n 1 | sed -E 's/"id":"([^"]*)"/\1/')

    echo "Record Name: '$RECORD_NAME' Record ID: '$RECORD_ID'"

    # Check if RECORD_ID is either empty or equal to "null"
    if [ -z "${RECORD_ID}" ] || [ "${RECORD_ID}" = "null" ]; then
        # If no record exists, create a new DNS record
        echo "DNS record for ${RECORD_NAME} not found. Creating a new record."

        CREATE_RESPONSE=$(curl -s -X POST "https://api.cloudflare.com/client/v4/zones/${ZONE_ID}/dns_records" \
            -H "Authorization: Bearer ${API_TOKEN}" \
            -H "Content-Type: application/json" \
            --data "{\"type\":\"A\",\"name\":\"${RECORD_NAME}\",\"content\":\"${CURRENT_IP}\",\"ttl\":120,\"proxied\":false}")

        if echo "${CREATE_RESPONSE}" | grep -q '"success":true'; then
            echo "Successfully created ${RECORD_NAME} with IP ${CURRENT_IP}"
        else
            echo "Failed to create DNS record for ${RECORD_NAME}"
            echo "Response: ${CREATE_RESPONSE}"
            exit 1
        fi
    else
        # If record exists, update the DNS record with the new IP
        echo "Updating existing DNS record for ${RECORD_NAME}."

        UPDATE_RESPONSE=$(curl -s -X PUT "https://api.cloudflare.com/client/v4/zones/${ZONE_ID}/dns_records/${RECORD_ID}" \
            -H "Authorization: Bearer ${API_TOKEN}" \
            -H "Content-Type: application/json" \
            --data "{\"type\":\"A\",\"name\":\"${RECORD_NAME}\",\"content\":\"${CURRENT_IP}\",\"ttl\":120,\"proxied\":false}")

        if echo "${UPDATE_RESPONSE}" | grep -q '"success":true'; then
            echo "Successfully updated ${RECORD_NAME} to ${CURRENT_IP}"
        else
            echo "Failed to update ${RECORD_NAME}"
            echo "Response: ${UPDATE_RESPONSE}"
            exit 1
        fi
    fi
}

# Get the current public IP address
CURRENT_IP=$(get_public_ip)
echo "IP address detected as $CURRENT_IP"

# Check if the config file exists, exit if not
CONFIG_FILE="./config.sh"
if [ ! -f "$CONFIG_FILE" ]; then
    echo "Error: Configuration file 'config.sh' not found! Create it by using 'cp config.example.sh config.sh' and editing it to your needs"
    exit 1
fi

# Load the config file (variables)
source ./config.sh

# Update the main domain if desired
if [ "$UPDATE_ROOT_DOMAIN" = true ]; then
    echo "Updating root domain ${ROOT_DOMAIN}"
    update_dns_record "${ROOT_DOMAIN}"
fi

# Update all subdomains in the array
for SUBDOMAIN in "${SUBDOMAINS[@]}"; do
    RECORD_NAME="${SUBDOMAIN}.${ROOT_DOMAIN}"
    echo "Updating subdomain ${RECORD_NAME}"
    update_dns_record "${RECORD_NAME}"
done
