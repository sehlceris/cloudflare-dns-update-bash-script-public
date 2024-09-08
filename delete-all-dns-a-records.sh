# Exit immediately if any command exits with a non-zero status
set -e

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
echo "script dir: $SCRIPT_DIR"

# Check if the config file exists, exit if not
CONFIG_FILE="$SCRIPT_DIR/config.sh"
if [ ! -f "$CONFIG_FILE" ]; then
    echo -e "\nError: Configuration file 'config.sh' not found! Create it by using 'cp config.example.sh config.sh' and editing it to your needs"
    exit 1
fi

# Load the config file (variables)
source $CONFIG_FILE

# Function to delete a DNS record
delete_record() {
    local record_id=$1
    curl -X DELETE "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records/$record_id" \
         -H "Authorization: Bearer $API_TOKEN" \
         -H "Content-Type: application/json"
}

# Get all DNS records
records=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records?type=A" \
     -H "Authorization: Bearer $API_TOKEN" \
     -H "Content-Type: application/json")

# Extract record IDs and delete each A record
echo "$records" | jq -r '.result[] | select(.type=="A") | .id' | while read -r record_id; do
    echo "Deleting A record with ID: $record_id"
    delete_record "$record_id"
done

echo "All A records have been deleted."