#!/usr/bin/python3

"""
Writes an .ffprobe.json file and calls 'ts add-shoo --rm' to immediately stash
and remove the file.

This is intended to be called by youtube-dl --exec.  It is called after every
video download.

We do the ffprobe here ourselves instead of using our patched youtube-dl
ffprobe functionality because youtube-dl runs this postprocessing command
before ffprobe.
"""

import os
import sys
import glob
import json
import shutil
import subprocess
from youtube_dl.utils import write_json_file, encodeFilename

def try_makedirs(p):
	try:
		os.makedirs(p)
	except OSError:
		pass

def main():
	fname = sys.argv[1]
	ffprobe_fname = fname.rsplit(".", 1)[0] + '.ffprobe.json'
	video_id = fname.rsplit(".", 1)[0][-11:]

	sp = subprocess.Popen(
		['ffprobe', '-v', 'quiet', '-print_format', 'json',
		'-show_format', '-show_streams', '-show_error', '-show_chapters', '-show_program_version',
		encodeFilename(fname, for_subprocess=True)],
		stdout=subprocess.PIPE, stderr=subprocess.PIPE, cwd=os.getcwd())
	out, err = sp.communicate()
	probeData = json.loads(out.decode().strip())
	if probeData.get('error'):
		raise RuntimeError('ffprobe metadata contained error: %r' % (probeData.get('error'),))
	write_json_file(probeData, ffprobe_fname)

	files = glob.glob('*%s*' % (video_id,))
	video_title_plus_id = list(f for f in files if f.endswith('.info.json'))[0].rsplit('.', 2)[0]
	response_dump_7z = video_title_plus_id + '.response_dump.7z'
	subprocess.check_call(['7zr', 'a', '-m0=lzma2', response_dump_7z, 'response_dump_' + video_id])
	shutil.rmtree('response_dump_' + video_id)

	# Because Google Drive throttles the number of files we can upload per minute,
	# and because terastash doesn't yet support bundling multiple files into one
	# Google Drive file, move the .jpg thumbnail and the .response_dump.7z to another
	# folder that we'll handle later.
	inessential_dest = os.getcwd().replace('/YouTube/', '/InessentialYouTube/', 1)
	try_makedirs(inessential_dest)
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
