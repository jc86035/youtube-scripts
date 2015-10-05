#!/usr/bin/python3

import os
import sys
import glob
import json
import subprocess
from youtube_dl.utils import write_json_file, encodeFilename

def main():
	fname = sys.argv[1]
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
	write_json_file(probeData, ffprobe)

	files = glob.glob('*%s*' % (video_id,))
	subprocess.check_call(['ts', 'add-shoo', '--rm', '-c', '-d'] + files)

if __name__ == '__main__':
	main()
