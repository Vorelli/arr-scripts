#!/usr/bin/with-contenv bash

# NOTE: this runs from /custom-cont-init.d -- under s6-overlay v3 a non-zero exit
# here aborts the whole container start. Never let a failed setup take the
# container down; log and carry on so the app + a shell stay reachable.
curl -sfL https://raw.githubusercontent.com/Vorelli/arr-scripts/main/lidarr/setup.bash | bash \
  || echo "scripts_init :: WARNING :: setup.bash failed -- continuing so the container stays up (clients may be degraded)"
exit 0
