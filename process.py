#!/usr/bin/python3

"""
This post-processing script is intended to be called by `youtube-dl --exec`
after every successful YouTube download.

Takes one argument: the filename for the video.

1. Writes an .ffprobe.json file.
2. 7zips the response_dump_ folder to a .7z file.
3. Removes the response_dump_ folder.
4. Moves the .jpg thumbnail and response_dump .7z file to an InessentialYouTube
   folder (replacing '/YouTube/' in cwd with '/InessentialYouTube/').
5. Runs `ts add-shoo --rm` with a 12 hour timeout to add the video file and smaller
   metadata files to terastash, then remove them from the local disk.

We do the ffprobe here ourselves instead of using our patched youtube-dl
ffprobe functionality because youtube-dl runs this postprocessing command
before it runs ffprobe.
"""

import os
import sys
import glob
import json
import shutil
import subprocess
from youtube_dl.utils import write_json_file, encodeFilename

def main():
	fname         = sys.argv[1]
	ffprobe_fname = fname.rsplit(".", 1)[0] + '.ffprobe.json'
	video_id      = fname.rsplit(".", 1)[0][-11:]

	sp = subprocess.Popen(
		[
			'ffprobe',
			'-loglevel', 'quiet',
			'-print_format', 'json',
			'-show_format',
			'-show_streams',
			'-show_error',
			'-show_chapters',
			'-show_program_version',
			encodeFilename(fname, for_subprocess=True)
		],
		stdout=subprocess.PIPE,
		stderr=subprocess.PIPE,
		cwd=os.getcwd()
	)
	out, err   = sp.communicate()
	probe_data = json.loads(out.decode().strip())
	if probe_data.get('error'):
		raise RuntimeError('ffprobe metadata contained error: %r' % (probe_data.get('error'),))
	write_json_file(probe_data, ffprobe_fname)

	files               = glob.glob('*%s*' % (video_id,))
	video_title_plus_id = list(f for f in files if f.endswith('.info.json'))[0].rsplit('.', 2)[0]
	response_dump_7z    = video_title_plus_id + '.response_dump.7z'
	subprocess.check_call(['7zr', 'a', '-m0=lzma2', response_dump_7z, 'response_dump_' + video_id])
	shutil.rmtree('response_dump_' + video_id)

	# Because Google Drive throttles the number of files we can upload per minute,
	# and because terastash doesn't yet support bundling multiple files into one
	# Google Drive file, move the .jpg thumbnail and the .response_dump.7z to another
	# folder that we'll handle later.
	inessential_dest = os.getcwd().replace('/YouTube/', '/InessentialYouTube/', 1)
	os.makedirs(inessential_dest, exist_ok=True)
	thumbnail_file = glob.glob('*%s.jpg' % (video_id,))[:1]
	if thumbnail_file:
		thumbnail_file = thumbnail_file[0]
		os.replace(thumbnail_file, os.path.join(inessential_dest, thumbnail_file))
	os.replace(response_dump_7z, os.path.join(inessential_dest, response_dump_7z))

	files = glob.glob('*%s*' % (video_id,))
	# 12h timeout because googleapis sometimes seems to get stuck forever
	subprocess.check_call(['timeout', '12h', 'ts', 'add-shoo', '--rm', '-c', '-d'] + files)


if __name__ == '__main__':
	main()
