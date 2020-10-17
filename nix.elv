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


use github.com/chlorm/elvish-stl/io
use github.com/chlorm/elvish-stl/os
use github.com/chlorm/elvish-stl/regex
use github.com/chlorm/elvish-util-wrappers/sudo


# Clear environment variables in user environment polluted by makeWrapper.
fn clear-env {
    unset-env GDK_PIXBUF_MODULE_FILE
    unset-env GI_TYPELIB_PATH
    unset-env GIO_EXTRA_MODULES
    unset-env GRL_PLUGIN_PATH
    unset-env GST_PLUGIN_SYSTEM_PATH_1_0
    unset-env GSETTINGS_SCHEMAS_PATH
    unset-env XDG_DATA_DIRS
    unset-env XDG_ICON_DIRS
}

fn -user-buildenvs {
    envs = [ ]
    for line [ (io:cat (get-env HOME)'/.nixpkgs/config.nix') ] {
        m = (regex:find '([0-9a-zA-Z_-]+)(?:[ ]+|)=.*buildEnv)' $line)
        if (!=s $m '') {
            envs = [ $@envs $m ]
        }
    }
    put $envs
}

fn find-nixconfig-closures {
    closures = [ ]
    for i [ (-user-buildenvs) ] {
        closures = [ $@closures (find '/nix/store' '-name' '*'$i'*') ]
    }
    put $closures
}

fn find-nixos-closures {
    put [ (e:find '/nix/store' '-name' '*'(hostname)'*') ]
}

fn build-iso [platform]{
    e:nix-build (e:nix-instantiate --eval -E '<nixpkgs>')'/nixos/release.nix' ^
        '-A' 'iso_minimal_new_kernel.'$platform
}

fn copy-closures [target @closures]{
    for i $closures {
        e:nix-copy-closure '--to' 'root@'$target $i
    }
}

fn install [@attrs]{
    for i $attrs {
        e:nix-env '-iA' $i '-f' '<nixpkgs>'
    }
}

fn rebuild-envs [@args]{
    exceptions = [ ]
    for i [ (-user-buildenvs) ] {
        try {
            e:nix-env '-iA' $i '-f' '<nixpkgs>' $@args
        } except e {
            exceptions = [ $@exceptions $e ]
            continue
        }
    }

    for i $exceptions {
        echo $i
    }
}

fn remove-references [path]{
    if (not (os:is-dir $path)) {
        fail 'Specified path does not exist: '$path
    }

    for i [ (e:find -L $path -xtype 1 -name "result*") ] {
        if (and (os:is-file $path'/.git/config') ^
                (!=s (io:cat $path'/.git/config' | grep 'triton') '')) {
            os:remove $path
        }
    }
}

fn rebuild-system [target @args]{
    sudo:sudo nixos-rebuild $target $@args ^
        -I 'nixpkgs='(nix-instantiate --eval -E '<nixpkgs>')
}

fn search [@attrs]{
    for i $attrs {
        e:nix-env '-qaP' '.*'$i'.*' '-f' '<nixpkgs>'
    }
}

