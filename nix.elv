# Copyright (c) 2019, Cody Opel <codyopel@gmail.com>
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

fn find-nixconfig-closures {
  local:envs = [(
    awk 'c&&!--c;!/^.*\/\*/ && /buildEnv/ {c=1}' (get-env HOME)'/.nixpkgs/config.nix' |
      grep -o -P '(?<=").*(?=")'
  )]

  local:closures = []
  for local:i $envs {
    closures = [ $@closures (find '/nix/store' '-name' '*'$i'*') ]
  }

  put $closures
}

fn find-nixos-closures {
  put [ (find '/nix/store' '-name' '*'(hostname)'*') ]
}

fn copy-closures [target closures]{
  for local:i $closures {
    nix-copy-closure '--to' 'root@'$target $i
  }
}

fn install [@pkgAttrs]{
  for local:i $pkgAttrs {
    nix-env '-iA' $i '-f' '<nixpkgs>'
  }
}

fn rebuild-envs [@args]{
  local:envs = [(
    awk '!/^.*\/\*/ && /buildEnv/ {print $1}' (get-env HOME)'/.nixpkgs/config.nix'
  )]

  local:exceptions = []
  for local:i $envs {
    try {
      nix-env '-iA' $i '-f' '<nixpkgs>' $@args
    } except e {
      exceptions = [$@exceptions $e]
      continue
    }
  }

  for local:x $exceptions {
    echo $x
  }
}

fn remove-references [path]{
  if (not ?(test -d $path)) {
    fail 'Specified path does not exist: '$path
  }

  for local:i [(find -L $path -xtype 1 -name "result*")] {
    pathDir = (dirname $path)
    if (and ?(test -f $path'/.git/config') (!=s (cat $path'/.git/config' | grep 'triton') '')) {
      rm $path
    }
  }
}

fn rebuild-system [target @args]{
  sudo nixos-rebuild $target $@args -I 'nixpkgs='(nix-instantiate --eval -E '<nixpkgs>')
}

fn search [@pkgAttrs]{
  for local:i $pkgAttrs {
    nix-env '-qaP' '.*'$i'.*' '-f' '<nixpkgs>'
  }
}

