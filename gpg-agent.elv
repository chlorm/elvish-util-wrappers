# Copyright (c) 2016, 2020, Cody Opel <cwopel@chlorm.net>
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


use github.com/chlorm/elvish-stl/os
use github.com/chlorm/elvish-stl/path
use github.com/chlorm/elvish-stl/utils
use github.com/chlorm/elvish-xdg/xdg


var SOCKET_DIR = (xdg:get-dir 'XDG_RUNTIME_DIR')'/gnupg'
var sockBase = '/S.gpg-agent'
var SOCKET = $SOCKET_DIR$sockBase
var SOCKET_BROWSER = $SOCKET_DIR$sockBase'.browser'
var SOCKET_EXTRA = $SOCKET_DIR$sockBase'.extra'
var SOCKET_SSH = $SOCKET_DIR$sockBase'.ssh'
var SOCKET_SCDAEMON = $SOCKET_DIR'S.scdaemon'

fn get-pinentry-cmd {
    var pinentryCmds = [
        'pinentry'
        'pinentry-tty'
        'pinentry-qt'
        'pinentry-gnome3'
        'pinentry-gtk2'
        'pinentry-kwallet'
    ]

    put (utils:get-preferred-cmd 'PREFERRED_PINENTRY_CMDS' $pinentryCmds)
}

fn set-permissions [agent]{
    var home = (path:home)
    os:chmod 0700 $home
    os:chmod 0700 $home'/.gnupg'

    os:chmod 0700 $SOCKET_DIR
    var sockets = [
        $SOCKET
        $SOCKET_BROWSER
        $SOCKET_EXTRA
        $SOCKET_SSH
    ]
    for i $sockets {
        os:chmod 0600 $i
    }
}

# FIXME:
fn configure-gnupg {

}

# FIXME:
fn configure-scdaemon {
    #echo "pcsc-driver $(UserAgent::PcscDriver)" >> \
    #  "$HOME/.gnupg/scdaemon.conf"
    #echo 'card-timeout 5' > $confdir'/scdaemon.conf'
    #echo 'disable-ccid' >> $confdir'/scdaemon.conf'
}

# TODO: try enabling and starting systemd user units

# Manually envoke gpg-agent, using gpg-agent-connect doesn't allow setting
# sockets explicty.
fn start {
    # Hardcode socket locations to explicitly fail on configuration errors.
    E:GPG_AGENT_SSH_SOCK_NAME=$SOCKET_SSH ^
    E:GPG_AGENT_EXTRA_SOCK_NAME=$SOCKET_EXTRA ^
    E:GPG_AGENT_BROWSER_SOCK_NAME=$SOCKET_BROWSER ^
    E:GPG_AGENT_SOCK_NAME=$SOCKET ^
    E:SCDAEMON_SOCK_NAME=$SOCKET_SCDAEMON ^
    e:gpg-agent ^
        '--daemon' ^
        '--pinentry-program' (get-pinentry-cmd) ^
        '--sh'

    set-permissions
}