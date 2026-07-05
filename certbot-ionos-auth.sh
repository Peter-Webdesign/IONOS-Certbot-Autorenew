#!/bin/sh

API_URL="https://api.hosting.ionos.com/dns/v1"
API_KEY="$(cat /root/.secrets/ionos/apikey)"
LOGFILE="/var/log/certbot-ionos-dns.log"

log() {
  echo "$1" | tee -a "$LOGFILE"
}

log "=============================================="
log "AUTH HOOK START $(date -Is)"
log "CERTBOT_DOMAIN=$CERTBOT_DOMAIN"
log "CERTBOT_VALIDATION=$CERTBOT_VALIDATION"

if [ -z "$CERTBOT_DOMAIN" ] || [ -z "$CERTBOT_VALIDATION" ]; then
  log "ERROR: Hook not called by certbot"
  exit 1
fi

# Zone ableiten
ZONE_NAME=$(expr match "$CERTBOT_DOMAIN" '.*\.\(.*\..*\)')
[ -z "$ZONE_NAME" ] && ZONE_NAME="$CERTBOT_DOMAIN"

log "ZONE_NAME=$ZONE_NAME"

# Zonen holen
ZONES_JSON=$(curl -s -H "X-API-Key: $API_KEY" "$API_URL/zones")
log "ZONES RESPONSE:"
log "$ZONES_JSON"

ZONE_ID=$(echo "$ZONES_JSON" | jq -r '.[] | select(.name=="'"$ZONE_NAME"'") | .id')

if [ -z "$ZONE_ID" ] || [ "$ZONE_ID" = "null" ]; then
  log "ERROR: Zone not found"
  exit 1
fi

RECORD_NAME="_acme-challenge.$CERTBOT_DOMAIN"
log "RECORD_NAME=$RECORD_NAME"

# 🔍 Bestehende TXT-Records korrekt holen
ZONE_DETAIL_JSON=$(curl -s \
  -H "X-API-Key: $API_KEY" \
  "$API_URL/zones/$ZONE_ID?recordName=$RECORD_NAME&recordType=TXT")

log "ZONE DETAIL RESPONSE:"
log "$ZONE_DETAIL_JSON"

# IDs + Änderungszeit extrahieren
RECORD_IDS=$(echo "$ZONE_DETAIL_JSON" | jq -r '.records[]? | "\(.id) \(.changeDate)"')

RECORD_COUNT=$(echo "$RECORD_IDS" | grep -c .)

log "Existing TXT record count: $RECORD_COUNT"

# 🔥 Wenn mehr als 1 vorhanden → auf 1 reduzieren
if [ "$RECORD_COUNT" -ge 2 ]; then
  log "More than 1 TXT record exists – pruning old ones"

  # Sortieren nach changeDate (älteste zuerst), alle bis auf die neueste löschen
  echo "$RECORD_IDS" \
    | sort -k2 \
    | head -n -1 \
    | while read RECORD_ID CHANGE_DATE; do
        log "Deleting old TXT record id=$RECORD_ID (changeDate=$CHANGE_DATE)"

        DELETE_RESPONSE=$(curl -s -X DELETE \
          -H "X-API-Key: $API_KEY" \
          "$API_URL/zones/$ZONE_ID/records/$RECORD_ID")

        log "DELETE RESPONSE:"
        log "$DELETE_RESPONSE"
      done
fi

# ➕ Neuen TXT-Record anlegen
CREATE_BODY=$(cat <<EOF
[
  {
    "name": "$RECORD_NAME",
    "type": "TXT",
    "content": "$CERTBOT_VALIDATION",
    "ttl": 60,
    "prio": 0,
    "disabled": false
  }
]
EOF
)

log "POST REQUEST BODY:"
log "$CREATE_BODY"

POST_RESPONSE=$(curl -s -X POST \
  -H "X-API-Key: $API_KEY" \
  -H "Content-Type: application/json" \
  "$API_URL/zones/$ZONE_ID/records" \
  --data "$CREATE_BODY")

log "POST RESPONSE:"
log "$POST_RESPONSE"

log "Waiting 120s for DNS propagation"
sleep 120

log "AUTH HOOK END $(date -Is)"
log ""

exit 0
