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


use github.com/chlorm/elvish-stl/io
use github.com/chlorm/elvish-stl/path
use github.com/chlorm/elvish-stl/platform
use github.com/chlorm/elvish-stl/str


fn -initialize-state {|obj class num|
    try {
        var _ = $obj[$class][$num]
    } catch _ {
        set obj[$class][$num] = [&]
    }
    put $obj
}

fn -sys-uid {|dev|
    str:to-nonempty-lines (io:open $dev'/device/uid')
}

fn -parse-sysfs {
    var sysfs = $E:ROOT'/sys/class/power_supply'
    if (not (os:exists $sysfs)) {
        fail 'cannot access sysfs'
    }
    var state = [
        &adapters=[&]
        &batteries=[&]
    ]
    for dev (path:scandir $sysfs)['files'] {
        var b = (path:basename $dev)
        if (==s $b[0..2] 'AC') {
            var num = (-sys-uid $dev)
            set state = (-initialize-state $state 'adapters' $num)
            var status = 'off-line'
            if (== (str:to-nonempty-lines (io: $dev'/online')) 1) {
                set status = 'on-line'
            }
            set state['adapters'][$num]['status'] = $status
            continue
        }
        if (==s $b[0..3] 'BAT') {
            var num = (-sys-uid $dev)
            set state = (-initialize-state $state 'batteries' $num)
            set state['batteries'][$num]['status'] = (str:to-nonempty-lines (io:open $dev'/status'))
            set state['batteries'][$num]['charge'] = (str:to-nonempty-lines (io:open $dev'/capacity'))
            continue
        }
        var err = 'invalid type: '$dev
        fail $err
    }

    put $state
}

fn get-adapters {
    if $platform:is-windows { fail }
    put (-parse-sysfs)['adapters']
}

fn get-batteries {
    if $platform:is-windows { fail }
    put (-parse-sysfs)['batteries']
}
