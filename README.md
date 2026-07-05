1. Vorbereitungen
Abhängigkeiten installieren (falls nicht vorhanden):
  apt update && apt install -y jq curl certbot
2. API-Key hinterlegen
  mkdir -p /root/.secrets/ionos
  nano /root/.secrets/ionos/apikey
Dort deinen IONOS API-Key (Public + Secret Key, mit Leerzeichen oder wie auch immer du das Format bei IONOS erzeugt hast) reinschreiben, dann Rechte einschränken:
  chmod 600 /root/.secrets/ionos/apikey
3. Script kopieren und ausführbar machen
  mkdir -p /etc/letsencrypt/hooks
  cp certbot-ionos-auth.sh /etc/letsencrypt/hooks/
  chmod +x /etc/letsencrypt/hooks/certbot-ionos-auth.sh
4. Logfile-Verzeichnis sicherstellen
  Das Script schreibt nach /var/log/certbot-ionos-dns.log – das existiert normalerweise, aber prüf kurz, ob /var/log beschreibbar ist (sollte es als root sein).
5. Zertifikat anfordern
Da dein Script nur der Auth-Hook ist (setzt den TXT-Record), brauchst du keinen Cleanup-Hook, weil es alte Records selbst vor dem Neuanlegen aufräumt. Der Aufruf sieht dann so aus:
bashcertbot certonly \
  --manual \
  --preferred-challenges dns \
  --manual-auth-hook /etc/letsencrypt/hooks/certbot-ionos-auth.sh \
  -d deine-domain.de \
  -d "*.deine-domain.de"
Wildcard-Zertifikate brauchen zwingend die DNS-Challenge, daher macht das Setup hier Sinn.
6. Automatische Verlängerung testen
  certbot renew --dry-run
Certbot merkt sich den --manual-auth-hook in der jeweiligen renewal-Config unter /etc/letsencrypt/renewal/deine-domain.de.conf, sodass certbot renew (z. B. per Cronjob/systemd-Timer) automatisch wieder dein Script aufruft.
