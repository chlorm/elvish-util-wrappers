# Copyright (c) 2021-2023, Cody Opel <cwopel@chlorm.net>
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


use ../elvish-stl/list
use ../elvish-stl/os
use ../elvish-stl/path
use ../elvish-stl/re


fn reflac {
    var exts = [
        '.aif'
        '.aiff'
        '.ape'
        '.flac'
        '.m4a'
        '.wav'
        '.wv'
    ]

    for in [ (put *) ] {
        var ext = (path:ext $in)
        if (list:has $exts $ext) {
            var out = (re:replace $ext'$' '.flac' $in)
            var orig = $in
            if (==s $ext '.flac') {
                os:move $in $in'.old'
                set in = $in'.old'
            }
            try {
                e:ffmpeg -hide_banner -i $in -map 0:a:0 -compression_level 8 $out
            } catch _ {
                os:remove $out
                os:move $in $orig
                return
            }
            os:remove $in
        }
    }
}

fn wav2wavpack {
    for in [ (put *.wav) ] {
        var out = (re:replace '\.wav' '.wv' $in)
        try {
            e:ffmpeg '-hide_banner' '-i' $in '-compression_level' '3' $out
        } catch _ {
            os:remove $out
            return
        }
        os:remove $in
    }
}

fn -dsd2wavpack {|&ext='dff'|
    for in [ (put *'.'$ext) ] {
        var out = (re:replace '\.'$ext'$' '.wv' $in)
        try {
            e:wavpack '-hh' $in $out
        } catch _ {
            os:remove $out
            return
        }
        os:remove $in
    }
}
fn dff2wavpack {
    -dsd2wavpack
}
fn dsf2wavpack {
    -dsd2wavpack &ext='dsf'
}

fn dff2dsf {
    for in [ (put *.dff) ] {
        var out = (re:replace '\.dff' '.dsf' $in)
        try {
            e:dff2dsf $in $out
        } catch _ {
            os:remove $out
            return
        }
        os:remove $in
    }
}

fn sacd2dff {
    for in [ (put *.iso) ] {
        # Stereo
        e:sacd_extract -2 -s -C -i$in >sacd_log.txt
        # Surround
        e:sacd_extract -m -s -C -i$in >>sacd_log.txt
    }
}

fn findCues {|@cuefile|
    var f = $cuefile
    if (< (count $f) 1) {
        set f = [ (put *.cue) ]
    }
    if (> (count $f) 1) {
        fail 'More than one input cue files'
    }
    put $f[0]
}

fn cue {|@cuefile|
    var f = (findCues $@cuefile)
    printf 'splitting: %s' $f
    e:foobar2000 '/runcmd-files=Convert/flac' $f
}

fn rmcue {|@cuefile|
    var c = (findCues $@cuefile)
    var a = (re:find 'FILE (?:"|)(.*[^"])(?:"|) WAVE' (slurp < $c))
    if (not (os:exists $c)) {
        fail 'cuefile does not exist: '$c
    }
    if (not (os:exists $a)) {
        fail 'audiofile does not exist'
    }
    os:remove $a
    os:remove $c
}

fn dnrf {|@f|
    e:foobar2000 '/runcmd-files=Dynamic Range Meter' $@f
}

fn dnr {
    var f = [(put *.flac)]
    dnrf $@f
}

fn cover {
    var names = [
        'Front'
        'front'
        'folder'
        'Cover'
        'cover'
    ]

    for ext [ jpg jpeg png ] {
        var e = 'jpg'
        if (==s 'png' $ext) {
            set e = 'png'
        }
        var shouldReturn = $false
        for name $names {
            try {
                os:move $name'.'$ext 'Folder.'$e
                echo $name'.'$ext' > Folder.'$e >&2
                set shouldReturn = $true
            } catch _ { }
        }
        if $shouldReturn {
            return
        }
        var imgs = []
        try {
            set imgs = [ (put *'.'$ext) ]
        } catch _ { }
        if (and (== (count $imgs) 1) (not (os:exists 'Folder.'$e))) {
            os:move $imgs[0] 'Folder.'$e
            echo $imgs[0]' > Folder.'$e >&2
            return
        }
    }
}

fn newnames {
    # ep
    fixerall '^album' 'lp' &c
    fixerall '^single' 'si' &c
    fixerall '^compilation' 'co' &c
    fixerall '^demo' 'de' &c
    fixerall '^live' 'li' &c
    fixerall '^remix' 're' &c
    fixerall '^mixtape' 'mi' &c
    fixerall '^soundtrack' 'st' &c
    fixerall '^bootleg' 'bl' &c
}
