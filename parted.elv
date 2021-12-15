# Copyright (c) 2021, Cody Opel <cwopel@chlorm.net>
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


use github.com/chlorm/elvish-util-wrappers/su


# Creates a new partition table with the specified partitions.
# parts = [
#     &1=[
#         type=logical|primary
#         fs=btrfs (optional)
#         name='partition label'
#         start=''
#         end=''
#         flags=[
#             boot
#             root
#         ]
#     ]
# ]
fn new {|device parts|
    var cmds = [ 'mklabel' 'gpt' ]
    var valid-fs = [
        'btrfs'
        'ext2'
        'fat32'
        'linux-swap'
    ]
    var valid-flags = [
        'bios_grub'
        'boot'
        'irst'
        'root'
        'swap'

    ]
    var valid-types = [
        'extended'
        'logical'
        'primary'
    ]
    for i [ (keys $parts) ] {
        has-value $valid-types $parts[$i]['type']
        var fs = ''
        if (has-key $parts[$i] 'fs') {
            has-value $valid-fs $parts[$i]['fs']
            set fs = $parts[$i]['fs']
        }
        set cmds = [
            $@cmds
            'mkpart' $parts[$i]['type'] $fs $parts[$i]['start'] $parts[$i]['end']
            'name' $i $parts[$i]['name']
        ]
        if (has-key $parts[$i] 'flags') {
            for o $parts[$i]['flags'] {
                has-value $valid-flags $o
                set cmds = [
                    $@cmds
                    'set' $i $o 'on'
                ]
            }
        }
    }
    su:do 'parted' $device $cmds
}
