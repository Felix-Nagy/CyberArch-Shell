#!/usr/bin/env bash
# hypridle before_sleep_cmd. Starts the lock screen and waits (max ~4s) until the
# compositor has confirmed the session lock (lock_shell.qml sets logind's LockedHint
# once WlSessionLock is secure), so the desktop is never visible after resume.
# Bounded, so hypridle releases logind's sleep delay inhibitor quickly.
locked() { [ "$(loginctl show-session auto -p LockedHint --value 2>/dev/null)" = yes ]; }
locked && exit 0
loginctl lock-session
for _ in $(seq 40); do
    locked && { sleep 0.3; exit 0; }   # small margin for the first frame
    sleep 0.1
done
exit 0
