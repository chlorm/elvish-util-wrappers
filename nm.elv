# Copyright (c) 2019, Cody Opel <cwopel@chlorm.net>
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
use github.com/chlorm/elvish-stl/exec


# Find connectable wifi ssids.
fn get-wifi-list {
    e:nmcli 'device' 'wifi' 'list'
}

# List saved connection.
fn get-wifi-connections {
    e:nmcli 'connection'
}

# List active connections.
fn get-wifi-status {
    e:nmcli 'general' 'status'
}

# Turn wireless devices on/off.
fn set-wifi-state {|state|
    if (not (has-value [ 'on' 'off' ] $state)) {
        fail 'Invalid argument'
    }
    e:nmcli 'radio' 'wifi' $state
}

# Returns the first wireless device found.
fn get-wifi-interface {
    var interface = ''
    for i [ (exec:cmd-out 'nmcli' 'device') ] {
        var s = [ (re:split '\s+' $i) ]
        if (==s $s[1] 'wifi') {
            set interface = $s[0]
            break
        }
    } else {
        fail 'no wifi interface'
    }
    put $interface
}

# Add a new connection.
fn add-wifi-connection {|ssid pass|
    e:nmcli ^
        'device' 'wifi' ^
        'connect' $ssid $pass ^
        'ifname' (get-wifi-interface) ^
        'name' $ssid
}

# Connect to a saved connection.
fn set-wifi-connection {|ssid|
    e:nmcli 'connection' 'up' 'id' $ssid
}

