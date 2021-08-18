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


use github.com/chlorm/elvish-stl/os
use github.com/chlorm/elvish-util-wrappers/su


fn format [device &keyfile=$nil &keysize=256]{
    var extra-args = [ ]
    if (not (or (== $keysize 256) (== $keysize 512))) {
        fail
    }
    if (not (eq $nil $keyfile)) {
        if (not (os:exists $keyfile)) {
            fail
        }
        set extra-args = [
            $@extra-args
            '--master-key-file' $keyfile
        ]
    }
    su:do 'cryptsetup' 'luksFormat' $device ^
        '--type' 'luks2' ^
        '--cipher' 'aes-xts-plain64' ^
        '--key-size' $keysize ^
        '--hash' 'sha256' ^
        '--iter-time' 5000 ^
        '--use-random' ^
        '--verify-passphrase' ^
        $@extra-args
}

fn open [device map &keyfile=$nil]{
    var extra-args = [ ]
    if (not (eq $nil $keyfile)) {
        if (not (os:is-file $keyfile)) {
            fail
        }
        set extra-args = [
            $@extra-args
            '--key-file' $keyfile
        ]
    }
    su:do 'cryptsetup' 'luksOpen' $device $map ^
        $@extra-args
}

fn new-key [keyfile &bits=256]{
    if (not (or (== $bits 256) (== $bits 512))) {
        fail
    }
    var c = (/ $bits 8)
    e:dd 'if=/dev/random' 'of=$keyfile' 'bs=1' 'count='$c
}

fn add-key [device keyfile]{
    su:do 'cryptsetup' 'luksAddKey' $device $keyfile
}

fn read-key [device]{
    su:do 'cryptsetup' 'luksBackupHeader'
}

fn wipe [device &random=$false]{
    var s = '/dev/zero'
    if $random {
        set s = '/dev/urandom'
    }
    su:do 'dd' 'if='$s 'of='$device 'bs=1M' 'status=progress'
    su:do 'sync'
}
