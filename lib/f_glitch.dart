import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// A widget that renders an glitched image.
class FGlitch extends StatefulWidget {
  const FGlitch(
      {super.key, required this.imageProvider, this.imageFit, this.controller});

  /// A image that is used to effected.
  final ImageProvider imageProvider;

  /// How to fit the image during layout.
  final BoxFit? imageFit;

  /// A controller about glitch actions.
  final GlitchController? controller;

  @override
  State<FGlitch> createState() => _FGlitchState();
}

class _FGlitchState extends State<FGlitch> {
  final _key = GlobalKey();

  void rebuild() {
    setState(() {});
  }

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.controller?.setKey(_key);
      widget.controller?.addListener(rebuild);
    });
  }

  @override
  void dispose() {
    super.dispose();
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

  List<_ColorChannel> get _colorChannels => widget.controller!._colorChannels;

  List<_GlitchMask> get _glitchChannels => widget.controller!._glitchChannels;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      key: _key,
      child: NotificationListener(
          child: Stack(
        children: [
          Container(
            color: Colors.black,
          ),

          // RGB shift
          ..._colorChannels.map((e) => _channelWidget(e)),

          // glitch
          ..._glitchChannels
              .where((element) => element._show)
              .map((g) => _glitchWidget(g)),
        ],
      )),
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

/// A controller to notify glitch data to FGlitch.
/// Effect has a [glitchRate]% chance of occurring every [frequency] milliseconds.
class GlitchController extends ChangeNotifier {
  GlitchController(
      {this.frequency = 1000,
      this.glitchRate = 50,
      this.autoplay = true,
      List<Color> channelColors = const [],
      List<BlendMode> glitchMasks = const []}) {
    _colorChannels =
        _defaultChannelColors.map((c) => _ColorChannel(c)).toList();
    _glitchChannels = _defaultGlitchList.map((c) => _GlitchMask(c)).toList();
    _frequency = frequency;

    if (autoplay) {
      play();
    }
  }

  /// Interval that happens effect. milliseconds.
  int frequency;

  /// Rate that happens effect. [1 - 100]
  int glitchRate;

  /// Play glitch interval when widget is created
  late final bool autoplay;

  List<Timer> _timers = [];

  bool _isPlay = false;

  int _frequency = 0;

  GlobalKey? _key;

  double get _widgetHeight => _key?.currentContext!.size!.height ?? 0;

  late List<_ColorChannel> _colorChannels = [];

  late List<_GlitchMask> _glitchChannels = [];

  final List<Color> _defaultChannelColors = const [
    Colors.red,
    Colors.green,
    Colors.blue,
  ];

  final List<BlendMode> _defaultGlitchList = const [
    BlendMode.softLight,
    BlendMode.multiply,
  ];

  static final Random _random = Random();

  @override
  void dispose() {
    _resetTimer();
    super.dispose();
  }

  void _resetTimer() {
    for (var timer in _timers) {
      timer.cancel();
    }
    _timers = [];
  }

  /// Play glitch animation interval.
  void play() {
    if (_isPlay) return;
    _startGlitchInterval();
    _isPlay = true;
  }

  /// Pause glitch animation interval.
  void pause() {
    _resetTimer();
    _isPlay = false;
  }

  /// Appear glitch effect.
  void glitch() {
    _colorChannels = _colorChannels
        .map((e) => _ColorChannel(e._color,
            topPosition: _randomPosition(-10, 10),
            leftPosition: _randomPosition(-10, 10)))
        .toList();

    for (final g in _glitchChannels) {
      g._setPosition(_randomSideMargin(-50, 50),
          _randomPosition(0, _widgetHeight), _randomPosition(5, 30));
      g._setShow(true);
    }
    notifyListeners();
  }

  /// Disappear glitch effect.
  void reset() {
    _colorChannels =
        _colorChannels.map((e) => _ColorChannel(e._color)).toList();

    for (final g in _glitchChannels) {
      g._setShow(false);
    }
    notifyListeners();
  }

  /// Set FGlitch GlobalKey to use getting widget height and getting ui.Image.
  void setKey(GlobalKey key) {
    _key = key;
  }

  /// Height at which the glitch effect appears. Usually, the height is the widget height.
  void setFrequency(int i) {
    frequency = i;
  }

  /// Height at which the glitch effect appears. Usually, the height is the widget height.
  void setGlitchRate(int i) {
    glitchRate = i;
  }

  /// Getting glitched image as ui.Image
  /// When you render as flutter web, you need to add some options as below.
  /// --web-render canvaskit, --release, --dart-define=BROWSER_IMAGE_DECODING_ENABLED=false
  /// e.g.) flutter run -d chrome --web-renderer canvaskit --release --dart-define=BROWSER_IMAGE_DECODING_ENABLED=false
  Future<ui.Image> asImage() async {
    final boundary =
        _key!.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    return await boundary.toImage();
  }

  double _randomPosition(double min, double max) {
    return _random.nextDouble() * (max - min) + min;
  }

  EdgeInsets _randomSideMargin(double min, double max) {
    var side = _random.nextDouble() * (max - min) + min;
    return side < 0
        ? EdgeInsets.only(right: side * -1)
        : EdgeInsets.only(left: side);
  }

  void _startGlitchInterval() {
    final timer =
        Timer.periodic(Duration(milliseconds: frequency), (Timer timer) {
      if (_random.nextInt(100) > glitchRate) return;

      _setTimer(
          _onTimerColorChannelShift(_colorChannels
              .map((cc) => _ColorChannel(cc._color,
                  topPosition: _randomPosition(-10, 10),
                  leftPosition: _randomPosition(-10, 10)))
              .toList()),
          100);

      _setTimer(
          _onTimerColorChannelShift(_colorChannels
              .map((cc) => _ColorChannel(cc._color,
                  topPosition: _randomPosition(-10, 10),
                  leftPosition: _randomPosition(-10, 10)))
              .toList()),
          200);

      _setTimer(
          _onTimerColorChannelShift(_colorChannels
              .map((cc) =>
                  _ColorChannel(cc._color, topPosition: 0, leftPosition: 0))
              .toList()),
          300);

      var milliseconds = 100;
      _glitchChannels.asMap().forEach((key, value) {
        _setTimer(_onTimerGlitch(key), milliseconds);
        milliseconds += 100;
      });

      if (_frequency != frequency) {
        timer.cancel();
        _startGlitchInterval();
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

      colorChannels.asMap().forEach((index, cc) {
        colorChannels[index] = cc;
      });
      _colorChannels = colorChannels;
      notifyListeners();
    };
  }

  void Function(Timer) _onTimerGlitch(int key) {
    return (Timer timer) {
      timer.cancel();

      var glitchMask = _glitchChannels[key];
      glitchMask._setPosition(_randomSideMargin(-50, 50),
          _randomPosition(0, _widgetHeight), _randomPosition(5, 30));
      glitchMask._setShow(true);
      _glitchChannels[key] = glitchMask;
      notifyListeners();

      final glitchTimer = Timer.periodic(
        const Duration(milliseconds: 300),
        (Timer timer) {
          timer.cancel();

          var glitchMask = _glitchChannels[key];
          glitchMask._setShow(false);
          _glitchChannels[key] = glitchMask;
          notifyListeners();
        },
      );
      _timers.add(glitchTimer);
    };
  }
}
