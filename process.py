#!/usr/bin/python3

"""
Writes an .ffprobe.json file and calls 'ts add-shoo --rm' to immediately stash
and remove the file.

This is intended to be called by youtube-dl --exec.  It is called after every
video download.
"""

import os
import sys
import glob
import json
import subprocess
from youtube_dl.utils import write_json_file, encodeFilename

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
	subprocess.check_call(['ts', 'add-shoo', '--rm', '-c', '-d'] + files)

if __name__ == '__main__':
	main()
