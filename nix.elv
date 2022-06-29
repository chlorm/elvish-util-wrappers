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


use github.com/chlorm/elvish-stl/exec
use github.com/chlorm/elvish-stl/io
use github.com/chlorm/elvish-stl/os
use github.com/chlorm/elvish-stl/path
use github.com/chlorm/elvish-stl/regex
use github.com/chlorm/elvish-util-wrappers/su


# Clear environment variables in user environment polluted by makeWrapper.
fn clear-env {
    unset-env 'GDK_PIXBUF_MODULE_FILE'
    unset-env 'GI_TYPELIB_PATH'
    unset-env 'GIO_EXTRA_MODULES'
    unset-env 'GRL_PLUGIN_PATH'
    unset-env 'GST_PLUGIN_SYSTEM_PATH_1_0'
    unset-env 'GSETTINGS_SCHEMAS_PATH'
    unset-env 'XDG_DATA_DIRS'
    unset-env 'XDG_ICON_DIRS'
}

fn -user-buildenvs {
    var envs = [ ]
    for line [ (io:cat (path:home)'/.nixpkgs/config.nix') ] {
        var m = (regex:find '([0-9a-zA-Z_-]+)(?:[ ]+|)=.*buildEnv)' $line)
        if (!=s $m '') {
            set envs = [ $@envs $m ]
        }
    }
    put $envs
}

fn find-nixconfig-closures {
    var closures = [ ]
    for i [ (-user-buildenvs) ] {
        set closures = [
            $@closures
            (exec:cmd-out 'find' '/nix/store' '-name' '*'$i'*')
        ]
    }
    put $closures
}

fn find-nixos-closures {
    put [ (exec:cmd-out 'find' '/nix/store' '-name' '*'(hostname)'*') ]
}

fn build-iso {|platform|
    var nixpkgs = (exec:cmd-out 'nix-instantiate' '--eval' '-E' '<nixpkgs>')
    e:nix-build $nixpkgs'/nixos/release.nix' ^
        '-A' 'iso_minimal_new_kernel.'$platform
}

fn copy-closures {|target @closures|
    for i $closures {
        e:nix-copy-closure '--to' 'root@'$target $i
    }
}

fn install {|@attrs|
    for i $attrs {
        e:nix-env '-iA' $i '-f' '<nixpkgs>'
    }
}

fn rebuild-envs {|@args|
    var exceptions = [ ]
    for i [ (-user-buildenvs) ] {
        try {
            e:nix-env '-iA' $i '-f' '<nixpkgs>' $@args
        } catch e {
            set exceptions = [ $@exceptions $e ]
            continue
        }
    }

    for i $exceptions {
        echo $i
    }
}

fn remove-references {|path|
    if (not (os:is-dir $path)) {
        fail 'Specified path does not exist: '$path
    }

    for i [ (exec:cmd-out 'find' '-L' $path '-xtype' 1 '-name' 'result*') ] {
        if (and (os:is-file $path'/.git/config') ^
                (!=s (io:cat $path'/.git/config' | e:grep 'triton') '')) {
            os:remove $path
        }
    }
}

fn rebuild-system {|target @args|
    su:do 'nixos-rebuild' $target $@args ^
        '-I' 'nixpkgs='(e:nix-instantiate '--eval' '-E' '<nixpkgs>')
}

fn search {|@attrs|
    for i $attrs {
        e:nix-env '-qaP' '.*'$i'.*' '-f' '<nixpkgs>'
    }
}

# Set up the per-user profile.
fn user-profile-init {
    use github.com/chlorm/elvish-stl/env

    var home = (path:home)
    var nixProfile = $home'/.nix-profile'

    # Append ~/.nix-defexpr/channels to $NIX_PATH so that <nixpkgs>
    # paths work when the user has fetched the Nixpkgs channel.
    env:append 'NIXPATH' $home'/.nix-defexpr/channels'

    # Set up environment.
    set-env 'NIX_PROFILES' '/nix/var/nix/profiles/default '$home'/.nix-profile'

    # Set $NIX_SSL_CERT_FILE so that Nixpkgs applications like curl work.
    var hasCaCerts = $false
    var caCertsPaths = [
        # NixOS, Ubuntu, Debian, Gentoo, Arch
        '/etc/ssl/certs/ca-certificates.crt'
        # openSUSE Tumbleweed
        '/etc/ssl/ca-bundle.pem'
        # Fedora, CentOS
        '/etc/pki/tls/certs/ca-bundle.crt'
        # fallback to cacert in Nix profile
        '/etc/ssl/certs/ca-bundle.crt'
    ]
    for p $caCertsPaths {
        if (os:exists $p) {
            set-env 'NIX_SSL_CERT_FILE' $p
            set hasCaCerts = $true
            break
        }
    }
    if (not $hasCaCerts) {
        fail 'ca certs not found'
    }

    env:prepend 'MANPATH' $nixProfile'/share/man'
    env:prepend 'PATH' $nixProfile'/bin'
}

