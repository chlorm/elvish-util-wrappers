# Copyright (c) 2020, Cody Opel <cwopel@chlorm.net>
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


use github.com/chlorm/elvish-stl/path
use github.com/chlorm/elvish-stl/wrap
use github.com/chlorm/elvish-xdg/xdg


var SOCKET_DIR = (xdg:get-dir XDG_RUNTIME_DIR)'/keyring'
var SOCKET_CONTROL = $SOCKET_DIR'/control'
var SOCKET_PKCS11 = $SOCKET_DIR'/pkcs11'
var SOCKET_SSH = $SOCKET_DIR'/ssh'

fn set-permissions [agent]{
    os:chmod 0700 $SOCKET_DIR
    var sockets = [
        $SOCKET_CONTROL
        $SOCKET_PKCS11
        $SOCKET_SSH
    ]
    for i $sockets {
        os:chmod 0600 $i
    }
}

# Manually envoke gnome-keyring-daemon
fn start {
    var cmd = [(
        wrap:cmd-out 'gnome-keyring-daemon' ^
        '--components' 'ssh,secrets,pkcs11' ^
        '--control-directory' $SOCKET_DIR ^
        '--daemonize'
    )]

    set-permissions
}
