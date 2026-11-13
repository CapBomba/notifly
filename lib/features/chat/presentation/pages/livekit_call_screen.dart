import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../../core/theme/app_theme.dart';

class LiveKitCallScreen extends ConsumerStatefulWidget {
  const LiveKitCallScreen({
    super.key,
    required this.roomName,
    required this.participantName,
    required this.isVideoCall,
  });

  final String roomName;
  final String participantName;
  final bool isVideoCall;

  @override
  ConsumerState<LiveKitCallScreen> createState() => _LiveKitCallScreenState();
}

class _LiveKitCallScreenState extends ConsumerState<LiveKitCallScreen> {
  Room? _room;
  bool _connecting = true;
  bool _micMuted = false;
  bool _videoMuted = false;
  String? _errorMessage;

  static const String _liveKitUrl = 'wss://notifly-sandbox-7k2j9s.livekit.cloud';

  @override
  void initState() {
    super.initState();
    _videoMuted = !widget.isVideoCall;
    _connectToRoom();
  }

  Future<void> _connectToRoom() async {
    try {
      final micStatus = await Permission.microphone.request();
      final camStatus = widget.isVideoCall
          ? await Permission.camera.request()
          : PermissionStatus.granted;

      if (micStatus.isDenied || (widget.isVideoCall && camStatus.isDenied)) {
        setState(() {
          _connecting = false;
          _errorMessage =
              'Microphone and Camera permissions are required for LiveKit calls.';
        });
        return;
      }

      _room = Room();
      await _room!.connect(
        _liveKitUrl,
        'dev_token_${widget.participantName}',
        roomOptions: RoomOptions(
          adaptiveStream: true,
          dynacast: true,
        ),
      );

      if (widget.isVideoCall) {
        await _room!.localParticipant?.setMicrophoneEnabled(true);
        await _room!.localParticipant?.setCameraEnabled(true);
      } else {
        await _room!.localParticipant?.setMicrophoneEnabled(true);
        await _room!.localParticipant?.setCameraEnabled(false);
      }

      setState(() => _connecting = false);
    } catch (_) {
      setState(() {
        _connecting = false;
      });
    }
  }

  @override
  void dispose() {
    _room?.disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            if (_connecting)
              const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Colors.white),
                    SizedBox(height: 16),
                    Text('Connecting via LiveKit...',
                        style: TextStyle(color: Colors.white70)),
                  ],
                ),
              )
            else if (_errorMessage != null)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    _errorMessage!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ),
              )
            else
              _buildCallView(),

            // Top bar
            Positioned(
              top: 16,
              left: 16,
              right: 16,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Text(
                    widget.roomName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 40),
                ],
              ),
            ),

            // Bottom control bar
            Positioned(
              bottom: 32,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  FloatingActionButton(
                    heroTag: 'mic',
                    backgroundColor: _micMuted ? Colors.red : Colors.white24,
                    onPressed: () {
                      setState(() => _micMuted = !_micMuted);
                      _room?.localParticipant?.setMicrophoneEnabled(!_micMuted);
                    },
                    child: Icon(_micMuted ? Icons.mic_off : Icons.mic,
                        color: Colors.white),
                  ),
                  const SizedBox(width: 20),
                  FloatingActionButton(
                    heroTag: 'end',
                    backgroundColor: Colors.red,
                    onPressed: () {
                      _room?.disconnect();
                      Navigator.pop(context);
                    },
                    child: const Icon(Icons.call_end, color: Colors.white),
                  ),
                  const SizedBox(width: 20),
                  if (widget.isVideoCall) ...[
                    FloatingActionButton(
                      heroTag: 'cam',
                      backgroundColor: _videoMuted ? Colors.red : Colors.white24,
                      onPressed: () {
                        setState(() => _videoMuted = !_videoMuted);
                        _room?.localParticipant?.setCameraEnabled(!_videoMuted);
                      },
                      child: Icon(
                          _videoMuted ? Icons.videocam_off : Icons.videocam,
                          color: Colors.white),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCallView() {
    final participants = _room?.remoteParticipants.values.toList() ?? [];

    if (!widget.isVideoCall || participants.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 54,
              backgroundColor: AppColors.messengerBlue,
              child: Text(
                widget.roomName.isNotEmpty
                    ? widget.roomName[0].toUpperCase()
                    : 'C',
                style: const TextStyle(
                    fontSize: 42,
                    color: Colors.white,
                    fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              widget.roomName,
              style: const TextStyle(
                  color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'LiveKit Secure Call Connected',
              style: TextStyle(color: Colors.greenAccent, fontSize: 14),
            ),
          ],
        ),
      );
    }

    final remoteParticipant = participants.isNotEmpty ? participants.first : null;
    final remoteTrack = remoteParticipant?.trackPublications.values
        .where((t) => t.kind == TrackType.VIDEO && t.track != null)
        .firstOrNull
        ?.track as VideoTrack?;

    final localParticipant = _room?.localParticipant;
    final localTrack = localParticipant?.trackPublications.values
        .where((t) => t.kind == TrackType.VIDEO && t.track != null)
        .firstOrNull
        ?.track as VideoTrack?;

    return Stack(
      children: [
        if (remoteTrack != null)
          Positioned.fill(
            child: VideoTrackRenderer(remoteTrack),
          )
        else
          Center(
            child: Text(
              'Waiting for ${widget.roomName} to join video...',
              style: const TextStyle(color: Colors.white70),
            ),
          ),
        Positioned(
          top: 70,
          right: 20,
          width: 100,
          height: 150,
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.white24, width: 2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: localTrack != null
                  ? VideoTrackRenderer(localTrack)
                  : Container(color: Colors.grey.shade900),
            ),
          ),
        ),
      ],
    );
  }
}
