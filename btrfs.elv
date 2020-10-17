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


use github.com/chlorm/elvish-util-wrappers/sudo


fn balance [mode path &dusage=$nil &musage=$nil]{
    modes = [
        'cancel'
        'pause'
        'resume'
        'start'
        'status'
    ]
    has-value $modes $mode
    opts = [ ]
    if (or (==s $mode 'start') (==s $mode 'status')) {
        opts = [ $opts '-v' ]
    }
    if (==s $mode 'start') {
        if (not (==s $dusage $nil)) {
            opts = [ $opts '-dusage='$dusage ]
        }
        if (not (==s $musage $nil)) {
            opts = [ $opts '-musage='$musage ]
        }
    }
    sudo:sudo 'btrfs' 'balance' $mode $@opts $path
}

fn defrag [path &compression='zstd']{
    compressionAlgorithms = [
        'lzo'
        'zlib'
        'zstd'
    ]
    has-value $compressionAlgorithms $compression
    sudo:sudo 'btrfs' 'filesystem' ^
        'defragment' '-v' '-r' '-c'$compression '-f' $path
}

fn scrub [mode path &background=$false &ioprioclass=3 &ioprioclassdata=4]{
    modes = [
        'cancel'
        'resume'
        'start'
        'status'
    ]
    has-value $modes $mode
    opts = [ ]
    if (or (==s $mode 'resume') (==s $mode 'start')) {
        if (not $background) {
            opts = [ $opts '-B' ]
        }
        opts = [ $opts '-d' '-c'$ioprioclass '-n'$ioprioclassdata ]
    }
    sudo:sudo 'btrfs' 'scrub' $mode $@opts $path
}
