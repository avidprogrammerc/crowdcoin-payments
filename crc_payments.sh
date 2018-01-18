#!/bin/bash

# This script is intended to be used to automatically send payments to crowdcoin masternode share holders.
# Edit the script variables to suit your needs.

echo -e "##############################################"
echo -e "#                                            #"
echo -e "#        Automatic Crowdcoin Payments        #"
echo -e "#                                            #"
echo -e "##############################################\n"

# Check for dependencies.
HAS_DEPENDENCIES=true

echo "Checking for dependencies..."
if ! which jq > /dev/null; then
    echo -e "jq is not installed...\n"
    HAS_DEPENDENCIES=false
else
    echo -e "✔\n"
fi



# This is the public key of the masternode
MASTERNODE_PUB_KEY="CPgpU3Gc92qVcjTRFLbseEkrwXDdu8XDmg"

# The following are the public addresses of the seat holders (adjust these as needed)
SEAT1="CLckwpm4wSqePxBVXyKbY8xVaHQmC1sQLn" # hokie_programmer - 50%
SEAT2="" # Ryan - pool.CryptoPros.us - 30%
SEAT3="" #  - 10%
SEAT4="" #  - 10%

# Service Fee
FEE="0.02"

if $HAS_DEPENDENCIES ; then
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

    echo -e "Total Due: $TOTAL_DUE\n"

    printf "Service fee (for Ryan - pool.CryptoPros.us): "
    SERVICE_FEE=$(echo "scale=100000; $TOTAL_DUE*$FEE" | bc -l)
    echo $SERVICE_FEE

    REMAINING_TOTAL=$(echo "scale=100000; $TOTAL_DUE-$SERVICE_FEE" | bc -l)
    echo -e "Remaining balance after fee: $REMAINING_TOTAL\n"

    SEAT1_DUE=$(echo "scale=100000; $REMAINING_TOTAL*.5" | bc -l)
    SEAT2_DUE=$(echo "scale=100000; $REMAINING_TOTAL*.3+$SERVICE_FEE" | bc -l)
    SEAT3_DUE=$(echo "scale=100000; $REMAINING_TOTAL*.1" | bc -l)
    SEAT4_DUE=$(echo "scale=100000; $REMAINING_TOTAL*.1" | bc -l)

    echo "hokie_programmer: $SEAT1_DUE"
    echo "Ryan - pool.CryptoPros.us: $SEAT2_DUE"
    echo "?: $SEAT3_DUE"
    echo "?: $SEAT4_DUE"

    echo -e "Cleaning up..."
    rm latest_payments.txt
fi
