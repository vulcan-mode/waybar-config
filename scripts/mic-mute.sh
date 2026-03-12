#!/bin/bash

if pamixer --default-source --get-mute 2>/dev/null | grep -q "true"; then
  echo '{"text": "󰍭", "class": "muted", "tooltip": "Microphone muted"}'
else
  echo '{"text": "", "class": "unmuted", "tooltip": "Microphone active"}'
fi
