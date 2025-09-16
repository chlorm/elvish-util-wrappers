# Copyright (c) 2025, Cody Opel <cwopel@chlorm.net>
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


use github.com/chlorm/elvish-stl/ini
use github.com/chlorm/elvish-stl/io
use github.com/chlorm/elvish-stl/map
use github.com/chlorm/elvish-stl/path
use github.com/chlorm/elvish-xdg/xdg-dirs


fn youtube {|@args &c=$false|
    if $c {
        set args = [
            '--cookies-from-browser' 'firefox'
            $@args
        ]
    }
    e:yt-dlp -f 'bv*+ba' $@args
}

fn stream-download {|@args &root=$nil|
    var download-root = (xdg-dirs:download-dir)
    if (not (eq $root $nil)) {
        set download-root = $root
    }

    e:yt-dlp ^
        '--no-part' ^
        '--hls-use-mpegts' ^
        '--downloader' 'm3u8:ffmpeg' ^
        '-o' (path:join $download-root 'streams' '%(title)s %(webpage_url_domain.:-4)s.ts') ^
        $@args
}

fn stream-watcher {|@args &root=$nil|
    var download-root = (xdg-dirs:download-dir)
    if (not (eq $root $nil)) {
        set download-root = $root
    }

    var counter = 0
    var s = $true
    var timeout-default = '10m'
    var timeout = $timeout-default
    var clean-exit = $false
    while $s {
        try {
            stream-download &root=$download-root $@args
            set clean-exit = $true
        } catch _ { }

        var message = ''
        if (and $clean-exit (< $counter 20)) {
            # Reduced backoff incase stream was temporarily interrupted
            if (< $counter 10) {
                set timeout = '30s'
            } else {
                set timeout = '2m'
            }
            set counter = (+ $counter 1)
            set message = '('$counter')'
        } else {
            set timeout = $timeout-default
            set counter = 0
            set clean-exit = $false
        }

        echo 'Sleeping'$message': '$timeout >&2
        sleep $timeout
    }
}

fn streams-manager {|&config=$nil &prio-min=2 &root=$nil|
    var download-root = (xdg-dirs:download-dir)
    if (not (eq $root $nil)) {
        set download-root = $root
    }

    if (eq $config $nil) {
        # TODO: xdg
        set config = (ini:unmarshal (io:read (path:join (path:home) '.yt-dlp-streams.ini')))
    }

    var streams = [ ]
    for site [ (map:keys $config) ] {
        for streamer [ (map:keys $config[$site]) ] {
            if (< $prio-min $config[$site][$streamer]) {
                continue
            }
            set streams = [ (printf $site $streamer) $@streams ]
        }
    }

    for stream $streams {
        put $stream
        sleep '2s'
    } | peach {|i|
        echo 'Starting: '$i >&2
        stream-watcher &root=$download-root $i
    }
}

