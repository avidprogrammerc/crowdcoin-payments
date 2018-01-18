#!/bin/bash

# This script is intended to be used to automatically send payments to crowdcoin masternode share holders.
# Edit the script variables to suit your needs.

# Check for dependencies.
HAS_DEPENDENCIES=true

echo "Checking for dependencies..."
if ! which jq > /dev/null; then
    echo "jq is not installed..."
    HAS_DEPENDENCIES=false
fi



# This is the public key of the masternode
MASTERNODE_PUB_KEY="CPgpU3Gc92qVcjTRFLbseEkrwXDdu8XDmg"

# The following are the public addresses of the seat holders (adjust these as needed)

if $HAS_DEPENDENCIES ; then
    echo "#####################################################"
    echo "#                                                   #"
    echo "#        Paying Crowdcoin Masternode Holders        #"
    echo "#                                                   #"
    echo "#####################################################"
    echo ""
    echo "Getting rewards due..."
    # Set LAST_SENT_TX to the most recent outgoing transaction
    LAST_SENT_TX=$(curl -s http://crowdcoin.site:3001/ext/getaddress/${MASTERNODE_PUB_KEY} \
        | jq -r '[.["last_txs"][] | select(.type | contains("vin"))][-1].addresses')

    # Get a list of all incoming transactions since LAST_SENT_TX
    REWARDS=$(curl -s http://crowdcoin.site:3001/ext/getaddress/CPgpU3Gc92qVcjTRFLbseEkrwXDdu8XDmg \
        | jq -r '.["last_txs"][]."addresses"' \
        | awk -v tx="$LAST_SENT_TX" '$0 == tx {i=1;next};i')

    # Get the value of each reward and add it to the total payment due
    for x in $REWARDS; do
        curl -s http://crowdcoin.site:3001/api/getrawtransaction?txid=$x\&decrypt=1 \
            | jq --arg MASTERNODE_PUB_KEY "$MASTERNODE_PUB_KEY" '."vout"[] | select(."scriptPubKey".addresses | contains([$MASTERNODE_PUB_KEY])) | .value' >> latest_payments.txt
    done;

    TOTAL_DUE=$(cat latest_payments.txt | xargs | sed -e 's/\ /+/g' | bc)

    echo "Total Due: $TOTAL_DUE"

    echo "Cleaning up..."
    rm latest_payments.txt
fi
