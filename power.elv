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


use str
use github.com/chlorm/elvish-stl/io
use github.com/chlorm/elvish-stl/path
use github.com/chlorm/elvish-stl/regex
use github.com/chlorm/elvish-stl/wrap


fn -initialize-state [obj class num]{
    try {
        var _ = $obj[$class][$num]
    } except _ {
        set obj[$class][$num] = [&]
    }
    put $obj
}

fn -parse-acpi {
    var acpiOutput = [ ]
    try {
        set acpiOutput = [ (wrap:cmd-out 'acpi' '-a' '-b') ]
    } except _ {
        fail
    }

    fn -num [n]{
        put (regex:find '(\d+):' $n)
    }

    var state = [
        &adapters=[&]
        &batteries=[&]
    ]
    for i $acpiOutput {
        var expld = [ (str:split " " $i) ]
        if (==s $expld[0] 'Adapter') {
            var num = (-num $expld[1])
            set state = (-initialize-state $state 'adapters' $num)
            set state[adapters][$num]['status'] = $expld[2]
        } elif (==s $expld[0] 'Battery') {
            var num = (-num $expld[1])
            set state = (-initialize-state $state 'batteries' $num)
            set state[batteries][$num]['status'] = (regex:find '(.*),' $expld[2])
            set state[batteries][$num]['charge'] = (regex:find '(\d+)%' $expld[3])
        } else {
            put $expld[0] >&2
            fail 'invalid type'
        }
    }

    put $state
}

fn -sys-uid [dev]{
    put [ (io:cat $dev'/device/uid') ][0]
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
        if (==s (path:basename $dev)[0..2] 'AC') {
            var num = (-sys-uid $dev)
            set state = (-initialize-state $state 'adapters' $num)
            var status = 'off-line'
            if (== [ (io:cat $dev'/online') ][0] 1) {
                set status = 'on-line'
            }
            set state['adapters'][$num]['status'] = $status
        } elif (==s (path:basename $dev)[0..3] 'BAT') {
            var num = (-sys-uid $dev)
            set state = (-initialize-state $state 'batteries' $num)
            set state['batteries'][$num]['status'] = (io:cat $dev'/status')
            set state['batteries'][$num]['charge'] = (io:cat $dev'/capacity')
        } else {
            put $dev >&2
            fail 'invalid type'
        }
    }

    put $state
}

fn get-adapters {
    try {
        put (-parse-sysfs)['adapters']
    } except _ {
        put (-parse-acpi)['adapters']
    }
}

fn get-batteries {
    try {
        put (-parse-sysfs)['batteries']
    } except _ {
        put (-parse-acpi)['batteries']
    }
}
