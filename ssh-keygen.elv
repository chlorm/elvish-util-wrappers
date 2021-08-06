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


fn generate-key [&type='ed25519' &passphrase=$nil &device-name=$nil &security-key=$false]{
    var types = [
        'ecdsa'
        'ed25519'
        'rsa'
    ]
    var _ = (has-value $types $type)

    # FIXME: use elvish-stl
    var date = (e:date '+%Y%m%d')
    var name = $date'-'(e:hostname)
    if $security-key {
        # FIXME: assert $device-name is not nil
        set name = $date'-'$device-name
    }

    fn if-sk [s]{
        if $security-key {
            put $s
        }
    }

    var cmdArgs = [
        '-t' $type(if-sk '-sk')
        '-C' $name
        '-f' $conf-dir'/id_'$type(if-sk '_sk')'-'$name
    ]
    if (!=s $pass $nil) {
        set cmdArgs = [ $@cmdArgs '-N' $pass ]
    }
    # FIXME: assert $security-key == $false
    if (==s $type 'rsa') {
        set cmdArgs = [ $@cmdArgs '-b' '4096' ]
    }
    if $security-key {
        var extra-args = [
            $@cmdArgs
            '-w' 'internal'
            '-O' 'resident'
            '-O' 'application='$name
        ]
    }

    if (not (os:is-dir $conf-dir)) {
        os:makedirs $conf-dir
    }
    if (not (os:is-file $conf-dir'/'$name'.pub')) {
        e:ssh-keygen $@cmdArgs
    }
}

fn update-known-hosts {
    var _ = (e:ssh-keygen '-H')
    os:remove $conf-dir'/known_hosts.old'
}