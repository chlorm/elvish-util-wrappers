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


fn -initialize-state [obj class num]{
  try {
    local:test = $obj[$class][$num]
  } except _ {
    obj[$class][$num]=[&]
  }
  put $obj
}

fn -parse-acpi {
  local:acpi-output = [ ]
  try {
    acpi-output = [ (e:acpi -a -b) ]
  } except _ {
    fail
  }

  fn -num [n]{
    put (regex:find '(\d+):' $n)
  }

  local:state = [
    &adapters=[&]
    &batteries=[&]
  ]
  for local:i $acpi-output {
    local:expld = [ (str:split " " $i) ]
    if (==s 'Adapter' $expld[0]) {
      local:num = (-num $expld[1])
      state = (-initialize-state $state adapters $num)
      state[adapters][$num][status]=$expld[2]
    } elif (==s 'Battery' $expld[0]) {
      local:num = (-num $expld[1])
      state = (-initialize-state $state batteries $num)
      state[batteries][$num][status]=(regex:find '(.*),' $expld[2])
      state[batteries][$num][charge]=(regex:find '(\d+)%' $expld[3])
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
  local:sysfs = $E:ROOT'/sys/class/power_supply'
  if (not (os:exists $sysfs)) {
    fail 'cannot access sysfs'
  }
  local:state = [
    &adapters=[&]
    &batteries=[&]
  ]
  for local:dev (path:scandir $sysfs)[files] {
    if (==s 'AC' (path:basename $dev)[0:2]) {
      local:num = (-sys-uid $dev)
      state = (-initialize-state $state adapters $num)
      local:status = off-line
      if (== 1 [ (io:cat $dev'/online') ][0]) {
        status = on-line
      }
      state[adapters][$num][status]=$status
    } elif (==s 'BAT' (path:basename $dev)[0:3]) {
      local:num = (-sys-uid $dev)
      state = (-initialize-state $state batteries $num)
      state[batteries][$num][status]=(io:cat $dev'/status')
      state[batteries][$num][charge]=(io:cat $dev'/capacity')
    } else {
      put $dev >&2
      fail 'invalid type'
    }
  }

  put $state
}

fn get-adapters {
  try {
    put (-parse-sysfs)[adapters]
  } except _ {
    put (-parse-acpi)[adapters]
  }
}

fn get-batteries {
  try {
    put (-parse-sysfs)[batteries]
  } except _ {
    put (-parse-acpi)[batteries]
  }
}

