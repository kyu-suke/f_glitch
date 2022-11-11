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

  bool get _showColorShift => widget.controller!._showColorShift;

  bool get _showGlitch => widget.controller!._showGlitch;

  bool get _showScanline => widget.controller!._showScanline;

  List<_ColorChannel> get _colorChannels => widget.controller!._colorChannels;

  List<_GlitchMask> get _glitchChannels => widget.controller!._glitchChannels;

  double get _widgetHeight => widget.controller!._widgetHeight;

  double get _widgetWidth => widget.controller!._widgetWidth;

  double get _lineHeight => widget.controller!._lineHeight;

  Color get _lineColor => widget.controller!._lineColor;

  void rebuild() {
    widget.controller?.setKey(_key);
    setState(() {});
  }

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
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

  Widget _scanLineWidget() {
    return CustomPaint(
      size: Size(_widgetWidth, _widgetHeight),
      painter: _ScanLinePainter(lineHeight: _lineHeight, lineColor: _lineColor),
    );
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      key: _key,
      child: NotificationListener(
          child: Stack(
        children: [
          Image(
            image: widget.imageProvider,
            color: _showColorShift ? Colors.black : null,
          ),

          // RGB shift
          if (_showColorShift) ..._colorChannels.map((e) => _channelWidget(e)),

          // glitch
          if (_showGlitch)
            ..._glitchChannels
                .where((element) => element._show)
                .map((g) => _glitchWidget(g)),

          // scanline
          if (_showScanline) _scanLineWidget(),
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
  GlitchController({
    this.frequency = 1000,
    this.glitchRate = 50,
    autoplay = true,
    showColorShift = true,
    showGlitch = true,
    showScanline = false,
    double glitchLevel = 1,
    List<Color> channelColors = const [],
    List<BlendMode> glitchMasks = const [],
    double lineHeight = 0.5,
    Color lineColor = Colors.black,
  }) {
    _colorChannels =
        _defaultChannelColors.map((c) => _ColorChannel(c)).toList();
    _glitchChannels = _defaultGlitchList.map((c) => _GlitchMask(c)).toList();
    _frequency = frequency;
    _showColorShift = showColorShift;
    _showGlitch = showGlitch;
    _showScanline = showScanline;
    _glitchLevel = glitchLevel;
    _lineHeight = lineHeight;
    _lineColor = lineColor;

    if (autoplay) {
      play();
    }
  }

  /// Interval that happens effect. milliseconds.
  int frequency;

  /// Rate that happens effect. [1 - 100]
  int glitchRate;

  late double _glitchLevel;

  late bool _showColorShift;

  late bool _showGlitch;

  late bool _showScanline;

  late List<_ColorChannel> _colorChannels = [];

  late List<_GlitchMask> _glitchChannels = [];

  List<Timer> _timers = [];

  bool _isPlay = false;

  int _frequency = 0;

  GlobalKey? _key;

  double _widgetHeight = 0;

  double _widgetWidth = 0;

  double _lineHeight = 0;

  Color _lineColor = Colors.black;

  double get _glitchCoefficient => 1.1 * _glitchLevel;

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

  /// Set glitch level.
  void setGlitchLevel(double level) {
    _glitchLevel = level;
    _notify();
  }

  /// Show color shift effect.
  void showColorShift() {
    _showColorShift = true;
    _notify();
  }

  /// Hide color shift effect.
  void hideColorShift() {
    _showColorShift = false;
    _notify();
  }

  /// Show glitch effect
  void showGlitch() {
    _showGlitch = true;
    _notify();
  }

  /// Hide glitch effect
  void hideGlitch() {
    _showGlitch = false;
    _notify();
  }

  /// Show scan line.
  void showScanline() {
    _showScanline = true;
    _notify();
  }

  /// Hide scan line.
  void hideScanline() {
    _showScanline = false;
    _notify();
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
            topPosition: _randomPosition(
                -10 * _glitchCoefficient, 10 * _glitchCoefficient),
            leftPosition: _randomPosition(
                -10 * _glitchCoefficient, 10 * _glitchCoefficient)))
        .toList();

    for (final g in _glitchChannels) {
      g._setPosition(
          _randomSideMargin(-50 * _glitchCoefficient, 50 * _glitchCoefficient),
          _randomPosition(0, _widgetHeight * _glitchCoefficient),
          _randomPosition(5 * _glitchCoefficient, 30 * _glitchCoefficient));
      g._setShow(true);
    }
    _notify();
  }

  /// Disappear glitch effect.
  void reset() {
    _colorChannels =
        _colorChannels.map((e) => _ColorChannel(e._color)).toList();

    for (final g in _glitchChannels) {
      g._setShow(false);
    }
    _notify();
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

  /// Set FGlitch GlobalKey to use getting widget height and getting ui.Image.
  void setKey(GlobalKey key) {
    _key = key;
    _setWidgetHeight(key.currentContext?.size?.height ?? 0);
    _setWidgetWidth(key.currentContext?.size?.width ?? 0);
  }

  void _setWidgetHeight(double height) {
    _widgetHeight = height;
  }

  void _setWidgetWidth(double width) {
    _widgetWidth = width;
  }

  /// Frequency of glitching.
  void setFrequency(int i) {
    frequency = i;
  }

  /// Height at which the glitch effect appears. Usually, the height is the widget height.
  void setGlitchRate(int i) {
    glitchRate = i;
  }

  void _notify() {
    if (_key?.currentWidget != null) {
      notifyListeners();
    }
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
                  topPosition: _randomPosition(
                      -10 * _glitchCoefficient, 10 * _glitchCoefficient),
                  leftPosition: _randomPosition(
                      -10 * _glitchCoefficient, 10 * _glitchCoefficient)))
              .toList()),
          100);

      _setTimer(
          _onTimerColorChannelShift(_colorChannels
              .map((cc) => _ColorChannel(cc._color,
                  topPosition: _randomPosition(
                      -10 * _glitchCoefficient, 10 * _glitchCoefficient),
                  leftPosition: _randomPosition(
                      -10 * _glitchCoefficient, 10 * _glitchCoefficient)))
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
      _notify();
    };
  }

  void Function(Timer) _onTimerGlitch(int key) {
    return (Timer timer) {
      timer.cancel();

      var glitchMask = _glitchChannels[key];
      glitchMask._setPosition(
          _randomSideMargin(-50 * _glitchCoefficient, 50 * _glitchCoefficient),
          _randomPosition(0, _widgetHeight * _glitchCoefficient),
          _randomPosition(5 * _glitchCoefficient, 30 * _glitchCoefficient));
      glitchMask._setShow(true);
      _glitchChannels[key] = glitchMask;
      _notify();

      final glitchTimer = Timer.periodic(
        const Duration(milliseconds: 300),
        (Timer timer) {
          timer.cancel();

          var glitchMask = _glitchChannels[key];
          glitchMask._setShow(false);
          _glitchChannels[key] = glitchMask;
          _notify();
        },
      );
      _timers.add(glitchTimer);
    };
  }
}

/// Scan line CustomPainter
class _ScanLinePainter extends CustomPainter {
  _ScanLinePainter({lineHeight = 0.5, lineColor = Colors.black}) {
    _lineHeight = lineHeight;
    _lineColor = lineColor;
  }

  late final double _lineHeight;
  late final Color _lineColor;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    paint.color = _lineColor;
    for (double y = 0; y < size.height; y++) {
      if (y % 2 == 0) {
        canvas.drawRect(
            Rect.fromPoints(Offset(0, y), Offset(size.width, y + _lineHeight)),
            paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
}
