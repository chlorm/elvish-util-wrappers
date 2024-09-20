# Copyright (c) 2022, 2024, Cody Opel <cwopel@chlorm.net>
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


use github.com/chlorm/elvish-stl/env
use github.com/chlorm/elvish-stl/ini
use github.com/chlorm/elvish-stl/io
use github.com/chlorm/elvish-stl/map
use github.com/chlorm/elvish-stl/os
use github.com/chlorm/elvish-stl/path
use github.com/chlorm/elvish-stl/platform


fn get-profiles-ini {
    if $platform:is-windows {
        var appData = (env:get 'APPDATA')
        path:join $appData 'Mozilla' 'Firefox' 'profiles.ini'
        return
    }

    path:join (path:home) '.mozilla' 'firefox' 'profiles.ini'
}

fn get-default-profile {|profilesMap|
    if (< (count $profilesMap) 1) {
        fail 'No profiles'
    }

    for i [ (map:keys $profilesMap) ] {
        try {
            var _ = (== $profilesMap[$i]['Default'] 1)
        } catch _ {
            continue
        }
        put $profilesMap[$i]['Path']
        return
    }

    echo (to-string $profilesMap) >&2
    fail 'Default profile not set'
}

fn get-default-profile-dir {
    var profilesIni = (get-profiles-ini)
    var profilesIniMap = (ini:unmarshal (io:open $profilesIni))
    var profilesRoot = (path:dirname $profilesIni)
    var profileDirName = (get-default-profile $profilesIniMap)
    var profileDir = (path:join $profilesRoot $profileDirName)

    put $profileDir
}

