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


use re


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
  if (not (has-value [ 'on' 'off' ] $state)) {
    fail 'Invalid argument'
  }
  nmcli r wifi $state
}

# Returns the first wireless device found.
fn get-wifi-interface {
  local:interface = ''
  for local:i [ (nmcli d) ] {
    local:s = [ (re:split '\s+' $i) ]
    if (==s 'wifi' $s[1]) {
      interface = $s[0]
      break
    }
  } else {
    fail 'no wifi interface'
  }
  put $interface
}

# Add a new connection.
fn add-wifi-connection [ssid pass]{
  try {
    nmcli \
      d wifi \
      connect $ssid $pass \
      ifname (get-wifi-interface) \
      name $ssid
  } except e {
    put $e >&2
    fail 'failed to add connection'
  }
}

# Connect to a saved connection.
fn connect-wifi [ssid]{
  try {
    nmcli c up id $ssid
  } except e {
    put $e >&2
    fail 'failed to connect'
  }
}
