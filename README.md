# Tapo C200 RTSP live video stream recorder

Connects to the RTSP stream provided by a TP-Link Tapo C200 camera (should work
with other Tapo camera and probably more RTSP devices) and records the live
stream into chunked files to provide a kind of "ring buffer" file system.

## Usage
1. Connect your camera to your local network ;
1. Setup your device account in the Tapo app to be able to connect to the RTSP
   stream of your camera, write down the chosen username and password ;
1. Find the local IP address of your camera ;
1. Update the `RTSP_URL` in `ffmpeg_rtsp_recorder.sh` with these informations
1. Launch the monitor script: `./ffmpeg_monitor.sh`

## RTSP disconnection, ffmpeg hanging and corrupted file
If the camera is electrically unplugged and `ffmpeg` was already connected to
the RTSP stream it might hang indefinitely. A monitor script has the
responsibility to detect this (when `ffmpeg` does not consume any CPU) and
restart the process.

When killing `ffmpeg` in the middle of a recording the resulting video file
might get corrupted. To fix it you can try the following.

### Try re-copying file using `ffmpeg`
```shell
ffmpeg -i input_corrupted_file.mp4 -c copy output_fixed_file.mp4
```
If you get the following: `moov atom not found`, you can continue with another
method to try to fix the file.

### Try fixing file using `qt-faststart`
```shell
qt-faststart input_corrupted_file.mp4 output_fixed_file.mp4
```
If you get the following: `last atom in file was not a moov atom`, you can
continue with another method to try to fix the file.

### Try restoring a truncated file using `untrunc`
```shell
git clone --recurse-submodules https://github.com/ponchio/untrunc.git
cd untrunc
# From README.md the simplest solution to build it is to build the docker image
docker build -t untrunc .
# Then run the image to fix your corrupted file providing a reference file that
# is working
docker run -v $(pwd):/files \
  untrunc /files/input_reference_file.mp4 /files/input_corrupted_file.mp4
```
