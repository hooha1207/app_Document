import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart' as yt;

class VideoPlayerWidget extends StatefulWidget {
  final String videoUrl;
  const VideoPlayerWidget({super.key, required this.videoUrl});
  @override
  State<VideoPlayerWidget> createState() => _VideoPlayerWidgetState();
}
class _VideoPlayerWidgetState extends State<VideoPlayerWidget> {
  late VideoPlayerController _controller;
  bool _showControls = true;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  bool _isPlaying = false;
  
  @override
  void initState() {
    super.initState();
    _initializeController();
  }
  
  @override
  void didUpdateWidget(VideoPlayerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.videoUrl != widget.videoUrl) {
      _controller.dispose();
      _initializeController();
    }
  }
  
  void _initializeController() {
    _controller = VideoPlayerController.file(File(widget.videoUrl))
      ..initialize().then((_) {
        // Ensure the first frame is shown after the video is initialized
        if (mounted) {
          setState(() {
             _duration = _controller.value.duration;
          });
        }
      });
      _controller.addListener(_videoListener);
  }
  
  void _videoListener() {
    if (!mounted) return;
    setState(() {
      _position = _controller.value.position;
      _duration = _controller.value.duration; // Update duration just in case
      _isPlaying = _controller.value.isPlaying;
    });
  }
  
  @override
  void dispose() {
    _controller.removeListener(_videoListener);
    _controller.dispose();
    super.dispose();
  }
  
  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }
  
  @override
  Widget build(BuildContext context) {
    return _controller.value.isInitialized
        ? AspectRatio(
            aspectRatio: _controller.value.aspectRatio,
            child: Stack(
              alignment: Alignment.bottomCenter,
              children: [
                VideoPlayer(_controller),
                GestureDetector(
                  onTap: () => setState(() => _showControls = !_showControls),
                  child: Container(color: Colors.transparent), // Touch interceptor
                ),
                if (_showControls) ...[
                   // Center Play Button
                   Center(
                     child: IconButton(
                       icon: Icon(
                         _isPlaying ? Icons.pause_circle_filled : Icons.play_circle_fill,
                         color: Colors.white.withValues(alpha: 0.7),
                         size: 64,
                       ),
                       onPressed: () {
                          _isPlaying ? _controller.pause() : _controller.play();
                       },
                     ),
                   ),
                   // Bottom Control Bar
                   Container(
                     padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                     decoration: const BoxDecoration(
                       gradient: LinearGradient(
                         colors: [Colors.black54, Colors.transparent], 
                         begin: Alignment.bottomCenter, 
                         end: Alignment.topCenter
                       ),
                     ),
                     child: Column(
                       mainAxisSize: MainAxisSize.min,
                       children: [
                          Row(
                            children: [
                              Text(_formatDuration(_position), style: const TextStyle(color: Colors.white, fontSize: 12)),
                              Expanded(
                                child: SliderTheme(
                                  data: SliderTheme.of(context).copyWith(
                                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                                    trackHeight: 2,
                                  ),
                                  child: Slider(
                                    min: 0,
                                    max: _duration.inMilliseconds.toDouble(),
                                    value: _position.inMilliseconds.toDouble().clamp(0, _duration.inMilliseconds.toDouble()),
                                    activeColor: Colors.teal,
                                    inactiveColor: Colors.white30,
                                    onChanged: (value) {
                                      _controller.seekTo(Duration(milliseconds: value.toInt()));
                                    },
                                  ),
                                ),
                              ),
                              Text(_formatDuration(_duration), style: const TextStyle(color: Colors.white, fontSize: 12)),
                            ],
                          ),
                       ],
                     ),
                   )
                ]
              ],
            ),
          )
        : const SizedBox(
            height: 200,
            child: Center(child: CircularProgressIndicator()),
          );
  }
}
class AudioPlayerWidget extends StatefulWidget {
  final String audioUrl;
  const AudioPlayerWidget({super.key, required this.audioUrl});
  @override
  State<AudioPlayerWidget> createState() => _AudioPlayerWidgetState();
}
class _AudioPlayerWidgetState extends State<AudioPlayerWidget> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  
  @override
  void initState() {
    super.initState();
    _audioPlayer.onPlayerStateChanged.listen((s) => mounted ? setState(() => _isPlaying = s == PlayerState.playing) : null);
    _audioPlayer.onDurationChanged.listen((d) => mounted ? setState(() => _duration = d) : null);
    _audioPlayer.onPositionChanged.listen((p) => mounted ? setState(() => _position = p) : null);
    _loadAudio();
  }
  
  @override
  void didUpdateWidget(AudioPlayerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.audioUrl != widget.audioUrl) {
      _loadAudio();
    }
  }
  
  void _loadAudio() {
    _audioPlayer.stop();
    _audioPlayer.setSourceDeviceFile(widget.audioUrl);
  }
  
  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
      child: Row(children: [
        IconButton(icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow), onPressed: () => _isPlaying ? _audioPlayer.pause() : _audioPlayer.play(DeviceFileSource(widget.audioUrl))),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Slider(min: 0, max: _duration.inSeconds.toDouble(), value: _position.inSeconds.toDouble(), onChanged: (v) => _audioPlayer.seek(Duration(seconds: v.toInt()))),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 8.0), child: Text('${_position.toString().split('.').first} / ${_duration.toString().split('.').first}')),
        ])),
      ]),
    );
  }
}

class YouTubeBlockWidget extends StatefulWidget {
  final String url;

  const YouTubeBlockWidget({super.key, required this.url});

  @override
  State<YouTubeBlockWidget> createState() => _YouTubeBlockWidgetState();
}

class _YouTubeBlockWidgetState extends State<YouTubeBlockWidget> {
  late yt.YoutubePlayerController _controller;
  bool _isPlayerReady = false;

  @override
  void initState() {
    super.initState();
    final videoId = yt.YoutubePlayer.convertUrlToId(widget.url);
    final startSeconds = _parseStartTime(widget.url);

    if (videoId != null) {
      _controller = yt.YoutubePlayerController(
        initialVideoId: videoId,
        flags: yt.YoutubePlayerFlags(
          autoPlay: false,
          mute: false,
          disableDragSeek: true,
          loop: false,
          isLive: false,
          forceHD: false,
          enableCaption: true,
          startAt: startSeconds,
        ),
      )..addListener(_listener);
    }
  }

  int _parseStartTime(String url) {
    try {
      final uri = Uri.parse(url);
      String? t = uri.queryParameters['t'];
      if (t == null) return 0;

      // Handle cases like "1m30s", "90s", "90"
      if (RegExp(r'^\d+$').hasMatch(t)) {
        return int.parse(t);
      }

      int totalSeconds = 0;
      final timeRegex = RegExp(r'(\d+)([hms])');
      final matches = timeRegex.allMatches(t);

      for (final match in matches) {
        final value = int.parse(match.group(1)!);
        final unit = match.group(2);
        if (unit == 'h') totalSeconds += value * 3600;
        if (unit == 'm') totalSeconds += value * 60;
        if (unit == 's') totalSeconds += value;
      }
      return totalSeconds;
    } catch (e) {
      debugPrint('Error parsing YouTube time: $e');
      return 0;
    }
  }

  void _listener() {
    if (_isPlayerReady && mounted && !_controller.value.isFullScreen) {
      // setState(() {});
    }
  }

  @override
  void deactivate() {
    // Pausing video while navigating to other pages.
    if (_controller.value.isPlaying) _controller.pause();
    super.deactivate();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (yt.YoutubePlayer.convertUrlToId(widget.url) == null) {
       return Container(
        height: 200,
        color: Colors.black12,
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, color: Colors.grey, size: 48),
            SizedBox(height: 8),
            Text('Invalid YouTube URL', style: const TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: yt.YoutubePlayer(
        controller: _controller,
        showVideoProgressIndicator: true,
        progressIndicatorColor: Colors.teal,
        onReady: () {
          _isPlayerReady = true;
        },
      ),
    );
  }
}
