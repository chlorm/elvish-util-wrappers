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


use str
use github.com/chlorm/elvish-stl/path
use github.com/chlorm/elvish-xdg/xdg


var SOCKET = (xdg:get-dir 'XDG_RUNTIME_DIR')'/openssh/ssh-agent.socket'

fn set-permissions [agent]{
    os:chmod 0700 (path:dirname $SOCKET)
    os:chmod 0600 $SOCKET
}

# Manually envoke ssh-agent
fn start {
    var cmd = [ (e:ssh-agent '-c' '-a' $SOCKET) ]

    set-permissions

    var pid = (str:join " " [ (str:split " " $cmd[1]) ][3..])[..-1]
    put $pid
}