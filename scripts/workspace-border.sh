#!/bin/bash
# Monitors Hyprland focus changes and writes dynamic CSS
# to control whether the active workspace button has a bottom border.
#
# Bottom border appears when the focused window is NOT the top-left
# tiled window on the current workspace, or when the workspace is
# empty, or when a floating window is focused.

CSS_FILE="$HOME/.config/waybar/dynamic.css"
SOCKET="$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock"
LAST_CSS=""
TRIGGER_FILE="/tmp/workspace-border-trigger"

write_css() {
  local css="$1"
  if [[ "$css" != "$LAST_CSS" ]]; then
    echo "$css" > "$CSS_FILE"
    LAST_CSS="$css"
  fi
}

compute_css() {
  local active_json active_addr active_ws
  active_json=$(hyprctl activewindow -j 2>/dev/null)
  active_addr=$(echo "$active_json" | jq -r '.address // empty')
  active_ws=$(echo "$active_json" | jq -r '.workspace.id // empty')

  if [[ -z "$active_addr" || -z "$active_ws" ]]; then
    # Focused workspace is empty — use box-shadow for visible bottom line (no miters)
    echo '#workspaces button.active {
  box-shadow: inset 0 -2px 0 0 @accent;
}
#workspaces button:not(.active):nth-child(1)  { box-shadow: inset 0 -2px 0 0 alpha(@color2, 0.15); }
#workspaces button:not(.active):nth-child(2)  { box-shadow: inset 0 -2px 0 0 alpha(@color2, 0.20); }
#workspaces button:not(.active):nth-child(3)  { box-shadow: inset 0 -2px 0 0 alpha(@color2, 0.25); }
#workspaces button:not(.active):nth-child(4)  { box-shadow: inset 0 -2px 0 0 alpha(@color2, 0.30); }
#workspaces button:not(.active):nth-child(5)  { box-shadow: inset 0 -2px 0 0 alpha(@color2, 0.35); }
#workspaces button:not(.active):nth-child(6)  { box-shadow: inset 0 -2px 0 0 alpha(@color2, 0.40); }
#workspaces button:not(.active):nth-child(7)  { box-shadow: inset 0 -2px 0 0 alpha(@color2, 0.45); }
#workspaces button:not(.active):nth-child(8)  { box-shadow: inset 0 -2px 0 0 alpha(@color2, 0.50); }
#workspaces button:not(.active):nth-child(9)  { box-shadow: inset 0 -2px 0 0 alpha(@color2, 0.55); }
#workspaces button:not(.active):nth-child(10) { box-shadow: inset 0 -2px 0 0 alpha(@color2, 0.60); }'
    return
  fi

  local is_floating
  is_floating=$(echo "$active_json" | jq -r '.floating // false')

  local show_borders=false

  if [[ "$is_floating" == "true" ]]; then
    show_borders=true
  else
    # Find the top-left tiled window on this workspace
    local topleft_addr
    topleft_addr=$(hyprctl clients -j 2>/dev/null | jq -r \
      --argjson ws "$active_ws" \
      '[.[] | select(.workspace.id == $ws and .floating == false)]
       | sort_by(.at[1], .at[0])
       | .[0].address // empty')

    if [[ "$active_addr" != "$topleft_addr" ]]; then
      show_borders=true
    fi
  fi

  if [[ "$show_borders" == "true" ]]; then
    echo '#workspaces button.active {
  box-shadow: inset 0 -2px 0 0 @accent;
}
#workspaces button:not(.active):nth-child(1)  { box-shadow: inset 0 -2px 0 0 alpha(@color2, 0.15); }
#workspaces button:not(.active):nth-child(2)  { box-shadow: inset 0 -2px 0 0 alpha(@color2, 0.20); }
#workspaces button:not(.active):nth-child(3)  { box-shadow: inset 0 -2px 0 0 alpha(@color2, 0.25); }
#workspaces button:not(.active):nth-child(4)  { box-shadow: inset 0 -2px 0 0 alpha(@color2, 0.30); }
#workspaces button:not(.active):nth-child(5)  { box-shadow: inset 0 -2px 0 0 alpha(@color2, 0.35); }
#workspaces button:not(.active):nth-child(6)  { box-shadow: inset 0 -2px 0 0 alpha(@color2, 0.40); }
#workspaces button:not(.active):nth-child(7)  { box-shadow: inset 0 -2px 0 0 alpha(@color2, 0.45); }
#workspaces button:not(.active):nth-child(8)  { box-shadow: inset 0 -2px 0 0 alpha(@color2, 0.50); }
#workspaces button:not(.active):nth-child(9)  { box-shadow: inset 0 -2px 0 0 alpha(@color2, 0.55); }
#workspaces button:not(.active):nth-child(10) { box-shadow: inset 0 -2px 0 0 alpha(@color2, 0.60); }'
  else
    # Top-left tiled window focused — hide bottom borders
    echo '#workspaces button.active:not(.empty) {
  border-bottom: 5px solid @background;
}'
  fi
}

update_css() {
  local css i
  for i in 1 2 3 4 5; do
    css=$(compute_css)
    write_css "$css"
    sleep 0.1
  done
}

# Clean up trigger file
rm -f "$TRIGGER_FILE"
mkfifo "$TRIGGER_FILE"

cleanup() {
  rm -f "$TRIGGER_FILE"
  kill 0 2>/dev/null
}
trap cleanup EXIT

# Initial update
write_css "$(compute_css)"

# Feed socket events AND trigger-file writes into one stream
{
  socat -u UNIX-CONNECT:"$SOCKET" STDOUT 2>/dev/null &
  cat "$TRIGGER_FILE" &
  wait
} | while IFS= read -r event; do
  update_css
done
