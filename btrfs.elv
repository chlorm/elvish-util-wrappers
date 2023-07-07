# Copyright (c) 2019-2021, Cody Opel <cwopel@chlorm.net>
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


use github.com/chlorm/elvish-stl/list
use github.com/chlorm/elvish-util-wrappers/su


fn add {|device filesystem|
    su:do 'btrfs' 'device' 'add' $device $filesystem
}

fn balance {|mode path &dusage=$nil &musage=$nil|
    var modes = [
        'cancel'
        'pause'
        'resume'
        'start'
        'status'
    ]
    var _ =(list:has $modes $mode)
    var opts = [ ]
    if (list:has [ 'start' 'status' ] $mode) {
        set opts = [ $@opts '-v' ]
    }
    if (==s $mode 'start') {
        if (not (eq $dusage $nil)) {
            set opts = [ $@opts '-dusage='$dusage ]
        }
        if (not (eq $musage $nil)) {
            set opts = [ $@opts '-musage='$musage ]
        }
    }
    su:do 'btrfs' 'balance' $mode $@opts $path
}

fn defrag {|path &compression='zstd' &compression-level='6'|
    var compressionAlgorithms = [
        'lzo'
        'zlib'
        'zstd'
    ]
    var opts = [ ]
    if (not (eq $compression $nil)) {
        list:has $compressionAlgorithms $compression
        set opts = [ $@opts '-c'$compression':'$compression-level ]
    }
    su:do 'btrfs' 'filesystem' 'defragment' '-v' '-r' $@opts '-f' $path
}

# FIXME: set checksum flag
fn mkfs {|@devices &checksum='crc32c' &label=$nil &metadata=$nil &data=$nil|
    var valid-checksums = [
        'crc32c'
        'xxhash'
        'blake2b'
        'sha256'
    ]
    var _ = (list:has $valid-checksums $checksum)
    var opts = [ ]
    if (not (eq $label $nil)) {
        set opts = [ $@opts '-L' $label ]
    }
    var valid-metadata = [
        'single'
        'dup'
        'raid1'
    ]
    if (not (eq $metadata $nil)) {
        set opts = [ $@opts '-m' $metadata ]
    }
    if (not (eq $data $nil)) {
        set opts = [ $@opts '-d' $data ]
    }
    su:do 'mkfs.btrfs' $@opts $@devices
}

fn mount {|device filesystem &subvol=$nil|
    if (not os:is-dir $filesystem) {
        fail
    }
    var opts = [ ]
    if (not (eq $subvol $nil)) {
        set opts = [ $@opts '-o' 'subvol='$subvol ]
    }
    su:do 'mount' '-t' 'btrfs' $@opts $device $filesystem
}

fn replace {|device filesystem|
    # FIXME: find devid programatically
    #su:do 'btrfs' 'replace' 'start' $devid $device $filesystem
}

fn scrub {|mode path &background=$false &ioprioclass=3 &ioprioclassdata=4|
    var modes = [
        'cancel'
        'resume'
        'start'
        'status'
    ]
    var _ = (list:has $modes $mode)
    # os:exists $path
    # and (>= 0 $ioprioclass) (<= 3 $ioprioclass)
    # and (>= 0 $ioprioclassdata) (<= 7 $ioprioclassdata)
    var opts = [ ]
    if (list:has [ 'resume' 'start' ] $mode) {
        if (not $background) {
            # Run in foreground
            set opts = [ $@opts '-B' ]
        }
        # Print statistics
        set opts = [ $@opts '-d' ]
        set opts = [ $@opts '-c'$ioprioclass '-n'$ioprioclassdata ]
    }
    su:do 'btrfs' 'scrub' $mode $@opts $path
}

fn subvol-create {|subvol|
    su:do 'btrfs' 'subvolume' 'create' $subvol
}
