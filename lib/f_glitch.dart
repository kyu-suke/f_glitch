import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// A widget that renders an glitched image.
/// Effect has a [glitchRate]% chance of occurring every [frequency] milliseconds.
class FGlitch extends StatefulWidget {
  FGlitch(
      {Key? key,
      required this.imageProvider,
      this.imageFit,
      this.frequency = 1000,
      this.glitchRate = 50,
      List<Color> channelColors = const [],
      List<BlendMode> glitchMasks = const []})
      : super(key: key) {
    _colorChannels =
        (channelColors.isEmpty ? _defaultChannelColors : channelColors)
            .map((c) => _ColorChannel(c))
            .toList();
    _glitchList = (glitchMasks.isEmpty ? _defaultGlitchList : glitchMasks)
        .map((bm) => _GlitchMask(bm))
        .toList();
  }


  /// Interval that happens effect.
  final int frequency; // milliseconds

  /// Rate that happens effect.
  final int glitchRate; // 1 - 100

  /// A image that is used to effected.
  final ImageProvider imageProvider;

  // How to fit the image during layout.
  final BoxFit? imageFit;

  late final List<_ColorChannel> _colorChannels;
  late final List<_GlitchMask> _glitchList;

  final List<Color> _defaultChannelColors = const [
    Colors.red,
    Colors.green,
    Colors.blue,
  ];

  final List<BlendMode> _defaultGlitchList = const [
    BlendMode.softLight,
    BlendMode.multiply,
  ];

  @override
  State<FGlitch> createState() => _FGlitchState();
}

class _FGlitchState extends State<FGlitch> {
  late int _frequency;
  final _key = GlobalKey();
  static final Random _random = Random();
  List<Timer> _timers = [];

  @override
  void initState() {
    super.initState();

    _frequency = widget.frequency;
    _fGlitchTimer();
  }


  @override
  void dispose() {
    for (var timer in _timers) {
      timer.cancel();
    }
    _timers = [];
    super.dispose();
  }

  void _fGlitchTimer() {
    final timer = Timer.periodic(Duration(milliseconds: widget.frequency), (Timer timer) {
      if (_random.nextInt(100) > widget.glitchRate) return;

      _setTimer(
          _onTimerColorChannelShift(widget._colorChannels
              .map((cc) => _ColorChannel(cc._color,
                  topPosition: _randomPosition(-10, 10),
                  leftPosition: _randomPosition(-10, 10)))
              .toList()),
          100);

      _setTimer(
          _onTimerColorChannelShift(widget._colorChannels
              .map((cc) => _ColorChannel(cc._color,
                  topPosition: _randomPosition(-10, 10),
                  leftPosition: _randomPosition(-10, 10)))
              .toList()),
          200);

      _setTimer(
          _onTimerColorChannelShift(widget._colorChannels
              .map((cc) =>
                  _ColorChannel(cc._color, topPosition: 0, leftPosition: 0))
              .toList()),
          300);

      var milliseconds = 100;
      widget._glitchList.asMap().forEach((key, value) {
        _setTimer(_onTimerGlitch(key), milliseconds);
        milliseconds += 100;
      });

      if (_frequency != widget.frequency) {
        timer.cancel();
        _fGlitchTimer();
      }
    });
    _timers.add(timer);
  }

  void _setTimer(void Function(Timer) fn, int milliseconds) {
    final timer = Timer.periodic(
      Duration(milliseconds: milliseconds),
      fn,
    );
    _timers.add(timer);
  }

  void Function(Timer) _onTimerColorChannelShift(
      List<_ColorChannel> colorChannels) {
    return (Timer timer) {
      timer.cancel();
      if (!mounted) return;
      setState(() {
        colorChannels.asMap().forEach((index, cc) {
          widget._colorChannels[index] = cc;
        });
      });
    };
  }

  void Function(Timer) _onTimerGlitch(int key) {
    return (Timer timer) {
      timer.cancel();
      if (!mounted) return;
      setState(() {
        var glitchMask = widget._glitchList[key];
        glitchMask._setPosition(
            _randomSideMargin(-50, 50),
            _randomPosition(0, _key.currentContext!.size!.height),
            _randomPosition(5, 30));
        glitchMask._setShow(true);
        widget._glitchList[key] = glitchMask;
      });

      final glitchTimer = Timer.periodic(
        const Duration(milliseconds: 300),
        (Timer timer) {
          timer.cancel();
          if (!mounted) return;
          setState(() {
            var glitchMask = widget._glitchList[key];
            glitchMask._setShow(false);
            widget._glitchList[key] = glitchMask;
          });
        },
      );
      _timers.add(glitchTimer);
    };
  }

  EdgeInsets _randomSideMargin(double min, double max) {
    var side = _random.nextDouble() * (max - min) + min;
    return side < 0
        ? EdgeInsets.only(right: side * -1)
        : EdgeInsets.only(left: side);
  }

  double _randomPosition(double min, double max) {
    return _random.nextDouble() * (max - min) + min;
  }

  Widget _channelWidget(_ColorChannel cc) {
    return Positioned.fill(
      left: cc.leftPosition,
      top: cc.topPosition,
      child: _BlendMask(
        blendMode: BlendMode.plus,
        child: Image(
          image: widget.imageProvider,
          fit: widget.imageFit,
          color: cc._color,
          colorBlendMode: BlendMode.multiply,
        ),
      ),
    );
  }

  Widget _glitchWidget(_GlitchMask g) {
    return Center(
      child: Container(
        margin: g._leftMargin,
        child: Stack(children: [
          ClipPath(
            clipper: _InvertedCircleClipper(g._topPosition, g._heightRate),
            clipBehavior: Clip.antiAliasWithSaveLayer,
            child: Wrap(
              children: [
                Image(
                  image: widget.imageProvider,
                  fit: widget.imageFit,
                  color: Colors.white,
                  colorBlendMode: g._blendMode,
                ),
              ],
            ),
          ),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      key: _key,
      children: [
        Container(
          color: Colors.black,
        ),

        // RGB shift
        ...widget._colorChannels.map((e) => _channelWidget(e)),

        // glitch
        ...widget._glitchList
            .where((element) => element._show)
            .map((g) => _glitchWidget(g)),
      ],
    );
  }
}

class _InvertedCircleClipper extends CustomClipper<Path> {
  const _InvertedCircleClipper(this._top, this._heightRate);

  final double _top;
  final double _heightRate;

  @override
  Path getClip(Size size) {
    return Path()
      ..addRect(
        Rect.fromLTWH(0, _top, size.width, size.height / _heightRate),
      )
      ..fillType = PathFillType.evenOdd;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}

class _ColorChannel {
  const _ColorChannel(this._color,
      {this.topPosition = 0, this.leftPosition = 0});

  final Color _color;

  /// [_ColorChannel]'s top position.
  final double topPosition;

  /// [_ColorChannel]'s left position.
  final double leftPosition;
}

class _GlitchMask {
  _GlitchMask(this._blendMode);

  final BlendMode _blendMode;
  EdgeInsets? _leftMargin;
  double _topPosition = 0;
  double _heightRate = 1;
  bool _show = false;

  void _setPosition(EdgeInsets margin, double topPosition, double heightRate) {
    _leftMargin = margin;
    _topPosition = topPosition;
    _heightRate = heightRate;
  }

  void _setShow(bool show) {
    _show = show;
  }
}

class _BlendMask extends SingleChildRenderObjectWidget {
  const _BlendMask({
    required this.blendMode,
    Key? key,
    Widget? child,
  }) : super(key: key, child: child);

  /// A widget that renders an glitched image.
  final BlendMode blendMode;

  final double _opacity = 1.0;

  @override
  RenderObject createRenderObject(context) {
    return _RenderBlendMask(blendMode, _opacity);
  }

  @override
  void updateRenderObject(BuildContext context, _RenderBlendMask renderObject) {
    renderObject.blendMode = blendMode;
    renderObject.opacity = _opacity;
  }
}

class _RenderBlendMask extends RenderProxyBox {
  _RenderBlendMask(this.blendMode, this.opacity);

  /// ColorChannels blend mode.
  BlendMode blendMode;

  /// ColorChannels opacity.
  double opacity;

  @override
  void paint(context, offset) {
    context.canvas.saveLayer(
        offset & size,
        Paint()
          ..blendMode = blendMode
          ..color = Color.fromARGB((opacity * 255).round(), 255, 255, 255));

    super.paint(context, offset);

    context.canvas.restore();
  }
}
