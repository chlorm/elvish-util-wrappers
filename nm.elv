# Copyright (c) 2019, Cody Opel <codyopel@gmail.com>
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Find connectable wifi ssids.
fn get-wifi-list {
  put (nmcli d wifi list)
}

# List saved connection.
fn get-wifi-connections {
  put (nmcli c)
}

# List active connections.
fn get-wifi-status {
  put (nmcli g status)
}

# Turn wireless devices on/off.
fn set-wifi-state [state]{
  if (not (has-value ['on' 'off'] $state)) {
    fail 'Invalid argument'
  }
  nmcli r wifi $state
}

# Returns the first wireless device found.
# TODO: make sure select and save to XDG_CONFIG_DIR.
fn get-wifi-interface {
  put (nmcli d | awk '/wifi/ {print $1; exit}')
}

# Add a new connection.
fn add-wifi-connection [ssid pass]{
  try {
    nmcli \
      d wifi \
      connect $ssid $pass ifname (get-wifi-interface) \
      name $ssid
  } except e {
    fail $e
  }
}

# Connect to a saved connection.
fn connect-wifi [ssid]{
  try {
    nmcli c up id $ssid
  } except e {
    fail $e
  }
}
