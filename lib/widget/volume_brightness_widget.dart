import 'dart:io';
import 'package:provider/provider.dart';
import '../provider/theme_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_volume_controller/flutter_volume_controller.dart';
import 'package:screen_brightness/screen_brightness.dart';

class VolumeBrightnessWidget extends StatefulWidget {
  const VolumeBrightnessWidget({super.key});

  @override
  State<VolumeBrightnessWidget> createState() => _VolumeBrightnessWidgetState();
}

class _VolumeBrightnessWidgetState extends State<VolumeBrightnessWidget> {
  double _volume = 0.5;
  double _brightness = 0.5;

  // 1.brightness
  // 2.volume
  int _controlType = 0;

  @override
  void initState() {
    super.initState();
    _loadSystemData();
  }

  Future<void> _loadSystemData() async {
    if (Platform.isWindows) {
      _volume = context.read<ThemeProvider>().softwareVolume;
      return;
    }
    try {
      final brightness = await ScreenBrightness().application;
      final volume = await FlutterVolumeController.getVolume() ?? 0.5;
      await FlutterVolumeController.updateShowSystemUI(false);
      if (!mounted) return;
      setState(() {
        _brightness = brightness;
        _volume = volume;
      });
    } catch (_) {
      /* Keep gestures available if a platform plugin is unavailable. */
    }
  }

  void _saveSoftwareVolume() {
    if (Platform.isWindows && _controlType == 2) {
      context.read<ThemeProvider>().setSoftwareVolume(_volume);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(44),
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onVerticalDragStart: (DragStartDetails details) {
          final width = Platform.isWindows
              ? context.size!.width - 88
              : MediaQuery.of(context).size.width;
          if (details.localPosition.dx > width / 2) {
            _controlType = 2;
            if (Platform.isWindows)
              _volume = context.read<ThemeProvider>().softwareVolume;
          } else {
            _controlType = 1;
          }
        },
        onVerticalDragUpdate: (DragUpdateDetails details) {
          if (_controlType == 2) {
            _volume = (_volume + (-details.delta.dy / 500)).clamp(0.0, 1.0);
            if (Platform.isWindows) {
              context.read<ThemeProvider>().setSoftwareVolume(
                _volume,
                persist: false,
              );
            } else {
              FlutterVolumeController.setVolume(_volume);
            }
          } else {
            _brightness = (_brightness + (-details.delta.dy / 500)).clamp(
              0.0,
              1.0,
            );
            ScreenBrightness().setApplicationScreenBrightness(_brightness);
          }
          setState(() {});
        },
        onVerticalDragEnd: (DragEndDetails details) {
          _saveSoftwareVolume();
          setState(() {
            _controlType = 0;
          });
        },
        onVerticalDragCancel: () {
          _saveSoftwareVolume();
          setState(() {
            _controlType = 0;
          });
        },
        child: Container(
          alignment: Alignment.topCenter,
          padding: const EdgeInsets.only(top: 20),
          child: _controlType == 0
              ? null
              : Container(
                  width: Platform.isWindows && _controlType == 2 ? 220 : 150,
                  height: 30,
                  padding: const EdgeInsets.symmetric(
                    vertical: 5,
                    horizontal: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _controlType == 1
                            ? Icons.light_mode
                            : Icons.volume_up_outlined,
                        color: Colors.white,
                        size: 20,
                      ),
                      const SizedBox(width: 5),
                      if (Platform.isWindows && _controlType == 2)
                        Text(
                          '软件音量 ${(_volume * 100).round()}% ',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                        ),
                      Expanded(
                        child: LinearProgressIndicator(
                          value: _controlType == 1 ? _brightness : _volume,
                          backgroundColor: Colors.white.withValues(alpha: 0.5),
                          color: Colors.redAccent,
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}
