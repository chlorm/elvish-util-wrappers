# Copyright (c) 2019-2020, Cody Opel <cwopel@chlorm.net>
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


use github.com/chlorm/elvish-util-wrappers/regex


fn -len [array]{
  local:len = 0
  for local:i [(keys $array)] {
    len = (+ $len 1)
  }
  put $len
}

fn -parse-xy [line]{
  local:xyr = [
    &staged=$line[0:1]
    &unstaged=$line[1:2]
  ]

  local:xy = [
    &staged=[&]
    &unstaged=[&]
  ]

  # NOTE: X is purposely ommitted to throw an error.
  for local:i [ staged unstaged ] {
    if (==s $xyr[$i] '.') {
      xy[$i][unmodifed]=$true
    } elif (==s $xyr[$i] 'A') {
      xy[$i][added]=$true
    } elif (==s $xyr[$i] 'C') {
      xy[$i][copied]=$true
    } elif (==s $xyr[$i] 'D') {
      xy[$i][deleted]=$true
    } elif (==s $xyr[$i] 'M') {
      xy[$i][modified]=$true
    } elif (==s $xyr[$i] 'R') {
      xy[$i][renamed]=$true
    } elif (==s $xyr[$i] 'T') {
      xy[$i][typechange]=$true
    } elif (==s $xyr[$i] 'U') {
      xy[$i][unmerged]=$true
    } else {
      put $i' '$xyr[$i] >&2
      fail 'not a valid XY char'
    }
  }

  put $xy
}

fn -parse-sub [line]{
  local:s = [
    &commit=$line[1:2]
    &tracked=$line[2:3]
    &untracked=$line[3:4]
  ]

  local:submodule = [&]

  if (==s 'S' $line[0:1]) {
    for local:i [(keys $s)] {
      if (has-value ['C' 'M' 'U'] $s[$i]) {
        submodule[$i]=$true
      } else {
        if (!=s '.' $s[$i]) {
          put $s[$i] >&2
          fail 'invalid submodule char'
        }
      }
    }
  }

  put $submodule
}

fn -map-modified [s]{
  put [
    &type=$s[0]
    &xy=$s[1]
    &sub=$s[2]
    &mode=[
      &head=$s[3]
      &index=$s[4]
      &worktree=$s[5]
    ]
    &obj=[
      &head=$s[6]
      &index=$s[7]
    ]
    &path=(joins " " $s[8:])
  ]
}

fn -parse-modified [status input]{
  local:path = $input[path]
  local:xy = (-parse-xy $input[xy])
  local:sub = (-parse-sub $input[sub])

  status[paths][$path][staged]=$xy[staged]
  status[paths][$path][unstaged]=$xy[unstaged]
  if (> (-len $sub) 0) {
    status[paths][$path][submodule]=$sub
  }
  status[paths][$path][mode]=$input[mode]
  status[paths][$path][object]=$input[obj]

  put $status
}

fn -map-renamed-copied [s]{
  local:p = [(re:splits '\t' (joins " " $s[9:]))]
  put [
    &type=$s[0]
    &xy=$s[1]
    &sub=$s[2]
    &mode=[
      &head=$s[3]
      &index=$s[4]
      &worktree=$s[5]
    ]
    &obj=[
      &head=$s[6]
      &index=$s[7]
    ]
    &score=$s[8]
    &path=$p[0]
    &origpath=$p[1]
  ]
}

fn -parse-rename-copied [status input]{
  local:path = $input[path]
  local:xy = (-parse-xy $input[xy])
  local:sub = (-parse-sub $input[sub])

  status[paths][$path][staged]=$xy[staged]
  status[paths][$path][unstaged]=$xy[unstaged]
  if (> (-len $sub) 0) {
    status[paths][$path][submodule]=$sub
  }
  status[paths][$path][mode]=$input[mode]
  status[paths][$path][object]=$input[obj]
  status[paths][$path][score]=$input[score]
  status[paths][$path][origpath]=$input[origpath]

  put $status
}

fn -map-unmerged [s]{
  put [
    &type=$s[0]
    &xy=$s[1]
    &sub=$s[2]
    &mode=[
      &stage1=$s[3]
      &stage2=$s[4]
      &stage3=$s[5]
      &worktree=$s[6]
    ]
    &obj=[
      &stage1=$s[7]
      &stage2=$s[8]
      &stage3=$s[9]
    ]
    &path=(joins " " $s[10:])
  ]
}

fn -parse-unmerged [status input]{
  local:path = $input[path]
  local:xy = (-parse-xy $input[xy])
  local:sub = (-parse-sub $input[sub])

  status[paths][$path][staged]=$xy[staged]
  status[paths][$path][unstaged]=$xy[unstaged]
  if (> (-len $sub) 0) {
    status[paths][$path][submodule]=$sub
  }
  status[paths][$path][mode]=$input[mode]
  status[paths][$path][object]=$input[obj]

  put $status
}

# Initializes a path object if it doesn't exist
fn -initialize-path [status path]{
  try {
    local:test = $status[paths][$path]
  } except _ {
    status[paths][$path]=[&]
  }

  put $status
}

# Returns the result of `git status` as a structured object.
# XXX: object structure and naming is not finalized and subject to change
fn status {
  local:git-status-output = []
  try {
    git-status-output = [(git 'status' '--porcelain=2' '--branch' '--ignored')]
  } except e {
    fail $e
  }

  local:git-status = [
    &branch=[&]
    &paths=[&]
  ]

  for local:i $git-status-output {
    local:line = [(splits " " $i)]
    if (==s '#' $line[0]) {
      local:header = (regex:find 'branch.([a-z]+)' $line[1])
      if (==s 'ab' $header) {
        git-status[branch][ahead]=(regex:find '\+(\d+)' $line[2])
        git-status[branch][behind]=(regex:find '-(\d+)' $line[3])
      } else {
        git-status[branch][$header]=$line[2]
      }
    } elif (==s '1' $line[0]) {
      local:input = (-map-modified $line)
      git-status = (-initialize-path $git-status $input[path])
      git-status = (-parse-modified $git-status $input)
    } elif (==s '2' $line[0]) {
      local:input = (-map-modified $line)
      git-status = (-initialize-path $git-status $input[path])
      git-status = (-parse-renamed-copied $git-status $input)
    } elif (==s 'u' $line[0]) {
      local:input = (-map-modified $line)
      git-status = (-initialize-path $git-status $input[path])
      git-status = (-parse-unmerged $git-status $input)
    } elif (==s '?' $line[0]) {
      local:path = (joins " " $line[1:])
      git-status = (-initialize-path $git-status $path)
      git-status[paths][$path][untracked]=$true
    } elif (==s '!' $line[0]) {
      local:path = (joins " " $line[1:])
      git-status = (-initialize-path $git-status $path)
      git-status[paths][$path][ignored]=$true
    } else {
      put $line[0] >&2
      fail 'invalid type'
    }
  }

  put $git-status
}

