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


use str
use github.com/chlorm/elvish-stl/regex


fn -parse-xy [line]{
    xyr = [
        &staged=$line[0..1]
        &unstaged=$line[1..2]
    ]

    xy = [
        &staged=[&]
        &unstaged=[&]
    ]

    # NOTE: X is purposely omitted to throw an error.
    for i [ staged unstaged ] {
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
    s = [
        &commit=$line[1..2]
        &tracked=$line[2..3]
        &untracked=$line[3..4]
    ]

    submodule = [&]

    if (==s 'S' $line[0..1]) {
        for i [ (keys $s) ] {
            if (has-value [ 'C' 'M' 'U' ] $s[$i]) {
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
        &path=(str:join " " $s[8..])
    ]
}

fn -parse-modified [status input]{
    path = $input[path]

    xy = (-parse-xy $input[xy])
    status[paths][$path][staged] = $xy[staged]
    status[paths][$path][unstaged] = $xy[unstaged]
    sub = (-parse-sub $input[sub])
    if (> (count $sub) 0) {
        status[paths][$path][submodule] = $sub
    }
    status[paths][$path][mode] = $input[mode]
    status[paths][$path][object] = $input[obj]

    put $status
}

fn -map-renamed-copied [s]{
    p = [ (re:splits '\t' (str:join " " $s[9..])) ]
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
    path = $input[path]

    xy = (-parse-xy $input[xy])
    status[paths][$path][staged] = $xy[staged]
    status[paths][$path][unstaged] = $xy[unstaged]
    sub = (-parse-sub $input[sub])
    if (> (count $sub) 0) {
        status[paths][$path][submodule] = $sub
    }
    status[paths][$path][mode] = $input[mode]
    status[paths][$path][object] = $input[obj]
    status[paths][$path][score] = $input[score]
    status[paths][$path][origpath] = $input[origpath]

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
        &path=(str:join " " $s[10..])
    ]
}

fn -parse-unmerged [status input]{
    path = $input[path]

    xy = (-parse-xy $input[xy])
    status[paths][$path][staged] = $xy[staged]
    status[paths][$path][unstaged] = $xy[unstaged]
    sub = (-parse-sub $input[sub])
    if (> (count $sub) 0) {
        status[paths][$path][submodule] = $sub
    }
    status[paths][$path][mode] = $input[mode]
    status[paths][$path][object] = $input[obj]

    put $status
}

# Initializes a path object if it doesn't exist
fn -initialize-path [status path]{
    try {
        _ = $status[paths][$path]
    } except _ {
        status[paths][$path] = [&]
    }

    put $status
}

# Returns the result of `git status` as a structured object.
# XXX: object structure and naming is not finalized and subject to change
fn status {
    gitStatusOutput = [ ]
    try {
        gitStatusOutput = [
            (e:git 'status' '--porcelain=2' '--branch' '--ignored')
        ]
    } except e {
        fail $e
    }

    gitStatus = [
        &branch=[&]
        &paths=[&]
    ]

    for i $gitStatusOutput {
        line = [ (str:split " " $i) ]
        if (==s $line[0] '#') {
            header = (regex:find 'branch.([a-z]+)' $line[1])
            if (==s $header 'ab') {
                gitStatus[branch][ahead] = (regex:find '\+(\d+)' $line[2])
                gitStatus[branch][behind] = (regex:find '-(\d+)' $line[3])
            } else {
                gitStatus[branch][$header] = $line[2]
            }
        } elif (==s $line[0] '1') {
            input = (-map-modified $line)
            gitStatus = (-initialize-path $gitStatus $input[path])
            gitStatus = (-parse-modified $gitStatus $input)
        } elif (==s $line[0] '2') {
            input = (-map-modified $line)
            gitStatus = (-initialize-path $gitStatus $input[path])
            gitStatus = (-parse-renamed-copied $gitStatus $input)
        } elif (==s $line[0] 'u') {
            input = (-map-modified $line)
            gitStatus = (-initialize-path $gitStatus $input[path])
            gitStatus = (-parse-unmerged $gitStatus $input)
        } elif (==s $line[0] '?') {
            path = (str:join " " $line[1..])
            gitStatus = (-initialize-path $gitStatus $path)
            gitStatus[paths][$path][untracked] = $true
        } elif (==s $line[0] '!') {
            path = (str:join " " $line[1..])
            gitStatus = (-initialize-path $gitStatus $path)
            gitStatus[paths][$path][ignored] = $true
        } else {
            put $line[0] >&2
            fail 'invalid type'
        }
    }

    put $gitStatus
}

