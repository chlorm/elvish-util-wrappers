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
use github.com/chlorm/elvish-stl/exec
use github.com/chlorm/elvish-stl/ini
use github.com/chlorm/elvish-stl/io
use github.com/chlorm/elvish-stl/map
use github.com/chlorm/elvish-stl/os
use github.com/chlorm/elvish-stl/path
use github.com/chlorm/elvish-stl/platform
use github.com/chlorm/elvish-stl/re


fn is-running {
    var running = $true

    if $platform:is-windows {
        try {
            var _ = (exec:ps-out '[bool](Get-Process firefox)')
        } catch _ {
            set running = $false
        }
    }

    put $running
}

fn get-dir {
    var home = (path:home)
    var firefoxDir = (path:join $home '.mozilla' 'firefox')

    if $platform:is-windows {
        var appData = (env:get 'APPDATA')
        set firefoxDir = (path:join $appData 'Mozilla' 'Firefox')
    }

    put $firefoxDir
}

fn get-profiles-ini {
    var firefoxDir = (get-dir)
    var profilesIni = (path:join $firefoxDir 'profiles.ini')

    put $profilesIni
}

fn get-profiles-map {
    var profilesIni = (get-profiles-ini)
    var profilesIniString = (io:open $profilesIni)
    var profilesMap = (ini:unmarshal $profilesIniString)

    put $profilesMap
}

fn get-default-profile {
    var profilesMap = (get-profiles-map)

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
    fail 'Default profile not set, add "Default=1" to the default profile.'
}

fn get-default-profile-dir {
    var firefoxDir = (get-dir)
    var profileDirName = (get-default-profile)
    var defaultProfileDir = (path:join $firefoxDir $profileDirName)

    put $defaultProfileDir
}

fn get-profile-dirs {
    var firefoxDir = (get-dir)
    var profilesMap = (get-profiles-map)

    var profileDirs = [ ]
    for i [ (map:keys $profilesMap) ] {
        if (re:match 'Profile[0-9]+' $i) {
            var profilePath = (path:join $firefoxDir $profilesMap[$i]['Path'])
            set profileDirs = [ $@profileDirs $profilePath ]
        }
    }

    put $profileDirs
}
