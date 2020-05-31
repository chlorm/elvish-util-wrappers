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


use github.com/chlorm/elvish-util-wrappers/sudo


fn balance [mode path]{
  local:modes = [
    'cancel'
    'pause'
    'resume'
    'start'
    'status'
  ]
  has-value $modes $mode
  local:opts = [ ]
  if (or (==s 'start' $mode) (==s 'status' $mode)) {
    opts = ['-v']
  }
  sudo:sudo 'btrfs' 'balance' $mode $@opts $path
}

fn defrag [path &compression='zstd']{
  local:compression-algorithms = [
    'lzo'
    'zlib'
    'zstd'
  ]
  has-value $compression-algorithms $compression
  sudo:sudo 'btrfs' 'filesystem' 'defragment' '-v' '-r' '-c'$compression '-f' $path
}


fn scrub [mode path]{
  local:modes = [
    'cancel'
    'resume'
    'start'
    'status'
  ]
  has-value $modes $mode
  local:opts = [ ]
  if (or (==s 'resume' $mode) (==s 'restart' $mode)) {
    opts = ['-c' '3']
  }
  sudo:sudo 'btrfs' 'scrub' $mode $@opts $path
}

